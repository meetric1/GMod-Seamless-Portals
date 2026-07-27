-- detours so stuff go through portals
AddCSLuaFile()

-- bullet detour
hook.Add("EntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	local tr = SeamlessPortals.TraceLine({start = data.Src, endpos = data.Src + data.Dir * data.Distance, filter = entity})
	local hitPortal = tr.Entity
	if !hitPortal:IsValid() then return end
	if hitPortal:GetClass() != "seamless_portal" then return end
	local exitportal = hitPortal:GetExitPortal()
	if !IsValid(exitportal) then return end
	if (tr.HitPos - hitPortal:GetPos()):Dot(hitPortal:GetUp()) > 0 then
		local newPos, newAng = SeamlessPortals.TransformPortal(hitPortal, exitportal, tr.HitPos, data.Dir:Angle())

		--ignoreentity doesnt seem to work for some reason
		data.IgnoreEntity = exitportal
		data.Src = newPos
		data.Dir = newAng:Forward()
		data.Tracer = 0

		return true
	end
end)

-- super simple traceline detour
SeamlessPortals = SeamlessPortals or {}
SeamlessPortals.TraceLine = SeamlessPortals.TraceLine or util.TraceLine
util.TraceLine = function(data) -- Trace line that can go through portals
	local tr = SeamlessPortals.TraceLine(data)

	if IsValid(tr.Entity) then
		if tr.Entity:GetClass() == "seamless_portal" and IsValid(tr.Entity:GetExitPortal()) then
			local hitPortal = tr.Entity
			if tr.HitNormal:Dot(hitPortal:GetUp()) > 0.9 then
				local editeddata = table.Copy(data)
				local exitportal = hitPortal:GetExitPortal()
				editeddata.start = SeamlessPortals.TransformPortal(hitPortal, exitportal, tr.HitPos)
				editeddata.endpos = SeamlessPortals.TransformPortal(hitPortal, exitportal, data.endpos)
				-- filter the exit portal from being hit by the ray
				if IsEntity(data.filter) then
					editeddata.filter = {data.filter, exitportal}
				else
					if istable(editeddata.filter) then
						table.insert(editeddata.filter, exitportal)
					else
						editeddata.filter = exitportal
					end
				end
				return SeamlessPortals.TraceLine(editeddata)
			end
		end
		if data["WorldDetour"] then tr.Entity = game.GetWorld() end
	end
	return tr
end



-- surf
--[[
if SERVER then
	hook.Add("PlayerSpawn", "", function(ply)
		timer.Simple(0, function()
			ply:SetWalkSpeed(250)
			ply:StripWeapons()
			--util.SpriteTrail(ply, 0, Color(255, 100, 0, 255), false, 20, 0, 10, 1 / (20) * 0.5, "trails/lol")
		end)
	end)
else
	hook.Add("HUDPaint", "", function()
		draw.SimpleText(math.floor(LocalPlayer():GetVelocity():Length()), "CloseCaption_Bold", ScrW() / 2, ScrH() / 2, nil, 1, nil)
	end)
end]]



if SERVER then return end

-- sound detour
hook.Add("EntityEmitSound", "seamless_portals_detour_sound", function(t)
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end

	for k, v in ipairs(ents.FindByClass("seamless_portal")) do
		local exitportal = v.GetExitPortal and v:GetExitPortal()
		if !v.ExitPortal or !exitportal or !exitportal:IsValid() or !exitportal.GetExitSize then continue end
		if !t.Pos or !IsValid(t.Entity) then continue end
		if t.Pos:DistToSqr(v:GetPos()) < 50000 * exitportal:GetExitSize()[1] and (t.Pos - v:GetPos()):Dot(v:GetUp()) > 0 then
			local newPos = SeamlessPortals.TransformPortal(v, exitportal, t.Pos, Angle())
			local oldPos = t.Entity:GetPos() or Vector()
			t.Entity:SetPos(newPos)
			EmitSound(t.SoundName, newPos, t.Entity:EntIndex(), t.Channel, t.Volume, t.SoundLevel, t.Flags, t.Pitch, t.DSP)
			t.Entity:SetPos(oldPos)
		end
	end
end)
