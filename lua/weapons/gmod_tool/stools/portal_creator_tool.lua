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
	local cosTh = vec1:Dot(vec2) / (vec1:Length() * vec2:Length())
	return math.deg(math.acos(cosTh))
end

function TOOL:GetPlacementPosition(tr)
	local ply = self:GetOwner()
	if not tr then tr = ply:GetEyeTrace() end
	if not tr.Hit then return false end
	-- yoink! smiley :)
	local rotAng = tr.HitNormal:Angle(); rotAng.p = rotAng.p + 90
	local elevationangle = VectorAngle(vector_up, tr.HitNormal)
	if elevationangle < 1 or (elevationangle > 179 and elevationangle < 181) then 
		rotAng.y = ply:EyeAngles().y + 180
	end
	--
	return (tr.HitPos + tr.HitNormal * (ply:GetInfoNum("seamless_portal_size_z", 1) + 1)), rotAng
end

function TOOL:GetLinkTarget()
	if ( SERVER ) then
		return self.LinkTarget
	else
		return self:GetOwner():GetNWEntity("pct_linkTarget")
	end
end

if ( CLIENT ) then

	local green = Color(0, 255, 0, 50)

	language.Add("Tool.portal_creator_tool.name", "Portal Creator")
	language.Add("Tool.portal_creator_tool.desc", "Creates and links portals")
	language.Add("Tool.portal_creator_tool.left", "Left Click: Create portal")
	language.Add("Tool.portal_creator_tool.right1", "Right Click: Start linking a portal")
	language.Add("Tool.portal_creator_tool.right2", "Right Click: Create link to another portal")

	-- yoink! smiley :)
	local xVar = CreateClientConVar("seamless_portal_size_x", "100", false, true, "Sets the size of the portal along the X axis", 1, 1000)
	local yVar = CreateClientConVar("seamless_portal_size_y", "100", false, true, "Sets the size of the portal along the Y axis", 1, 1000)
	local zVar = CreateClientConVar("seamless_portal_size_z", "8", false, true, "Sets the size of the portal along the Z axis", 1, 100)
	local sidesVar = CreateClientConVar("seamless_portal_sides", "4", false, true, "Sets the number of sides the portal has", 3, 100)
	local backVar = CreateClientConVar("seamless_portal_backface", "1", false, true, "Sets whether to spawn with a backface or not", 0, 1)

	function TOOL.BuildCPanel(panel)
		panel:AddControl("label", {text = "Creates and links portals"})
		panel:NumSlider("Portal Size X", "seamless_portal_size_x", 1, 1000, 1)
		panel:NumSlider("Portal Size Y", "seamless_portal_size_y", 1, 1000, 1)
		panel:NumSlider("Portal Size Z", "seamless_portal_size_z", 1, 100, 1)
		panel:NumSlider("Portal Sides", "seamless_portal_sides", 3, 100, 0)
		panel:CheckBox("Has Backface (Invisible until linked!)", "seamless_portal_backface")
	end

	local beamMat = Material("cable/blue_elec")
	function TOOL:DrawHUD()
		local pos, ang = self:GetPlacementPosition()
		if not pos then return end
		--
		cam.Start3D()
			if self:GetStage() == 2 then
				local target = self:GetLinkTarget()
				if IsValid(target) then
					local to = pos
					local ply = self:GetOwner()
					local from = target:GetPos()
					local tr = ply:GetEyeTrace()
					-- the tower of if statements
					if tr.Hit then
						local ent = tr.Entity
						if IsValid(ent) then
							if ent:GetClass() == "seamless_portal" then
								if ent:EntIndex() ~= target:EntIndex() then
									to = ent:GetPos()
								end
							end
						end
					end
					render.SetMaterial(beamMat)
					render.DrawBeam(from, to, 3, 0, 1)
					cam.End3D()
					return
				end
			end
			local xScale = xVar:GetFloat() * 0.5
			local yScale = yVar:GetFloat() * 0.5
			local zScale = zVar:GetFloat()
			render.SetColorMaterial()
			render.DrawBox(pos, ang, Vector(-xScale, -yScale, -zScale), Vector(xScale, yScale, 0), green)
		cam.End3D()
	end

	function TOOL:LeftClick()
		return true
	end

	function TOOL:RightClick()
		return true
	end

elseif ( SERVER ) then

	function TOOL:Deploy()
		self:SetStage(1)
	end

	function TOOL:LeftClick(trace)
		local pos, ang = self:GetPlacementPosition(trace)
		if not pos then return false end
		local ent = ents.Create("seamless_portal")
		if not IsValid(ent) then return false end
		local ply = self:GetOwner()
		ang.p = ang.p + 270
		ent:SetPos(pos)
		ent:SetAngles(ang)
		ent:SetCreator(ply)
		ent:Spawn()
		if CPPI then ent:CPPISetOwner(ply) end
		-- yoink! smiley, no fun allowed
		local sizex = math.Clamp(ply:GetInfoNum("seamless_portal_size_x", 1) * 0.5, 1, 500)
		local sizey = math.Clamp(ply:GetInfoNum("seamless_portal_size_y", 1) * 0.5, 1, 500)
		local sizez = math.Clamp(ply:GetInfoNum("seamless_portal_size_z", 1), 1, 100)
		ent:SetSize(Vector(sizex, sizey, sizez))
		ent:SetDisableBackface(ply:GetInfoNum("seamless_portal_backface", 1) == 0)
		ent:SetSides(ply:GetInfoNum("seamless_portal_sides", 4))
		cleanup.Add(ply, "props", ent)
		undo.Create("Seamless Portal")
			undo.AddEntity(ent)
			undo.SetPlayer(ply)
		undo.Finish()
		return true
	end

	function TOOL:SetLinkTarget(ent)
		self.LinkTarget = ent
		self:GetOwner():SetNWEntity("pct_linkTarget", ent)
	end

	function TOOL:GetTarget(trace)
		if not trace.Hit then return NULL end
		local ent = trace.Entity
		if not IsValid(ent) then return NULL end
		if ent:GetClass() ~= "seamless_portal" then return NULL end
		if CPPI then
			if not ent:CPPICanTool(self:GetOwner(), "portal_creator_tool") then return NULL end
		end
		return ent
	end

	function TOOL:RightClick(trace)
		local ent = self:GetTarget(trace)
		if not IsValid(ent) then
			self:SetStage(1)
			return false
		end
		local stage = self:GetStage()
		if (stage <= 1) then
			self:SetLinkTarget(ent)
			self:SetStage(2)
		else -- Linking a portal to itself for mirror dimension
			local link = self:GetLinkTarget()
			-- LinkPortal already contains an IsValid check
			ent:LinkPortal(link)
			self:SetStage(1)
		end
		return true
	end

	function TOOL:Reload(trace)
		local ent = self:GetTarget(trace)
		if not IsValid(ent) then return false end
		local ply = self:GetOwner()
		if ply:IsAdmin() or ent:GetCreator() == ply
			then SafeRemoveEntity(ent)
		end
		return true
	end

end
