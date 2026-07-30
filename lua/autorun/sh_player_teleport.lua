AddCSLuaFile()

-- TODO: infmap
-- shrink support
-- fix hull resizing after entering floor portal

-- client lerp prevention
local function lerp_teleport(start_pos, start_vel)
	SeamlessPortals.DrawPlayerInView = false
	timer.Remove("seamless_portals_lerp_teleport")	--in case you enter the portal while the timer is running

	local weapon_pos = Vector()
	local total_frame_time = 0

	start_pos = Vector(start_pos) -- this will be self-modified

	-- need for frame interp. noticable flashing over this speed. Hacky
	-- TODO: is this fixable?
	if start_vel:LengthSqr() < 1000 * 1000 then
		start_pos:Sub(start_vel * FrameTime())
	end

	hook.Add("CalcView", "seamless_portals_fix", function(ply, pos, ang, fov)
		local frame_time = FrameTime()
		ang[3] = ang[3] * math.pow(math.max(0.3 - total_frame_time, 0) / 0.3, 3)

		-- in my testing, lerp from positions takes roughly 0.03 seconds
		-- which means we need to fake our velocity for a tiny bit
		if total_frame_time < 0.03 then
			start_pos:Add(start_vel * frame_time)
			pos:Set(start_pos)
		elseif !SeamlessPortals.DrawPlayerInView then
			SeamlessPortals.DrawPlayerInView = true
			hook.Remove("GetMotionBlurValues", "seamless_portals_fix")
		end

		weapon_pos:Set(pos)

		total_frame_time = total_frame_time + frame_time
	end)

	hook.Add("CalcViewModelView", "seamless_portals_fix", function(wep, vm, oldPos, oldAng, pos, ang)
		pos:Set(weapon_pos)
		ang[3] = ang[3] * math.pow(math.max(0.3 - total_frame_time, 0) / 0.3, 3)
	end)

	-- >:)
	hook.Add("GetMotionBlurValues", "seamless_portals_fix", function(h, v, f, r)
		return 0, 0, 0, 0
	end)

	timer.Create("seamless_portals_lerp_teleport", 0.3, 1, function()
		SeamlessPortals.DrawPlayerInView = true
		hook.Remove("CalcView", "seamless_portals_fix")
		hook.Remove("CalcViewModelView", "seamless_portals_fix")
		hook.Remove("GetMotionBlurValues", "seamless_portals_fix")

		-- reset roll
		local lp = LocalPlayer()
		local ang = lp:EyeAngles() ang[3] = 0
		lp:SetEyeAngles(ang)
	end)
end

-- TODO: figure out the correct mask for this..
local portal_trace_data = {
	filter = function(e) return e:GetClass() == "seamless_portal" end,
	ignoreworld = true,
}

-- hull modifier (so we can enter floor/ground)
local function get_hull(ply)
	if ply.SEAMLESS_PORTALS_HULL_MINS then
		return Vector(ply.SEAMLESS_PORTALS_HULL_MINS), Vector(ply.SEAMLESS_PORTALS_HULL_MAXS)
	else
		return ply:GetHull()
	end
end

local function get_hull_duck(ply)
	if ply.SEAMLESS_PORTALS_HULL_DUCK_MINS then
		return Vector(ply.SEAMLESS_PORTALS_HULL_DUCK_MINS), Vector(ply.SEAMLESS_PORTALS_HULL_DUCK_MAXS)
	else
		return ply:GetHullDuck()
	end
end

local function invalidate_hull(ply)
	if ply.SEAMLESS_PORTALS_HULL_MINS then return end

	ply.SEAMLESS_PORTALS_HULL_MINS, ply.SEAMLESS_PORTALS_HULL_MAXS = ply:GetHull()
	ply.SEAMLESS_PORTALS_HULL_DUCK_MINS, ply.SEAMLESS_PORTALS_HULL_DUCK_MAXS = ply:GetHullDuck()
end

local function validate_hull(ply)
	if !ply.SEAMLESS_PORTALS_HULL_MINS then return end

	ply.SEAMLESS_PORTALS_HULL_MINS = nil
	ply.SEAMLESS_PORTALS_HULL_MAXS = nil
	ply.SEAMLESS_PORTALS_HULL_DUCK_MINS = nil
	ply.SEAMLESS_PORTALS_HULL_DUCK_MAXS = nil

	-- TODO: does calling ResetHull every frame cause any problems?
	ply:ResetHull()

	return true
end

local function is_hull_invalid(ply)
	return ply.SEAMLESS_PORTALS_HULL_MINS and true or false
end

local function get_hull_clip(hull_mins, hull_maxs, half)
	for i = 1, 2 do
		hull_mins[i] = hull_mins[i] / 4
		hull_maxs[i] = hull_maxs[i] / 4
	end

	hull_maxs[3] = hull_maxs[3] * 0.9

	if half then
		hull_mins[3] = hull_maxs[3]
	end
end

-- hull stand and hull duck must be calculated separately
local function clip_hull(ply, hull_mins, hull_maxs, half)
	--local hull_mins, hull_maxs = get_hull(ply) -- pass in to avoid gc spaz (+2 vectors)
	get_hull_clip(hull_mins, hull_maxs, half)
	ply:SetHull(hull_mins, hull_maxs)
	--debugoverlay.Box(ply:GetPos(), hull_mins, hull_maxs, 0.05, Color(255, 255, 255, 0))

	hull_mins, hull_maxs = get_hull_duck(ply)
	get_hull_clip(hull_mins, hull_maxs, half)
	ply:SetHullDuck(hull_mins, hull_maxs)
end

local function update_hull(ply, ply_pos)
	-- no need to modify hull if we're in noclip
	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		validate_hull(ply)
		return
	end

	local hull_mins, hull_maxs = get_hull(ply)
	local ply_view_offset = ply:GetCurrentViewOffset()
	local ply_eyepos = ply_pos + ply_view_offset
	portal_trace_data.start = ply_pos
	portal_trace_data.endpos = ply_pos
	portal_trace_data.mins = hull_mins
	portal_trace_data.maxs = hull_maxs
	local tr_hull = util.TraceHull(portal_trace_data)
	if !tr_hull.Hit then
		if is_hull_invalid(ply) then
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
	portal_trace_data.start = ply_eyepos
	portal_trace_data.endpos = ply_pos - Vector(0, 0, hull_maxs[3])
	local half = portal:GetUp():Dot(Vector(0, 0, 1)) > 0.5 and SeamlessPortals.TraceLine(portal_trace_data).Hit

	clip_hull(ply, hull_mins, hull_maxs, half)

	return true
end

-- TODO: extrude on sides too so we dont get stuck in a wall
local function extrude_player(ply, ply_pos)
	local mins, maxs = (ply:Crouching() and ply.GetHullDuck or ply.GetHull)(ply)
	local max_diff = maxs[3] - mins[3]
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

	if !tr_ground.StartSolid then
		ply_pos[3] = ply_pos[3] + math.min((1 - tr_ground.Fraction) * maxs[3], max_diff)
		return true
	end

	return false
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
	local tr = SeamlessPortals.TraceLine(portal_trace_data)
	if !tr.Hit then return end

	local portal = tr.Entity
	if !IsValid(portal) or portal:GetUp():Dot(ply_vel) >= 0 then return end -- not going into portal

	local exit_portal = portal:GetExitPortal()
	if !IsValid(exit_portal) then return end

	local new_ply_eyepos, new_ply_ang = SeamlessPortals.TransformPortal(portal, exit_portal, tr.HitPos, ply:EyeAngles())
	local _, new_ply_vel = SeamlessPortals.TransformPortal(portal, exit_portal, nil, ply_vel:Angle())
	new_ply_vel = new_ply_vel:Forward() * math.max(
		ply_vel:Length(),
		exit_portal:GetUp():Dot(-physenv.GetGravity() / 2) -- minimum velocity (to prevent fast in/out movement)
	)

	local ratio = exit_portal:GetSize()[1] / portal:GetSize()[1]
	new_ply_vel:Mul(ratio)

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
			-- singleplayer sucks. Network everything over
			net.Start("SEAMLESS_PORTALS_FIX_SINGLEPLAYER")
			net.WriteVector(new_ply_eyepos)
			net.WriteVector(new_ply_vel)
			net.WriteBool(portal == exit_portal)
			net.Send(ply)

			ply:SetEyeAngles(new_ply_ang)
		end

		portal:TriggerOutput("OnTeleportFrom", ply)
		exit_portal:TriggerOutput("OnTeleportTo", ply)
	end

	-- ply_eyepos is now invalid
	local new_ply_pos = new_ply_eyepos
	new_ply_pos:Sub(ply:GetCurrentViewOffset())

	-- incase we get stuck
	update_hull(ply, new_ply_pos)
	extrude_player(ply, new_ply_pos)
	mv:SetOrigin(new_ply_pos)
	mv:SetVelocity(new_ply_vel)
	ply:SetGroundEntity(nil) -- TODO: is this required?

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
