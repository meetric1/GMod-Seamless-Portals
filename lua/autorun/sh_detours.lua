-- detours so stuff go through portals
AddCSLuaFile()

-- bullet detour
hook.Add("EntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
	if !SeamlessPortals or #SeamlessPortals.Portals < 1 then return end
	local tr = SeamlessPortals.TraceLine({start = data.Src, endpos = data.Src + data.Dir * (data.Distance or 56755), filter = entity})
	local hitPortal = tr.Entity
	if !IsValid(hitPortal) then return end
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
	end
	return tr
end

if SERVER then return end

-- sound detour
local recursive = false -- EmitSound SHOULDNT trigger this hook, but lets be safe in case something detours it
hook.Add("EntityEmitSound", "seamless_portals_detour_sound", function(t)
	if !SeamlessPortals or #SeamlessPortals.Portals < 1 then return end
	if recursive then return end

	if !t.Pos then return end

	local eye_pos = MainEyePos()
	for _, portal in ipairs(SeamlessPortals.Portals) do
		local exit_portal = portal.GetExitPortal and portal:GetExitPortal()
		if !IsValid(exit_portal) then continue end

		-- are we in range?
		local portal_pos = portal:GetPos()
		local portal_size = portal:GetSize()[1]
		if t.Pos:DistToSqr(portal_pos) > 2*2 * portal_size * portal_size then continue end

		-- is sound infront of portals?
		if (eye_pos - exit_portal:GetPos()):Dot(exit_portal:GetUp()) < 0 or (t.Pos - portal_pos):Dot(portal:GetUp()) < 0 then continue end

		local translated_pos = SeamlessPortals.TransformPortal(portal, exit_portal, t.Pos)

		recursive = true
		EmitSound(t.SoundName, translated_pos, 0, t.Channel, t.Volume, t.SoundLevel, t.Flags, t.Pitch, t.DSP)
		recursive = false
	end
end)
