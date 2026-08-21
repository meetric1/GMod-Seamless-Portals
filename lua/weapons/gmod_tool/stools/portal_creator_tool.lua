TOOL.Category = "Seamless Portals"
TOOL.Name = "Portal Creator"

TOOL.Information = {
	{name = "left"},
	{name = "right1", stage = 1},
	{name = "right2", stage = 2},
	{name = "reload"}
}

-- portal fitter tool reuses a lot of this code
local g_tool = TOOL
hook.Add("PreRegisterTOOL", "seamless_portals_tool", function(tool, class)
	if class == "portal_fitter_tool" then
		tool.LeftClick = g_tool.LeftClick
		tool.Deploy = g_tool.Deploy
		tool.SetLinkTarget = g_tool.SetLinkTarget
		tool.GetLinkTarget = g_tool.GetLinkTarget
		tool.RightClick = g_tool.RightClick
		tool.Reload = g_tool.Reload
		tool.DrawHUD = g_tool.DrawHUD
	end
end)

if CLIENT then
	language.Add("Tool.portal_creator_tool.name", "Portal Creator")
    language.Add("Tool.portal_creator_tool.desc", "Creates and links portals")
    language.Add("Tool.portal_creator_tool.left", "Left Click: Create portal")
    language.Add("Tool.portal_creator_tool.right1", "Right Click: Start linking a portal")
    language.Add("Tool.portal_creator_tool.right2", "Right Click: Create link to another portal")
    language.Add("Tool.portal_creator_tool.reload", "Reload: Unlink a portal")

    CreateClientConVar("seamless_portals_size_x", "100", false, true, "Sets the size of the portal along the X axis", 1, 1000)
	CreateClientConVar("seamless_portals_size_y", "100", false, true, "Sets the size of the portal along the Y axis", 1, 1000)
	CreateClientConVar("seamless_portals_size_z", "8", false, true, "Sets the size of the portal along the Z axis", 1, 100)
	CreateClientConVar("seamless_portals_sides", "4", false, true, "Sets the number of sides the portal has", 3, 100)
	CreateClientConVar("seamless_portals_backface", "1", false, true, "Sets whether to spawn with a backface or not", 0, 1)
	CreateClientConVar("seamless_portals_align", "1", false, true, "Enable/Disable Portal creator alignment helper", 0, 1)
	CreateClientConVar("seamless_portals_toolsided", "1", false, true, "Enable/Disable whether the tooled side is the front.", 0, 1)

	function TOOL.BuildCPanel(panel)
		panel:AddControl("label", {text = "Creates and links portals"})
		panel:NumSlider("Portal Size X", "seamless_portals_size_x", 1, 1000, 1)
		panel:NumSlider("Portal Size Y", "seamless_portals_size_y", 1, 1000, 1)
		panel:NumSlider("Portal Size Z", "seamless_portals_size_z", 1, 100, 1)
		panel:NumSlider("Portal Sides", "seamless_portals_sides", 3, 100, 0)
        panel:CheckBox("Has Backface (Invisible until linked!)", "seamless_portals_backface")
        panel:CheckBox("Nudge Portals from walls", "seamless_portals_align")
        panel:CheckBox("Make Tooled side the front", "seamless_portals_toolsided")
	end
end

function TOOL:EasyExtrude(pos, dir, length)
    local tr = SeamlessPortals.TraceLine({
        start = pos,
        endpos = pos + dir * length,
        filter = self:GetOwner()
    })

    if tr.Hit then
        return pos - dir * (length * (1 - tr.Fraction) + 0.1)
    else
        return pos
    end
end

function TOOL:GetPlacementPosition(trace)
    if !trace.Hit then return nil end

    local owner = self:GetOwner()
    local portal_ang = trace.HitNormal:Angle()
    portal_ang:Add(Angle(90, 0, 0))

    -- rotate if on floor or ceiling
    if math.abs(trace.HitNormal:Dot(Vector(0, 0, 1))) > 0.99 then
    	portal_ang:Add(Angle(0, owner:EyeAngles()[2] + 180, 0))
    end

    local portal_pos = trace.HitPos + trace.HitNormal
    if owner:GetInfoNum("seamless_portals_align", 0) == 1 then
    	local nudge_x = owner:GetInfoNum("seamless_portals_size_x", 1) / 2
        local nudge_y = owner:GetInfoNum("seamless_portals_size_y", 1) / 2

        portal_pos = self:EasyExtrude(portal_pos, -portal_ang:Right(), nudge_y)
        portal_pos = self:EasyExtrude(portal_pos, portal_ang:Right(), nudge_y)
        portal_pos = self:EasyExtrude(portal_pos, -portal_ang:Forward(), nudge_x)
        portal_pos = self:EasyExtrude(portal_pos, portal_ang:Forward(), nudge_x)
    end
    portal_pos:Add(trace.HitNormal * owner:GetInfoNum("seamless_portals_size_z", 1))

    local portal_size = Vector(
		owner:GetInfoNum("seamless_portals_size_x", 1),
		owner:GetInfoNum("seamless_portals_size_y", 1),
		owner:GetInfoNum("seamless_portals_size_z", 1)
	)

    return portal_pos, portal_ang, portal_size
end

-- portal creation
function TOOL:LeftClick(trace)
	if !trace.Hit then return false end

	local pos, ang, size = self:GetPlacementPosition(trace)
	if !pos then return false end

	if CLIENT then return true end -- prediction

	local owner = self:GetOwner()
	local portal = ents.Create("seamless_portal")
	portal:SetPos(pos)
	portal:SetAngles(ang)
	portal:SetCreator(owner)
	portal:SetSize(size) -- set size before portal creation so it gets internally clamped
	portal:SetSides(owner:GetInfoNum("seamless_portals_sides", 4))
	portal:SetDisableBackface(owner:GetInfoNum("seamless_portals_backface", 1) == 0)
	portal:Spawn()

	if CPPI then
		portal:CPPISetOwner(owner)
	end

	cleanup.Add(owner, "props", portal)
	undo.Create("Seamless Portal")
		undo.AddEntity(portal)
		undo.SetPlayer(owner)
	undo.Finish()

	return true
end

-- portal linking
function TOOL:Deploy()
	self:SetStage(1)
end

function TOOL:SetLinkTarget(target)
	self:GetOwner():SetNWEntity("SEAMLESS_PORTALS_LINK_TARGET", target)
end

function TOOL:GetLinkTarget()
	return self:GetOwner():GetNWEntity("SEAMLESS_PORTALS_LINK_TARGET")
end


function TOOL:RightClick(trace)
	if !trace.Hit then return false end
	local owner = self:GetOwner()
	local portal = trace.Entity
	if !IsValid(portal) or portal:GetClass() ~= "seamless_portal" then return false end

	if CLIENT then return true end

	if owner:GetInfoNum("seamless_portals_toolsided", 0) == 1 then
		local side = -math.Sign(portal:GetUp():Dot(portal:GetPos() - self:GetOwner():GetShootPos()))
		local ent_ang = Angle(portal:GetAngles())

		if side < 0 then
			ent_ang:RotateAroundAxis(ent_ang:Forward(), 180)
			portal:SetPos(portal:GetPos() - portal:GetUp() * portal:GetSize()[3])
		end

		portal:SetAngles(ent_ang)
	end

	local stage = self:GetStage()
	if stage <= 1 then
		portal:UnlinkPortal()
		self:SetLinkTarget(portal)
		self:SetStage(2)
	else
		local portal_1 = self:GetLinkTarget()
		portal:LinkPortal(portal_1)
		self:SetStage(1)
	end

	return true
end

-- portal unlinking
function TOOL:Reload(trace)
	local portal = trace.Entity
	if !IsValid(portal) or portal:GetClass() ~= "seamless_portal" then return false end

	if CLIENT then return true end

	portal:SetExitPortal(nil)
	return true
end

-- client visual
if CLIENT then
	local green = Color(0, 255, 0, 50)
	local beam_material = Material("cable/blue_elec")
	function TOOL:DrawHUD()
		local owner = self:GetOwner()
		local trace = owner:GetEyeTrace()
        local pos, ang, size = self:GetPlacementPosition(trace)
		if not pos then return end

		cam.Start3D()
			if self:GetStage() == 2 then
				-- link mode
				local target = self:GetLinkTarget()
				if IsValid(target) then
					local from = target:GetPos()
					local to = trace.HitPos
					if IsValid(trace.Entity) then
						if trace.Entity:GetClass() == "seamless_portal" then
							to = trace.Entity:GetPos()
						end
					end
					render.SetMaterial(beam_material)
					render.DrawBeam(from, to, 3, 0, 1)
				end
			end
			-- regular mode
			local mins, maxs = Vector(size[1] * -0.5, size[2] * -0.5, -size[3]), Vector(size[1] * 0.5, size[2] * 0.5, 0)
			render.SetColorMaterial()
			render.DrawBox(pos, ang, mins, maxs, green)
			render.DrawWireframeBox(pos, ang, mins, maxs, green, true)
		cam.End3D()

		if self.Name == "Portal Fitter" then
			draw.DrawText(string.format("Size X: %.2f\n", size[1]), "HudDefault", 50, 230, color_white)
	        draw.DrawText(string.format("Size Y: %.2f\n", size[2]), "HudDefault", 50, 250, color_white)
	        draw.DrawText(string.format("Ratio: %.2f\n", size[2] / size[1]), "HudDefault", 50, 270, color_white)
        end
	end
end
