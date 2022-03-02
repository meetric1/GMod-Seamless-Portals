-- this file controls player movement through portals
-- is is also clientside because we need prediction
-- this is probably the most important and hacked together part of the mod

AddCSLuaFile()

local freezePly = false
local function updateCalcViews(finalPos, finalVel, finalSize)
	timer.Remove("portals_eye_fix_delay")	--just in case you enter the portal while the timer is running
	
	local weaponAng
	local weaponPos = LocalPlayer():EyePos()
	local addAngle = 1
	finalPos = finalPos - finalVel * FrameTime() * 0.5	-- why does this work? idk but it feels nice, could be a source prediction thing
	hook.Add("CalcView", "seamless_portals_fix", function(ply, origin, angle)
		if ply:EyePos():DistToSqr(origin) > 10000 then return end
		addAngle = addAngle * 0.9
		angle.r = angle.r * addAngle

		-- position ping compensation
		if freezePly and ply:Ping() > 5 then
			finalPos = finalPos + finalVel * FrameTime()
            SeamlessPortals.drawPlayerInView = true
		else
			finalPos = ply:EyePos()
		end

		weaponAng = angle
		weaponPos = finalPos

		return {origin = finalPos, angles = angle}
	end)

    -- weapons sometimes glitch out a bit when you teleport, since the weapon angle is wrong
	hook.Add("CalcViewModelView", "seamless_portals_fix", function(wep, vm, oldPos, oldAng, pos, ang)
		if weaponAng then
			return weaponPos, weaponAng
		end
	end)

    -- finish eyeangle lerp
	timer.Create("portals_eye_fix_delay", 0.5, 1, function()
		local ang = LocalPlayer():EyeAngles()
		ang.r = 0
		LocalPlayer():SetEyeAngles(ang)
		hook.Remove("CalcView", "seamless_portals_fix")
		hook.Remove("CalcViewModelView", "seamless_portals_fix")
	end)
end

-- this indicates wheather the player is 'teleporting' and waiting for the server to give the OK that the client position is valid
-- (only a problem with users that have higher ping)
if SERVER then
    util.AddNetworkString("PORTALS_FREEZE")
else
    net.Receive("PORTALS_FREEZE", function()
		if game.SinglePlayer() then updateCalcViews(Vector(), Vector()) end 	--singleplayer lerp fix
        freezePly = false
    end)
end


local seamless_check = function(e) return !(e:GetClass() == "seamless_portal" or e:GetClass() == "player") end    -- for traces

-- 'no collide' the player with the wall by shrinking the player's collision box
local traceTable = {}
local function editPlayerCollision(mv, ply)
	traceTable.start = ply:GetPos() + ply:GetVelocity() * 0.02
	traceTable.endpos = traceTable.start
	traceTable.mins = Vector(-16, -16, 0)
	traceTable.maxs = Vector(16, 16, 72)
	traceTable.filter = ply

	if !ply.PORTAL_STUCK_OFFSET then
		traceTable.ignoreworld = true
	else
		-- extrusion in case the player enables non-ground collision and manages to clip outside of the portal while they are falling (rare case)
		local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() - Vector(0, 0, 1), filter = ply})
		if tr.Hit then 
			ply.PORTAL_STUCK_OFFSET = nil
			mv:SetOrigin(ply:GetPos() + Vector(0, 0, 72))
			ply:ResetHull()
			return 
		end
	end

	local tr = util.TraceHull(traceTable)

	-- getting this to work on the ground was a FUCKING headache
	if !ply.PORTAL_STUCK_OFFSET and tr.Hit and tr.Entity:GetClass() == "seamless_portal" and tr.Entity:ExitPortal() and tr.Entity:ExitPortal():IsValid() then
		if tr.Entity:GetUp():Dot(Vector(0, 0, 1)) > 0.9 then		-- the portal is on the ground
			traceTable.mins = Vector(0, 0, 0)
			traceTable.maxs = Vector(0, 0, 72)

			local tr = util.TraceHull(traceTable)
			if !tr.Hit or tr.Entity:GetClass() != "seamless_portal" then
				return -- we accomplished nothing :DDDD
			end

			ply.PORTAL_STUCK_OFFSET = 71
		else	
			ply.PORTAL_STUCK_OFFSET = 0		-- the portal is not on the ground
		end

		ply:SetHull(Vector(-4, -4, 0 + ply.PORTAL_STUCK_OFFSET), Vector(4, 4, 72))
		ply:SetHullDuck(Vector(-4, -4, 0 + ply.PORTAL_STUCK_OFFSET), Vector(4, 4, 36))

	elseif ply.PORTAL_STUCK_OFFSET and !tr.Hit then
		ply:ResetHull()
		ply.PORTAL_STUCK_OFFSET = nil
	end

	traceTable.ignoreworld = false
end

-- teleport players
hook.Add("Move", "seamless_portal_teleport", function(ply, mv)
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end

	local plyPos = ply:EyePos()
	traceTable.start = plyPos - mv:GetVelocity() * 0.02 * (ply.SCALE_MULTIPLIER or 1)
	traceTable.endpos = plyPos + mv:GetVelocity() * 0.02 * (ply.SCALE_MULTIPLIER or 1)
	traceTable.filter = ply
	local tr = util.TraceLine(traceTable)

	editPlayerCollision(mv, ply)
	
	if !tr.Hit then return end
	local hitPortal = tr.Entity
	if hitPortal:GetClass() == "seamless_portal" and hitPortal:ExitPortal() and hitPortal:ExitPortal():IsValid() then
		if mv:GetVelocity():Dot(hitPortal:GetUp()) < 0 then
			if ply.PORTAL_TELEPORTING then return end
			freezePly = true

            -- wow look at all of this code just to teleport the player
			local editedPos, editedAng = SeamlessPortals.TransformPortal(hitPortal, hitPortal:ExitPortal(), tr.HitPos, mv:GetVelocity():Angle())
			local newEyeAngle = ply:EyeAngles()
			newEyeAngle:RotateAroundAxis(hitPortal:GetForward(), 180)
			local editedEyeAng = hitPortal:ExitPortal():LocalToWorldAngles(hitPortal:WorldToLocalAngles(newEyeAngle))
			local max = math.Max(mv:GetVelocity():Length(), hitPortal:ExitPortal():GetUp():Dot(-physenv.GetGravity() / 3))

			--ground can fluxuate depending on how the user places the portals, so we need to make sure we're not going to teleport into the ground
			local editedPos = editedPos - (ply:EyePos() - ply:GetPos())
			traceTable.start = editedPos + (ply:EyePos() - ply:GetPos())
			traceTable.endpos = editedPos - Vector(0, 0, 0.1)
			traceTable.filter = seamless_check
			local floor_trace = util.TraceLine(traceTable)

			-- scaling part
			local finalPos = editedPos

			-- dont do extrusion if the player is noclipping
			local offset
			if ply:GetMoveType() != MOVETYPE_NOCLIP then
				offset = floor_trace.HitPos
			else
				offset = editedPos
			end

			local exitSize = (hitPortal:ExitPortal():GetExitSize() / hitPortal:GetExitSize())
			if ply.SCALE_MULTIPLIER then
				ply:ConCommand("scale_multiplier " .. (ply.SCALE_MULTIPLIER * exitSize))
				ply.SCALE_MULTIPLIER = math.Clamp(ply.SCALE_MULTIPLIER * exitSize, 0.01, 10)
				finalPos = finalPos + ((ply:EyePos() - ply:GetPos()) - (ply:EyePos() - ply:GetPos()) * exitSize)
			end

			finalPos = finalPos - (editedPos - offset) * exitSize + Vector(0, 0, 0.1)	-- small offset so we arent in the floor

			-- apply final velocity
			mv:SetVelocity(editedAng:Forward() * max * exitSize)

			-- lerp fix for singleplayer
			if game.SinglePlayer() then
				ply:SetPos(finalPos)
				ply:SetEyeAngles(editedEyeAng)
			end

			-- send the client the new position
			if SERVER then 
				mv:SetOrigin(finalPos)
				net.Start("PORTALS_FREEZE")
				net.Send(ply)
			else
				updateCalcViews(finalPos + (ply:EyePos() - ply:GetPos()), editedAng:Forward() * max * exitSize, (ply.SCALE_MULTIPLIER or 1) * exitSize)	--fix viewmodel lerping for a tiny bit
				ply:SetEyeAngles(editedEyeAng)
			end

			ply.PORTAL_TELEPORTING = true 
			ply.PORTAL_STUCK_OFFSET = nil
			ply:ResetHull()

			timer.Simple(0, function()
				ply.PORTAL_TELEPORTING = false
			end)

			return true
		end
	end
end)
