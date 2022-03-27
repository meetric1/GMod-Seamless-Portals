-- this is the code that teleports entities like props
-- it only works for things with physics since I dont want to add support to other wacked entities that dont have physics

local allEnts
local portals
timer.Create("portals_ent_update", 0.5, 0, function()
    portals = ents.FindByClass("seamless_portal")
    allEnts = ents.GetAll()

    for i = #allEnts, 1, -1 do 
        local prop = allEnts[i]
        local removeEnt = false
        if !prop:IsValid() or !prop:GetPhysicsObject():IsValid() then table.remove(allEnts, i) continue end
        if prop:GetVelocity() == Vector(0, 0, 0) then table.remove(allEnts, i) continue end
        if prop:GetClass() == "player" or prop:GetClass() == "seamless_portal" then table.remove(allEnts, i) continue end

        local realPos = prop:GetPos()
        local closestPortalDist = 0
        local closestPortal = nil
        for k, portal in ipairs(portals) do
            if !portal:IsValid() then continue end
            local dist = realPos:DistToSqr(portal:GetPos())
            if (dist < closestPortalDist or k == 1) and portal:ExitPortal() and portal:ExitPortal():IsValid() then
                closestPortalDist = dist
                closestPortal = portal
            end
        end

        if !closestPortal or closestPortalDist > 10000 * closestPortal:GetExitSize()[3] then table.remove(allEnts, i) continue end     --over 100 units away from the portal, dont bother checking
        if (closestPortal:GetPos() - realPos):Dot(closestPortal:GetUp()) > 0 then table.remove(allEnts, i) continue end     --behind the portal, dont bother checking
    end
end)

local seamless_check = function(e) return e:GetClass() == "seamless_portal" end    -- for traces
hook.Add("Tick", "seamless_portal_teleport", function()
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 or !allEnts then return end
    for _, prop in ipairs(allEnts) do
        if !prop:IsValid() then continue end
        local realPos = prop:GetPos()

        -- can it go through the portal?
        local tr = SeamlessPortals.TraceLine({
            start = realPos - prop:GetVelocity() * 0.02, 
            endpos = realPos + prop:GetVelocity() * 0.02, 
            filter = seamless_check,
        })

        if !tr.Hit then continue end
        local hitPortal = tr.Entity
        if hitPortal:GetClass() == "seamless_portal" and hitPortal:ExitPortal() and hitPortal:ExitPortal():IsValid() then
            if prop:GetVelocity():Dot(hitPortal:GetUp()) < 0 then
                --local propsToTeleport = prop.Constraints
                --table.insert(propsToTeleport, prop)

                --for _, constraintedProp in ipairs(propsToTeleport) do
                    -- rotate velocity, position, and angles
                    local editedPos, editedAng = SeamlessPortals.TransformPortal(hitPortal, hitPortal:ExitPortal(), tr.HitPos, prop:GetVelocity():Angle())

                    --extra angle rotate
                    local newPropAng = prop:GetAngles()
                    newPropAng:RotateAroundAxis(hitPortal:GetForward(), 180)
                    local editedPropAng = hitPortal:ExitPortal():LocalToWorldAngles(hitPortal:WorldToLocalAngles(newPropAng))
                    local max = math.Max(prop:GetVelocity():Length(), hitPortal:ExitPortal():GetUp():Dot(-physenv.GetGravity() / 3))
                    prop:ForcePlayerDrop()
                    if prop:GetPhysicsObject():IsValid() then 
                        prop:GetPhysicsObject():SetVelocity(editedAng:Forward() * max) 
                    end
                    prop:SetAngles(editedPropAng)
                    prop:SetPos(editedPos)
                --end
            end
        end
    end
end)
