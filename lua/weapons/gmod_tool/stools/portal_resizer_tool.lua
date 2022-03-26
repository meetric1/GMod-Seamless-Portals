TOOL.Category = "Seamless Portals"
TOOL.Name = "#Tool.portal_resizer_tool.name"

if CLIENT then
	language.Add("Tool.portal_resizer_tool.name", "Portal Resizer")
	language.Add("Tool.portal_resizer_tool.desc", "Sets the size of portals")
	
	TOOL.ConvarX = CreateClientConVar("seamless_portal_size_x", "1", false, true, "Sets the size of the portal along the X axis", 0.01, 10)
	TOOL.ConvarY = CreateClientConVar("seamless_portal_size_y", "1", false, true, "Sets the size of the portal along the Y axis", 0.01, 10)
	TOOL.ConvarZ = CreateClientConVar("seamless_portal_size_z", "1", false, true, "Sets the size of the portal along the Z axis", 0.01, 10)

	TOOL.DisplayX = TOOL.ConvarX:GetInt()
	TOOL.DisplayY = TOOL.ConvarY:GetInt()
	TOOL.DisplayZ = TOOL.ConvarY:GetInt()

	TOOL.Information = {
		{name = "left"},
	}

	language.Add( "Tool.portal_resizer_tool.left", "Sets the size of portals" )

	function TOOL.BuildCPanel(panel)
		panel:AddControl("label", {
			text = "Sets the size of portals",
		})
		panel:NumSlider("Portal Size X", "seamless_portal_size_x", 0.05, 10, 2)
		panel:NumSlider("Portal Size Y", "seamless_portal_size_y", 0.05, 10, 2)
		panel:NumSlider("Portal Size Z", "seamless_portal_size_z", 0.05, 10, 2)
	end

	local COLOR_GREEN = Color(0, 255, 0, 50)
	function TOOL:DrawHUD()
		local traceTable = util.GetPlayerTrace(self:GetOwner())
		local trace = SeamlessPortals.TraceLine(traceTable)
		
		if !trace.Entity or trace.Entity:GetClass() != "seamless_portal" then return end	-- dont draw the world or else u crash lol

		local mins, maxs = trace.Entity:OBBMins(), trace.Entity:OBBMaxs()
		mins[3] = mins[3] * 3
		maxs[3] = 0

		cam.Start3D()
			render.SetColorMaterial()
			render.DrawBox(trace.Entity:GetPos(), trace.Entity:GetAngles(), mins, maxs, COLOR_GREEN)
		cam.End3D()
	end
end

function TOOL:LeftClick(trace)
	local traceTable = util.GetPlayerTrace(self:GetOwner())
	local trace = SeamlessPortals.TraceLine(traceTable)

	if !trace.Entity or trace.Entity:GetClass() != "seamless_portal" then return false end
	if CPPI and SERVER then if !trace.Entity:CPPICanTool(self:GetOwner(), "remover") then return false end end
	local sizex = self:GetOwner():GetInfoNum("seamless_portal_size_x", 1)
	local sizey = self:GetOwner():GetInfoNum("seamless_portal_size_y", 1)
	local sizez = self:GetOwner():GetInfoNum("seamless_portal_size_z", 1)
	trace.Entity:SetExitSize(Vector(sizex, sizey, sizez))
	return true
end

function TOOL:RightClick(trace)
	local traceTable = util.GetPlayerTrace(self:GetOwner())
	local trace = SeamlessPortals.TraceLine(traceTable)

	if !trace.Entity or trace.Entity:GetClass() != "seamless_portal" then return false end
	if CPPI and SERVER then if !trace.Entity:CPPICanTool(self:GetOwner(), "remover") then return false end end
	trace.Entity:SetExitSize(Vector(1, 1, 1))
	return true
end

