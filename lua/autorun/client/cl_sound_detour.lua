-- sound detouring
AddCSLuaFile()

if SERVER then return end

hook.Add("EntityEmitSound", "seamless_portals_detour_sound", function(t)
    if !SeamlessPortals then return end
	if SeamlessPortals.PortalIndex < 1 then return end
	for k, v in ipairs(ents.FindByClass("seamless_portal")) do
        if !t.Pos or t.Entity:GetClass() == "player" then continue end
        if (t.Pos - v:GetPos()):Dot(v:GetUp()) > 0 then
            local newPos, _ = SeamlessPortals.TransformPortal(v, v:ExitPortal(), t.Pos, Angle())
            t.Entity:SetPos(newPos)
            EmitSound(t.SoundName, newPos, t.Entity:EntIndex(), t.Channel, t.Volume, t.SoundLevel, t.Flags, t.Pitch, t.DSP)
            t.Entity:SetPos(Vector())
        end
	end
end)