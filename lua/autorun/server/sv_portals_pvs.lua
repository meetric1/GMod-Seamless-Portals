-- add the exit portals positions to player's PVS
hook.Add("SetupPlayerVisibility", "seamless_portals", function(ply, viewEntity)
    if #SeamlessPortals.Portals == 0 then
        return
    end

    local distance = ply:GetInfoNum("seamless_portal_drawdistance", 250)
    local eyePos = IsValid(viewEntity) and viewEntity:GetPos() or ply:EyePos()
    local eyeAngle = IsValid(viewEntity) and viewEntity:GetAngles() or ply:EyeAngles()

    for _, portal in ipairs(SeamlessPortals.Portals) do
        if portal:IsValid() then
            local exitPortal = portal:GetExitPortal()

            -- check the visibility of the portal and the existence of its exit portal before adding to the PVS
            if IsValid(exitPortal) and ply:TestPVS(portal) and SeamlessPortals.ShouldRender(portal, eyePos, eyeAngle, distance) then
                AddOriginToPVS(exitPortal:GetPos())
            end
        end
    end
end)
