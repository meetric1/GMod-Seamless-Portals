-- detours so stuff go through portals
AddCSLuaFile()

-- bullet detour
hook.Add("PostEntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
	if !SeamlessPortals or #SeamlessPortals.Portals < 1 then return end
	local tr = SeamlessPortals.TraceLine({start = data.Trace.StartPos, endpos = data.Trace.StartPos + data.Trace.Normal * (data.Distance or 56755), filter = entity})
	local hit_portal = tr.Entity
	if !IsValid(hit_portal) then return end
	if hit_portal:GetClass() != "seamless_portal" then return end
	local exit_portal = hit_portal:GetExitPortal()
	if !IsValid(exit_portal) then return end
	if (tr.HitPos - hit_portal:GetPos()):Dot(hit_portal:GetUp()) > 0 and not entity.FiredBullet then
		local new_pos, new_ang = SeamlessPortals.TransformPortal(hit_portal, exit_portal, tr.HitPos, data.Trace.Normal:Angle())
		local newTr = SeamlessPortals.TraceLine({
			start = new_pos,
			endpos = new_pos + new_ang:Forward() * (data.Distance or 56755),
			filter = exit_portal
		})
		local new_data = table.Copy(data)

		--ignoreentity doesnt seem to work for some reason
		new_data.IgnoreEntity = exit_portal
		new_data.Src = new_pos
		new_data.Dir = new_ang:Forward()
		new_data.Attacker = entity
		new_data.Inflictor = entity
		new_data.Tracer = 0

		exit_portal.FiredBullet = true
		exit_portal:FireBullets(new_data)
		exit_portal.FiredBullet = false

		-- portal bullet
		local eff = EffectData()
		eff:SetStart(new_data.Src)
		eff:SetOrigin(newTr.HitPos)
		eff:SetNormal(new_ang:Forward())
		eff:SetScale(2500)

		local tracer_name = data.TracerName

		if not tracer_name then
			if data.AmmoType == "AR2" then
				tracer_name = "AR2Tracer"
			end
		end

		tracer_name = tracer_name or "Tracer"

		util.Effect(tracer_name, eff)

		-- entity bullet
		local eff = EffectData()
		eff:SetStart(data.Trace.StartPos)
		eff:SetOrigin(tr.HitPos)
		eff:SetNormal(data.Trace.Normal)
		eff:SetScale(2500)

		util.Effect(tracer_name, eff)


		return false
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
