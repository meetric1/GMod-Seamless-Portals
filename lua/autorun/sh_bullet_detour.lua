-- detour bullets so they go through portals
AddCSLuaFile()

-- clientside so visuals are also changed
hook.Add("EntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
    if !SeamlessPortals then return end
	if SeamlessPortals.PortalIndex < 1 then return end
	local tr = util.TraceLine({start = data.Src, endpos = data.Src + data.Dir * data.Distance, filter = entity})
	local hitPortal = tr.Entity
	if hitPortal:GetClass() == "seamless_portal" and hitPortal:ExitPortal() then
		if (tr.HitPos - hitPortal:GetPos()):Dot(hitPortal:GetUp()) > 0 then
			local newPos, newAng = SeamlessPortals.TransformPortal(hitPortal, hitPortal:ExitPortal(), tr.HitPos, data.Dir:Angle())

			--ignoreentity doesnt seem to work for some reason
			data.IgnoreEntity = hitPortal:ExitPortal()
			data.Src = newPos
			data.Dir = newAng:Forward()
			--print("detoured bullet")
			return true
		end
	end
end)
