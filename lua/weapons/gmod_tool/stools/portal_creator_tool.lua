 
TOOL.Category = "Seamless Portals"
TOOL.Name = "#Tool.portal_creator_tool.name"

TOOL.Information = {
	{ name = "left" },
	{ name = "right1", stage = 1 },
	{ name = "right2", stage = 2 }
}

TOOL.LinkTarget = NULL

-- yoink! smiley :)
local function VectorAngle(vec1, vec2)
	local costheta = vec1:Dot(vec2) / (vec1:Length() * vec2:Length())
	local theta = math.acos(costheta)
	return math.deg(theta)
end

function TOOL:GetPlacementPosition(tr)
	if not tr then tr = self:GetOwner():GetEyeTrace() end
	if not tr.Hit then return false end
	-- yoink! smiley :)
	local rotatedAng = tr.HitNormal:Angle() + Angle(90, 0, 0)

	local elevationangle = VectorAngle(vector_up, tr.HitNormal)
	if elevationangle < 1 or (elevationangle > 179 and elevationangle < 181) then 
		rotatedAng.y = self:GetOwner():EyeAngles().y + 180
	end
	--
	return (tr.HitPos + tr.HitNormal * 10), rotatedAng
end

if ( CLIENT ) then

	local green = Color(0, 255, 0, 50)

	language.Add("Tool.portal_creator_tool.name", "Portal Creator")
	language.Add("Tool.portal_creator_tool.desc", "Creates and links portals")
	language.Add("Tool.portal_creator_tool.left", "Left Click: Create portal")
	language.Add("Tool.portal_creator_tool.right1", "Right Click: Start linking a portal")
	language.Add("Tool.portal_creator_tool.right2", "Right Click: Create link to another portal")

	-- yoink! smiley :)
	local xVar = CreateClientConVar("seamless_portal_size_x", "1", false, true, "Sets the size of the portal along the X axis", 0.01, 10)
	local yVar = CreateClientConVar("seamless_portal_size_y", "1", false, true, "Sets the size of the portal along the Y axis", 0.01, 10)

	function TOOL.BuildCPanel(panel)
		panel:AddControl("label", {
			text = "Creates and links portals",
		})
		panel:NumSlider("Portal Size X", "seamless_portal_size_x", 0.05, 10, 2)
		panel:NumSlider("Portal Size Y", "seamless_portal_size_y", 0.05, 10, 2)
	end

	local beamMat = Material("cable/blue_elec")
	function TOOL:DrawHUD()
		local pos, angles = self:GetPlacementPosition()
		if not pos then return end
		--
		cam.Start3D()
			if self:GetStage() == 2 then
				if IsValid(self.LinkTarget) then
					local from = self.LinkTarget:GetPos()
					local to = pos
					local tr = self.Owner:GetEyeTrace()
					-- the tower of if statements
					if tr.Hit then
						local ent = tr.Entity
						if IsValid(ent) then
							if ent:GetClass() == "seamless_portal" then
								if ent:EntIndex() ~= self.LinkTarget:EntIndex() then
									to = ent:GetPos()
								end
							end
						end
					end
					render.SetMaterial(beamMat)
					render.DrawBeam(from, to, 3, 0, 1)
				end
			else
				local xScale = xVar:GetFloat()
				local yScale = yVar:GetFloat()
				render.SetColorMaterial()
				render.DrawBox(pos, angles, Vector(-47.45 * xScale, -47.45 * yScale, -1.5), Vector(47.45 * xScale, 47.45 * yScale, 1.5), green)
			end
		cam.End3D()
	end

	function TOOL:LeftClick() end

elseif ( SERVER ) then

	function TOOL:Deploy()
		self:SetStage(1)
	end

	function TOOL:LeftClick(trace)
		local pos, angles = self:GetPlacementPosition(trace)
		if not pos then return end
		local ent = ents.Create("seamless_portal")
		ent:SetPos(pos)
		ent:SetAngles(angles + Angle(270, 0, 0))
		ent:Spawn()
		if CPPI then ent:CPPISetOwner(self:GetOwner()) end
		-- yoink! smiley
		local sizex = self:GetOwner():GetInfoNum("seamless_portal_size_x", 1)
		local sizey = self:GetOwner():GetInfoNum("seamless_portal_size_y", 1)
		ent:SetExitSize(Vector(sizex, sizey, 1))
		cleanup.Add(self:GetOwner(), "props", ent)
	end

end

function TOOL:RightClick(trace)
	if not trace.Hit then
		self:SetStage(1)
		return
	end
	local ent = trace.Entity
	if not ent then
		self:SetStage(1)
		return
	end
	if ent:GetClass() ~= "seamless_portal" then
		self:SetStage(1)
		return
	end

	local stage = self:GetStage()
	if (stage <= 1) then
		self.LinkTarget = ent
		self:SetStage(2)
	else
		if (ent:EntIndex() == self.LinkTarget:EntIndex()) then
			self:SetStage(1)
			return
		end
		-- LinkPortal already contains an IsValid check
		ent:LinkPortal(self.LinkTarget)
		self:SetStage(1)
	end
end
