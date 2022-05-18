-- detours so stuff go through portals
AddCSLuaFile()

-- bullet detour
hook.Add("EntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	local tr = SeamlessPortals.TraceLine({start = data.Src, endpos = data.Src + data.Dir * data.Distance, filter = entity})
	local hitPortal = tr.Entity
	if !hitPortal:IsValid() then return end
	if hitPortal:GetClass() == "seamless_portal" and hitPortal:GetExitPortal() and hitPortal:GetExitPortal():IsValid() then
		if (tr.HitPos - hitPortal:GetPos()):Dot(hitPortal:GetUp()) > 0 then
			local newPos, newAng = SeamlessPortals.TransformPortal(hitPortal, hitPortal:GetExitPortal(), tr.HitPos, data.Dir:Angle())

			--ignoreentity doesnt seem to work for some reason
			data.IgnoreEntity = hitPortal:GetExitPortal()
			data.Src = newPos
			data.Dir = newAng:Forward()
			data.Tracer = 0

			return true
		end
	end
end)

-- effect detour (Thanks to WasabiThumb)
local oldUtilEffect = util.Effect
local function effect(name, b, c, d)
     if SeamlessPortals.PortalIndex > 0 and (name == "phys_unfreeze" or name == "phys_freeze") then return end
     oldUtilEffect(name, b, c, d)
end
util.Effect = effect

-- super simple traceline detour
SeamlessPortals = SeamlessPortals or {}
SeamlessPortals.TraceLine = SeamlessPortals.TraceLine or util.TraceLine
SeamlessPortals.NewTraceLine = function(data)
	local tr = SeamlessPortals.TraceLine(data)
	if tr.Entity:IsValid() then
		if tr.Entity:GetClass() == "seamless_portal" and tr.Entity:GetExitPortal() and tr.Entity:GetExitPortal():IsValid() then
			local hitPortal = tr.Entity
			if tr.HitNormal:Dot(hitPortal:GetUp()) > 0 then
				local editeddata = table.Copy(data)
				editeddata.start = SeamlessPortals.TransformPortal(hitPortal, hitPortal:GetExitPortal(), tr.HitPos)
				editeddata.endpos = SeamlessPortals.TransformPortal(hitPortal, hitPortal:GetExitPortal(), data.endpos)
				-- filter the exit portal from being hit by the ray
				if IsEntity(data.filter) and data.filter:GetClass() != "player" then
					editeddata.filter = {data.filter, hitPortal:GetExitPortal()}
				else
					if istable(editeddata.filter) then
						table.insert(editeddata.filter, hitPortal:GetExitPortal())
					else
						editeddata.filter = hitPortal:GetExitPortal()
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
hook.Add("EntityEmitSound", "seamless_portals_detour_sound", function(t)
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	for k, v in ipairs(ents.FindByClass("seamless_portal")) do
        if !v.ExitPortal or !v:GetExitPortal() or !v:GetExitPortal():IsValid() or !v:GetExitPortal().GetExitSize then continue end
        if !t.Pos or !t.Entity or t.Entity == NULL then continue end
        if t.Pos:DistToSqr(v:GetPos()) < 50000 * v:GetExitPortal():GetExitSize()[1] and (t.Pos - v:GetPos()):Dot(v:GetUp()) > 0 then
            local newPos, _ = SeamlessPortals.TransformPortal(v, v:GetExitPortal(), t.Pos, Angle())
            local oldPos = t.Entity:GetPos() or Vector()
            t.Entity:SetPos(newPos)
            EmitSound(t.SoundName, newPos, t.Entity:EntIndex(), t.Channel, t.Volume, t.SoundLevel, t.Flags, t.Pitch, t.DSP)
            t.Entity:SetPos(oldPos)
        end
	end
end)

-- black halo clipping plane fix
SeamlessPortals.HaloAdd = SeamlessPortals.HaloAdd or halo.Add
SeamlessPortals.NewHaloAdd = function(entities, color, blurx, blury, passes, additive, ignorez)
	if !SeamlessPortals.Rendering then
		SeamlessPortals.HaloAdd(entities, color, blurx, blury, passes, additive, ignorez)
	end
end
