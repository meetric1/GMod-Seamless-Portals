-- this is the code that teleports entities like props
-- it only works for things with physics since I dont want to add support to other wacked entities that dont have physics

local allEnts
timer.Create("portals_ent_update", 0.25, 0, function()
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
    local portals = ents.FindByClass("seamless_portal")
    allEnts = ents.GetAll()

    for i = #allEnts, 1, -1 do 
        local prop = allEnts[i]
        local removeEnt = false
        if !prop:IsValid() or !prop:GetPhysicsObject():IsValid() then table.remove(allEnts, i) continue end
        if prop:GetVelocity():IsZero() then table.remove(allEnts, i) continue end
        if prop:GetClass() == "player" or prop:GetClass() == "seamless_portal" then table.remove(allEnts, i) continue end

        local realPos = prop:LocalToWorld(prop:OBBCenter())
        local closestPortalDist = 0
        local closestPortal = nil
        for k, portal in ipairs(portals) do
            if !portal:IsValid() then continue end
            local dist = realPos:DistToSqr(portal:GetPos())
            if (dist < closestPortalDist or k == 1) and portal:GetExitPortal() and portal:GetExitPortal():IsValid() then
                closestPortalDist = dist
                closestPortal = portal
            end
        end

        if !closestPortal or closestPortalDist > 1000000 * closestPortal:GetSize()[3] then table.remove(allEnts, i) continue end     --over 100 units away from the portal, dont bother checking
        if (closestPortal:GetPos() - realPos):Dot(closestPortal:GetUp()) > 0 then table.remove(allEnts, i) continue end     --behind the portal, dont bother checking
    end
end)

// stolen from infinite map
local function unfucked_setpos(constrainedProp, editedPos, editedPropAng, editedVel)
    // source engine cancels velocity for some reason
    local phys = constrainedProp:GetPhysicsObject()
    if phys:IsValid() then
        phys:SetPos(editedPos, true)
        phys:SetAngles(editedPropAng)
        phys:SetVelocity(editedVel)
    end

    // ragdoll moment
    if constrainedProp:IsRagdoll() then
        constrainedProp:SetAngles(editedPropAng)
        constrainedProp:SetPos(editedPos)
        for i = 0, constrainedProp:GetPhysicsObjectCount() - 1 do
            local phys = constrainedProp:GetPhysicsObjectNum(i)
            phys:SetPos(editedPos, true)
            phys:SetVelocityInstantaneous(editedVel)
        end
    end
end

local seamless_check = function(e) return e:GetClass() == "seamless_portal" end    -- for traces
hook.Add("Tick", "seamless_portal_teleport", function()
    if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 or !allEnts then return end
    for _, prop in ipairs(allEnts) do
        if !prop or !prop:IsValid() then continue end
        if prop:IsPlayerHolding() then continue end
        local realPos = prop:GetPos()

        -- can it go through the portal?
        local obbMin = prop:OBBMins()
        local obbMax = prop:OBBMaxs()
        local tr = util.TraceHull({
            start = realPos - prop:GetVelocity() * 0.02,
            endpos = realPos + prop:GetVelocity() * 0.02,
            mins = obbMin,
            maxs = obbMax,
            filter = seamless_check,
            ignoreworld = true,
        })

        if !tr.Hit then continue end
        local hitPortal = tr.Entity
        if hitPortal:GetClass() != "seamless_portal" then return end
        local hitPortalExit = tr.Entity:GetExitPortal()
        if hitPortalExit and hitPortalExit:IsValid() and obbMax[1] < hitPortal:GetSize()[1] * 2 and obbMax[2] < hitPortal:GetSize()[2] * 2 and prop:GetVelocity():Dot(hitPortal:GetUp()) < -0.5 then
            local constrained = constraint.GetAllConstrainedEntities(prop)
            for k, constrainedProp in pairs(constrained) do
                local editedPos, editedPropAng = SeamlessPortals.TransformPortal(hitPortal, hitPortalExit, constrainedProp:GetPos(), constrainedProp:GetAngles())
                local _, editedVel = SeamlessPortals.TransformPortal(hitPortal, hitPortalExit, nil, constrainedProp:GetVelocity():Angle())
                local max = math.Max(constrainedProp:GetVelocity():Length(), hitPortalExit:GetUp():Dot(-physenv.GetGravity() / 3))
                constrainedProp:ForcePlayerDrop()
                unfucked_setpos(constrainedProp, editedPos, editedPropAng, editedVel:Forward() * max)
            end
        end
    end
end)
