AddCSLuaFile()
AddCSLuaFile("cl_portal_flashlight.lua")

local function too_fast(vel)
	return vel:LengthSqr() > 1000 * 1000
end

-- TODO: figure out the correct mask for this..
local portal_trace_data = {
	filter = function(e) return e:GetClass() == "seamless_portal" end,
	ignoreworld = true,
	mask = MASK_PLAYERSOLID
}

-- hull modifier (so we can enter floor/ground)
local function get_hull(ply)
	local mins, maxs
	if ply.SEAMLESS_PORTALS_HULL_MINS then
		mins, maxs = Vector(ply.SEAMLESS_PORTALS_HULL_MINS), Vector(ply.SEAMLESS_PORTALS_HULL_MAXS)
	else
		mins, maxs = ply:GetHull()
	end

	local scale = ply:GetModelScale()
	mins:Mul(scale)
	maxs:Mul(scale)

	return mins, maxs
end

local function get_hull_duck(ply)
	local mins, maxs
	if ply.SEAMLESS_PORTALS_HULL_DUCK_MINS then
		mins, maxs = Vector(ply.SEAMLESS_PORTALS_HULL_DUCK_MINS), Vector(ply.SEAMLESS_PORTALS_HULL_DUCK_MAXS)
	else
		mins, maxs = ply:GetHullDuck()
	end

	local scale = ply:GetModelScale()
	mins:Mul(scale)
	maxs:Mul(scale)

	return mins, maxs
end

local function invalidate_hull(ply)
	if ply.SEAMLESS_PORTALS_HULL_MINS then return end

	ply.SEAMLESS_PORTALS_HULL_MINS, ply.SEAMLESS_PORTALS_HULL_MAXS = ply:GetHull()
	ply.SEAMLESS_PORTALS_HULL_DUCK_MINS, ply.SEAMLESS_PORTALS_HULL_DUCK_MAXS = ply:GetHullDuck()
end

local function validate_hull(ply)
	if !ply.SEAMLESS_PORTALS_HULL_MINS then return false end

	-- TODO: does calling ResetHull cause any problems with resizing mods?
	ply:ResetHull()

	ply.SEAMLESS_PORTALS_HULL_MINS = nil
	ply.SEAMLESS_PORTALS_HULL_MAXS = nil
	ply.SEAMLESS_PORTALS_HULL_DUCK_MINS = nil
	ply.SEAMLESS_PORTALS_HULL_DUCK_MAXS = nil

	return true
end

local function is_hull_invalid(ply)
	return ply.SEAMLESS_PORTALS_HULL_MINS and true or false
end

local function get_hull_clip(hull_mins, hull_maxs)
	for i = 1, 2 do
		hull_mins[i] = math.max(hull_mins[i] / 4, -4)
		hull_maxs[i] = math.min(hull_maxs[i] / 4, 4)
	end

	hull_maxs[3] = hull_maxs[3] * 0.9
end

-- hull stand and hull duck must be calculated separately
local function clip_hull(ply, hull_mins, hull_maxs, half)
	--local hull_mins, hull_maxs = get_hull(ply) -- pass in to avoid gc spaz (-2 vectors)
	get_hull_clip(hull_mins, hull_maxs)

	local hull_duck_mins, hull_duck_maxs = get_hull_duck(ply)
	get_hull_clip(hull_duck_mins, hull_duck_maxs)

	if half then
		hull_mins[3] = hull_maxs[3]
		hull_duck_mins[3] = hull_maxs[3] -- genuine fuckshit
	end

	ply:SetHull(hull_mins, hull_maxs)
	ply:SetHullDuck(hull_duck_mins, hull_duck_maxs)

	--debugoverlay.Box(ply:GetPos(), hull_mins, hull_maxs, 0.5, Color(255, 0, 0, 0))
end

local function update_hull(ply, ply_pos)
	-- no need to modify hull if we're in noclip
	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		validate_hull(ply)
		return
	end

	local hull_mins, hull_maxs = get_hull(ply)
	portal_trace_data.start = ply_pos
	portal_trace_data.endpos = ply_pos
	portal_trace_data.mins = hull_mins
	portal_trace_data.maxs = hull_maxs
	local tr_hull = util.TraceHull(portal_trace_data)
	if !tr_hull.Hit then
		if is_hull_invalid(ply) then
			-- FIXME: during a teleport, this GetPos will check the ENTERED location, instead of the current
			-- meaning, it will check the enter location, and possibly think your collision hull is good for validation.
			-- (possibly sticking you into a wall)
			-- however, the likelyhood of this is nearly impossible, since you:
				-- 1. Need enough speed to not overlap the portal on exit
				-- 2. But not enough speed, since the too_fast check will force this overlap check to reutrn true
				-- 3. Enter a portal attached to nothing
				-- 4. Exit into a location which gets the normal hull stuck and non extruded
			-- I cant replicate this bug at all or find a situation where it happens, so I'm going to just leave this as-is for now
			ply_pos = ply:GetPos()
			if util.TraceHull({
				start = ply_pos,
				endpos = ply_pos,
				mins = hull_mins,
				maxs = hull_maxs,
				filter = ply,
				mask = MASK_PLAYERSOLID,
				collisiongroup = COLLISION_GROUP_INTERACTIVE
			}).Hit
			then
				-- shit. We're stuck
				clip_hull(ply, hull_mins, hull_maxs, false) -- back to standing
				return true -- let movement code try to extrude player
			end
		end

		return validate_hull(ply)
	end

	local portal = tr_hull.Entity
	if !IsValid(portal:GetExitPortal()) then return end

	-- we're about to change hull
	invalidate_hull(ply)

	-- floor portal mode. yikes.
	local half = portal:GetUp():Dot(Vector(0, 0, 1)) > 0.5
	if half then
		portal_trace_data.start = ply_pos + Vector(0, 0, hull_maxs[3])
		portal_trace_data.endpos = ply_pos + Vector(0, 0, hull_mins[3])

		local tr_ground = SeamlessPortals.TraceLine(portal_trace_data)
		half = tr_ground.Hit and !tr_ground.StartSolid
	end

	clip_hull(ply, hull_mins, hull_maxs, half)

	if half then
		ply:SetGroundEntity(nil)
	end

	return true
end

-- TODO: extrude on sides too so we dont get stuck in a wall
local function extrude_player(ply, ply_pos)
	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		return false
	end

	local mins, maxs = (ply:Crouching() and ply.GetHullDuck or ply.GetHull)(ply)
	local max_diff = maxs[3] - mins[3]
	if max_diff <= 0 then return false end

	mins[3] = maxs[3]
	local tr_ground = util.TraceHull({
		start = ply_pos,
		endpos = ply_pos - Vector(0, 0, maxs[3]),
		mins = mins,
		maxs = maxs,
		filter = ply,
		mask = MASK_PLAYERSOLID,
		collisiongroup = COLLISION_GROUP_INTERACTIVE
	})

	if !tr_ground.StartSolid and tr_ground.Hit then
		ply_pos[3] = ply_pos[3] + math.min((1 - tr_ground.Fraction) * maxs[3], max_diff)
		return true
	end

	return false
end

-- client lerp prevention
local get_flashlight = CLIENT and include("cl_portal_flashlight.lua")
local flashlight = nil -- flashlight will flicker going through (because of player lerp).. create a temporary fake one
local function lerp_teleport(start_pos, start_vel)
	-- reset values after teleport
	timer.Create("seamless_portals_lerp_teleport", 0.3, 1, function()
		SeamlessPortals.DrawPlayerInView = true
		hook.Remove("CalcView", "seamless_portals_lerp_teleport")
		hook.Remove("CalcViewModelView", "seamless_portals_lerp_teleport")
		hook.Remove("GetMotionBlurValues", "seamless_portals_lerp_teleport")

		-- reset roll / flashlight
		local ply = LocalPlayer()
		local ang = ply:EyeAngles() ang[3] = 0
		ply:SetEyeAngles(ang)
		ply:SetFlashlightColor(Color(255, 255, 255))
		if flashlight then flashlight:Remove() end
	end)

	local ply = LocalPlayer()
	if ply:GetViewEntity() != ply then -- viewing from a camera, no need to lerp
		return
	end

	SeamlessPortals.DrawPlayerInView = false
	start_pos = Vector(start_pos) -- this will be self-modified

	-- need for frame interp. noticable flashing over this speed. Hacky
	-- TODO: is this fixable?
	if !too_fast(start_vel) then
		start_pos:Sub(start_vel * FrameTime())
	end

	local weapon_pos = Vector(start_pos)
	local total_frame_time = 0
	hook.Add("CalcView", "seamless_portals_lerp_teleport", function(_, pos, ang)
		local frame_time = FrameTime()
		ang[3] = ang[3] * math.pow(math.max(0.3 - total_frame_time, 0) / 0.3, 3)

		-- prevents client from seeing small jitter during teleport with portals on differing heights (hack..)
		pos:Set(ply:EyePos())

		-- in my testing, lerp from positions takes roughly 0.03 seconds
		-- which means we need to fake our velocity for a tiny bit
		if total_frame_time < 0.03 then
			start_pos:Add(ply:GetVelocity() * frame_time)
			pos:Set(start_pos)
		elseif !SeamlessPortals.DrawPlayerInView then
			SeamlessPortals.DrawPlayerInView = true
			hook.Remove("GetMotionBlurValues", "seamless_portals_lerp_teleport")
		end

		ply:SetFlashlightColor(Color(0, 0, 0)) -- yeahh..
		if flashlight then flashlight:Remove() end
		flashlight = get_flashlight(pos, ang)
		if flashlight then flashlight:Update() end

		weapon_pos:Set(pos)

		total_frame_time = total_frame_time + frame_time
	end)

	hook.Add("CalcViewModelView", "seamless_portals_lerp_teleport", function(_, _, old_pos, _, pos, ang)
		--pos:Sub(old_pos)
		--pos:Add(weapon_pos)
		pos:Set(weapon_pos)
		ang[3] = ang[3] * math.pow(math.max(0.3 - total_frame_time, 0) / 0.3, 3)
	end)

	-- >:)
	hook.Add("GetMotionBlurValues", "seamless_portals_lerp_teleport", function(h, v, f, r)
		return 0, 0, 0, 0
	end)
end

hook.Add("Move", "seamless_portal_teleport", function(ply, mv)
	if !SeamlessPortals or #SeamlessPortals.Portals < 1 then
		validate_hull(ply)
		return
	end

	local ply_eyepos = ply:EyePos() -- base off eyepos, feels more accurate
	local ply_vel = mv:GetVelocity()
	local ply_vel_offset = ply_vel * FrameTime()

	-- update_hull will return true if we might need to do a ground extrusion
	local ply_pos = mv:GetOrigin()
	if update_hull(ply, ply_pos + ply_vel_offset) then
		if extrude_player(ply, ply_pos) then
			mv:SetOrigin(ply_pos)
		end
	end

	-- teleportation logic
	portal_trace_data.start = ply_eyepos
	portal_trace_data.endpos = ply_eyepos + ply_vel_offset
	portal_trace_data.ignoreworld = false
	local tr = SeamlessPortals.TraceLine(portal_trace_data)
	portal_trace_data.ignoreworld = true
	if !tr.Hit then return end

	local portal = tr.Entity -- might be world, but IsValid will catch it
	if !IsValid(portal) or portal:GetUp():Dot(ply_vel) >= 0 then return end -- not going into portal

	local exit_portal = portal:GetExitPortal()
	if !IsValid(exit_portal) then return end

	local hit_pos = portal_trace_data.endpos
	if too_fast(ply_vel) then
		hit_pos = tr.HitPos
	end

	local new_ply_eyepos, new_ply_ang = SeamlessPortals.TransformPortal(portal, exit_portal, hit_pos, ply:EyeAngles())
	local _, new_ply_vel = SeamlessPortals.TransformPortal(portal, exit_portal, nil, ply_vel:Angle())
	new_ply_vel = new_ply_vel:Forward()
	new_ply_vel:Mul(math.max(
		ply_vel:Length(),
		exit_portal:GetUp():Dot(-physenv.GetGravity() / 2) -- minimum velocity (to prevent fast in/out movement)
	))

	local ratio = exit_portal:GetSize()[1] / portal:GetSize()[1]
	new_ply_vel:Mul(ratio)

	local new_ply_pos = ply:GetCurrentViewOffset()
	new_ply_pos:Negate()
	new_ply_pos:Add(new_ply_eyepos)

	if CLIENT then
		if IsFirstTimePredicted() then
			ply:SetEyeAngles(new_ply_ang)
			lerp_teleport(new_ply_eyepos, new_ply_vel)

			-- mirror dimension
			if portal == exit_portal then
				SeamlessPortals.ToggleMirror(!SeamlessPortals.ToggleMirror())
			end
		end
	else
		if game.SinglePlayer() then
			ply:SetEyeAngles(new_ply_ang)

			-- singleplayer sucks. Network everything over
			net.Start("SEAMLESS_PORTALS_FIX_SINGLEPLAYER")
			net.WriteVector(new_ply_eyepos)
			net.WriteVector(new_ply_vel)
			net.WriteBool(portal == exit_portal)
			net.Send(ply)
		end

		-- shrinkinator (most popular resizing mod- change if there is a better one)
		ply:SetNWInt("desired_size", ply:GetNWInt("desired_size", 100) * ratio)

		portal:TriggerOutput("OnTeleportFrom", ply)
		exit_portal:TriggerOutput("OnTeleportTo", ply)
	end

	-- incase we get stuck
	update_hull(ply, new_ply_pos)
	extrude_player(ply, new_ply_pos)
	mv:SetOrigin(new_ply_pos)
	mv:SetVelocity(new_ply_vel)
	ply:SetGroundEntity(nil)

	return true
end)

-- singleplayer hack
if game.SinglePlayer() then
	if SERVER then
		util.AddNetworkString("SEAMLESS_PORTALS_FIX_SINGLEPLAYER")
	else
		net.Receive("SEAMLESS_PORTALS_FIX_SINGLEPLAYER", function()
			lerp_teleport(net.ReadVector(), net.ReadVector())

			if net.ReadBool() then
				SeamlessPortals.ToggleMirror(!SeamlessPortals.ToggleMirror())
			end
		end)
	end
end
