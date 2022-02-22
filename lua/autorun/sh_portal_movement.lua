-- this file controls player movement through portals
-- is is also clientside because we need prediction
-- this is probably the most important and hacked together part of the mod

AddCSLuaFile()

local freezePly = false
local function updateCalcViews(portal1, portal2, finalPos, finalVel)
	timer.Remove("portals_eye_fix_delay")	--just in case you enter the portal while the timer is running
	
	local weaponAng = LocalPlayer():EyeAngles()
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
			weaponPos = finalPos
			weaponAng = angle
            SeamlessPortals.drawPlayerInView = true
		else
			finalPos = ply:EyePos()
			weaponPos = finalPos
			weaponAng = angle
		end

		return {origin = finalPos, angles = angle}
	end)

    -- weapons sometimes glitch out a bit when you teleport, since the weapon angle is wrong
	hook.Add("CalcViewModelView", "seamless_portals_fix", function(wep, vm, oldPos, oldAng, pos, ang)
		return weaponPos, weaponAng
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
		if game.SinglePlayer() then updateCalcViews() end 	--singleplayer lerp fix
        freezePly = false
    end)
end

-- teleport players
local seamless_check = function(e) return !(e:GetClass() == "seamless_portal" or e:GetClass() == "player") end    -- for traces
hook.Add("Move", "seamless_portal_teleport", function(ply, mv)
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	local plyPos = ply:EyePos()
	local tr = util.TraceLine({
		start = plyPos - mv:GetVelocity() * 0.02, 
		endpos = plyPos + mv:GetVelocity() * 0.02, 
		filter = ply
	})
	
	if !tr.Hit then return end
	local hitPortal = tr.Entity
	if hitPortal:GetClass() == "seamless_portal" and hitPortal:ExitPortal() and hitPortal:ExitPortal():IsValid() then
		if mv:GetVelocity():Dot(hitPortal:GetUp()) < 0 then
			if CLIENT and ply.PORTAL_TELEPORTING then return false end

            -- wow look at all of this code just to teleport the player
			local editedPos, editedAng = SeamlessPortals.TransformPortal(hitPortal, hitPortal:ExitPortal(), tr.HitPos, mv:GetVelocity():Angle())
			local newEyeAngle = ply:EyeAngles()
			newEyeAngle:RotateAroundAxis(hitPortal:GetForward(), 180)
			local editedEyeAng = hitPortal:ExitPortal():LocalToWorldAngles(hitPortal:WorldToLocalAngles(newEyeAngle))
			local max = math.Max(mv:GetVelocity():Length(), hitPortal:ExitPortal():GetUp():Dot(-physenv.GetGravity() / 3))
			mv:SetVelocity(editedAng:Forward() * max)

			--ground can fluxuate depending on how the user places the portals, so we need to make sure we're not going to teleport into the ground
			local editedPos = editedPos - (ply:EyePos() - ply:GetPos())
			local floor_trace = util.TraceLine({
				start = editedPos + (ply:EyePos() - ply:GetPos()),
				endpos = editedPos - Vector(0, 0, 0.1),
				filter = seamless_check
			})

			local finalPos = editedPos - (editedPos - floor_trace.HitPos) + Vector(0, 0, 0.1)	--tiny offset so we arent in the floor
			freezePly = true

			if game.SinglePlayer() then
				ply:SetPos(finalPos)
				ply:SetEyeAngles(editedEyeAng)
			end

			if SERVER then 
				mv:SetOrigin(finalPos)
				net.Start("PORTALS_FREEZE")
				net.Send(ply)
			else
				ply:SetEyeAngles(editedEyeAng)
				updateCalcViews(hitPortal, hitPortal:ExitPortal(), finalPos + (ply:EyePos() - ply:GetPos()), editedAng:Forward() * ply:GetVelocity():Length())	--fix viewmodel lerping for a tiny bit
				ply.PORTAL_TELEPORTING = true 
				timer.Simple(0, function()
					ply.PORTAL_TELEPORTING = false
				end)
			end

			return true
		end
	end
end)
