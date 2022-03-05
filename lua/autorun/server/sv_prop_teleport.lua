-- this is the code that teleports entities like props
-- it only works for things with physics since I dont want to add support to other wacked entities that dont have physics

local seamless_check = function(e) return e:GetClass() == "seamless_portal" end    -- for traces
hook.Add("Think", "seamless_portal_teleport", function()
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
    for _, prop in ipairs(ents.GetAll()) do
        if prop:GetClass() == "player" or prop:GetClass() == "seamless_portal" then continue end
        if !prop:GetPhysicsObject():IsValid() then continue end
        if prop:GetVelocity() == Vector(0, 0, 0) then continue end

        -- puts fake prop in the other portal
        local realPos = prop:GetPos()
        local closestPortalDist = 0
        local closestPortal = nil
        for k, portal in ipairs(ents.FindByClass("seamless_portal")) do 
            local dist = realPos:DistToSqr(portal:GetPos())
            if (dist < closestPortalDist or k == 1) and portal:ExitPortal() and portal:ExitPortal():IsValid() then
                closestPortalDist = dist
                closestPortal = portal
            end
        end

        if !closestPortal or !closestPortal:ExitPortal() or !closestPortal:ExitPortal():IsValid() then continue end
    
        -- can it go through the portal?
        local tr = util.TraceLine({
            start = realPos - prop:GetVelocity() * 0.01, 
            endpos = realPos + prop:GetVelocity() * 0.01, 
            filter = seamless_check,
            noDetour = true,
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
                    prop:GetPhysicsObject():SetVelocity(editedAng:Forward() * max)
                    prop:SetAngles(editedPropAng)
                    prop:SetPos(editedPos)
                --end
            end
        end
    end
end)
