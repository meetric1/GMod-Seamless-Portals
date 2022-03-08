-- detours so stuff go through portals
AddCSLuaFile()

-- bullet detour
hook.Add("EntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	local tr = util.TraceLine({start = data.Src, endpos = data.Src + data.Dir * data.Distance, filter = entity, noDetour = true})
	local hitPortal = tr.Entity
	if !hitPortal:IsValid() then return end
	if hitPortal:GetClass() == "seamless_portal" and hitPortal:ExitPortal() then
		if (tr.HitPos - hitPortal:GetPos()):Dot(hitPortal:GetUp()) > 0 then
			local newPos, newAng = SeamlessPortals.TransformPortal(hitPortal, hitPortal:ExitPortal(), tr.HitPos, data.Dir:Angle())

			--ignoreentity doesnt seem to work for some reason
			data.IgnoreEntity = hitPortal:ExitPortal()
			data.Src = newPos
			data.Dir = newAng:Forward()

			return true
		end
	end
end)

-- effect detour (Thanks to WasabiThumb)
local oldUtilEffect = util.Effect
local function effect(name, b, c, d)
     if SeamlessPortals.PortalIndex > 0 and (name == "phys_freeze" or name == "phys_unfreeze") then return end
     oldUtilEffect(name, b, c, d)
end
util.Effect = effect

-- traceline detour (Thanks to WasabiThumb)
-- (REWRITE THIS!)
local oldTraceLine = util.TraceLine
local rLayer = 0
local rLimit = 2
local function traceLine(data)
	local tr = oldTraceLine(data)
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return tr end
	if data["noDetour"] then return tr end
	if (rLayer >= rLimit) then return tr end
	if tr.Fraction >= 1 then return tr end
	if not tr.Hit then return tr end
	local ent = tr.Entity
	if not IsValid(ent) then return tr end
	if ent:GetClass() ~= "seamless_portal" then return tr end
	local exit = ent:ExitPortal()
	if not IsValid(exit) then return tr end
	local normal = tr.HitNormal
	local targetNormal = ent:GetUp()
	-- Taking advantage of the fact that portals are rectangular prisms
	if normal:DistToSqr(targetNormal) >= 1 then return tr end
	-- We hit the surface of a portal, time to perform a new trace
	local totalDist = data["endpos"]:Distance(data["start"])
	local remainingDist = totalDist * (1 - tr.Fraction)
	local realAngle = (data["endpos"] - data["start"]):Angle()
	local newStart, newAngle = SeamlessPortals.TransformPortal(ent, exit, tr.HitPos, realAngle)
	local newEnd = newStart + newAngle:Forward() * remainingDist
	local oldFilter = data["filter"]
	local myLayer = rLayer + 1
	local function newFilter(e)
		if not IsValid(e) then return false end
		if rLayer == myLayer then
			if e:EntIndex() == exit:EntIndex() then return false end
			if e:EntIndex() == ent:EntIndex() then return false end
		end
		if istable(oldFilter) then
			if table.HasValue(oldFilter, e) then return false end
		elseif isfunction(oldFilter) then
			return oldFilter(e)
		end
		return true
	end
	data["start"] = newStart
	data["endpos"] = newEnd
	data["filter"] = newFilter
	rLayer = rLayer + 1
	local ret = util.TraceLine(data)
	rLayer = rLayer - 1
	return ret
end

util.TraceLine = traceLine


if SERVER then return end

-- sound detour
hook.Add("EntityEmitSound", "seamless_portals_detour_sound", function(t)
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	for k, v in ipairs(ents.FindByClass("seamless_portal")) do
        if !v.ExitPortal or !v:ExitPortal() or !v:ExitPortal():IsValid() then continue end
        if !t.Pos or !t.Entity or t.Entity == NULL then continue end
        if t.Pos:DistToSqr(v:GetPos()) < 50000 and (t.Pos - v:GetPos()):Dot(v:GetUp()) > 0 then
            local newPos, _ = SeamlessPortals.TransformPortal(v, v:ExitPortal(), t.Pos, Angle())
            local oldPos = t.Entity:GetPos() or Vector()
            t.Entity:SetPos(newPos)
            EmitSound(t.SoundName, newPos, t.Entity:EntIndex(), t.Channel, t.Volume, t.SoundLevel, t.Flags, t.Pitch, t.DSP)
            t.Entity:SetPos(oldPos)
        end
	end
end)
