-- Detours so stuff go through portals
AddCSLuaFile()

-- Bullet detour
hook.Add("EntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	local line = {start = Vector(data.Src), filter = entity}
	line.endpos = Vector(data.Dir); line.endpos:Mul(data.Distance); line.endpos:Add(data.Src)
	local tr = SeamlessPortals.TraceLine(line)
	local hitPortal = tr.Entity
	if !hitPortal or !hitPortal:IsValid() then return end
	if hitPortal:GetClass() != "seamless_portal" then return end
	local exitPortal = hitPortal:GetExitPortal()
	if exitPortal and exitPortal:IsValid() then
		if (tr.HitPos - hitPortal:GetPos()):Dot(hitPortal:GetUp()) > 0 then
			local newPos, newAng = SeamlessPortals.TransformPortal(hitPortal, exitPortal, tr.HitPos, data.Dir:Angle())

			-- Ignoreentity doesnt seem to work for some reason
			data.IgnoreEntity = exitPortal
			data.Src = newPos
			data.Dir = newAng:Forward()
			data.Tracer = 0

			return true
		end
	end
end)

local efName = {
	["phys_freeze"] = true,
	["phys_unfreeze"] = true
} -- Store names as hashes @dvdvideo1234
-- Effect detour (Thanks to WasabiThumb)
local oldUtilEffect = util.Effect
local function effect(name, b, c, d)
	if SeamlessPortals.PortalIndex > 0 and efName[name] then return end
	oldUtilEffect(name, b, c, d)
end
util.Effect = effect

-- Super simple traceline detour
SeamlessPortals = SeamlessPortals or {}
SeamlessPortals.TraceLine = SeamlessPortals.TraceLine or util.TraceLine
local function detourTraceLine(data)
	local tr = SeamlessPortals.TraceLine(data)
	local hitPortal = tr.Entity
	if hitPortal and hitPortal:IsValid() and hitPortal:GetClass() == "seamless_portal" then
		local exitPortal = hitPortal:GetExitPortal() -- Read exit portal
		if exitPortal and exitPortal:IsValid() and tr.HitNormal:Dot(hitPortal:GetUp()) > 0 then
			local detour = table.Copy(data)
			detour.start = SeamlessPortals.TransformPortal(hitPortal, exitPortal, tr.HitPos)
			detour.endpos = SeamlessPortals.TransformPortal(hitPortal, exitPortal, data.endpos)
			-- Filter the exit portal from being hit by the ray
			if IsEntity(data.filter) and data.filter:GetClass() != "player" then
				detour.filter = {data.filter, exitPortal}
			else
				if istable(detour.filter) then
					table.insert(detour.filter, exitPortal)
				else
					detour.filter = exitPortal
				end
			end
			return SeamlessPortals.TraceLine(detour)
		end
	end
	return tr
end

-- Use original traceline if there are no portals
timer.Create("seamless_portals_traceline", 1, 0, function()
	if SeamlessPortals.PortalIndex > 0 then
		util.TraceLine = detourTraceLine
	else
		util.TraceLine = SeamlessPortals.TraceLine	-- THE ORIGINAL TRACELINE
	end
end)

if SERVER then return end

-- Sound detour
hook.Add("EntityEmitSound", "seamless_portals_detour_sound", function(t)
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	for k, v in ipairs(ents.FindByClass("seamless_portal")) do
		if !v.ExitPortal or !v:GetExitPortal() or !v:GetExitPortal():IsValid() then continue end
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
