 
local oldTraceLine = util.TraceLine
local rLayer = 0
local rLimit = 4

local function traceLine(data)
	local tr = oldTraceLine(data)
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