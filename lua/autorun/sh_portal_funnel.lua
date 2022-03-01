
-- possible todo: make these convars?

-- what percentage of the speed to convert into funneling
local attractionPower = 0.2
local attractionPowerStrafing = 0.02
-- at what distance to stop looking for portals to funnel into
local attractionRadius = 480
-- if the current direction is this much offset from the inward direction
-- of the portal, then do not funnel. We wouldn't want to funnel a player
-- into a portal that they are not expressing any intent to enter.
local angleRange = math.pi / 4
hook.Add("Move", "sp_portal_funnel", function(ply, move)

	local vel = move:GetVelocity()
	local threshold = math.pow(ply:GetRunSpeed(), 2)
	local magSqr = vel:LengthSqr()
	local portal = NULL
	-- Only if the player is traveling at least their run speed.
	-- At lower speeds, players aren't really going to need funneling.
	-- This also allows us to elegantly sidestep some issues.
	if (magSqr >= threshold) then
		local found = ents.FindInSphere(ply:GetPos(), attractionRadius)
		for _,ent in ipairs(found) do
			if (ent:GetClass() == "seamless_portal") then
				portal = ent
				break
			end
		end
	end
	if IsValid(portal) then
		local mag = math.sqrt(magSqr)
		local inward = -portal:GetUp()
		local angle = math.acos((vel.x * inward.x + vel.y * inward.y + vel.z * inward.z) / mag)
		if (math.abs(angle) <= angleRange) then
			-- Crucially, we are not adding any energy here. Magnitude stays
			-- the same before and after.
			local towards = (portal:GetPos() - ply:GetPos()):GetNormalized() * mag
			local power = attractionPower
			if (move:GetSideSpeed() > 0) then power = attractionPowerStrafing end
			local speedCap = ply:GetRunSpeed()
			if (speedCap > 0 and speedCap < mag) then
				power = math.min(power, speedCap / mag)
			end
			local newVel = vel * (1 - power) + towards * power
			move:SetVelocity(newVel)
		end
	end

end ) 
