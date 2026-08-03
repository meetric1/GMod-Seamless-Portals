TOOL.Category = "Seamless Portals"
TOOL.Name = "#Tool.portal_fitter_tool.name"

TOOL.Information = {
    { name = "left" },
	{ name = "right1", stage = 1 },
	{ name = "right2", stage = 2 }
}

TOOL.LinkTarget = NULL

function TOOL:EasyTrace(pos, dir)
    return util.TraceLine({
        start = pos,
        endpos = pos + dir * 1000,
        filter = self:GetOwner()
    })
end

function TOOL:GetLinkTarget()
	if ( SERVER ) then
		return self.LinkTarget
	else
		return self:GetOwner():GetNWEntity("pct_linkTarget")
	end
end

function TOOL:GetPlacementPosition(tr)
	local ply = self:GetOwner()
	if not tr then tr = ply:GetEyeTrace() end
    if not tr.Hit then return nil end

    local ang = ply:EyeAngles()

    -- bias pitch a bit, because its more likely we are placing on a wall
    ang[1] = math.Round(-ang[1] * (1 - 90 / 360) / 90) * 90

    ang[2] = ang[2] + 180
    local snap_angle = ply:GetInfoNum("seamless_portals_snap_angle", 90)
    if snap_angle > 1 then
        ang[2] = math.Round(ang[2] / snap_angle) * snap_angle
    end

    tr.HitNormal:Mul(ply:GetInfoNum("seamless_portals_size_z", 1) + 1)

    local left = self:EasyTrace(tr.HitPos + tr.HitNormal, -ang:Right())
    local right = self:EasyTrace(tr.HitPos + tr.HitNormal, ang:Right())

    local pos = (left.HitPos + right.HitPos) / 2
    local down = self:EasyTrace(pos, -ang:Up())
    local up = self:EasyTrace(pos, ang:Up())
    pos = (down.HitPos + up.HitPos) / 2

    local size_x = down.HitPos:Distance(up.HitPos) / 2
    local size_y = left.HitPos:Distance(right.HitPos) / 2

    -- too small
    if size_x < 1 or size_y < 1 then
        return nil
    end

    -- subtract 0.1 from size to prevent zfighting
	return pos, ang, Vector(size_x - 0.1, size_y - 0.1)
end

if ( CLIENT ) then

	local green = Color(0, 255, 0, 50)

	language.Add("Tool.portal_fitter_tool.name", "Portal Fitter")
	language.Add("Tool.portal_fitter_tool.desc", "Creates a portal, fitted to each wall")
    language.Add("Tool.portal_fitter_tool.left", "Left Click: Create portal")
    language.Add("Tool.portal_fitter_tool.right1", "Right Click: Start linking a portal")
	language.Add("Tool.portal_fitter_tool.right2", "Right Click: Create link to another portal")

    local snap_angle = CreateClientConVar("seamless_portals_snap_angle", "90", false, true, "Portal Snap Angle, in Degrees", 0, 90)
	local zVar = CreateClientConVar("seamless_portals_size_z", "8", false, true, "Sets the size of the portal along the Z axis", 1, 100)
	local backVar = CreateClientConVar("seamless_portals_backface", "1", false, true, "Sets whether to spawn with a backface or not", 0, 1)

	function TOOL.BuildCPanel(panel)
		panel:AddControl("label", {text = "Creates a fitted portal"})
		panel:NumSlider("Portal Snap Angle", "seamless_portals_snap_angle", 0, 90, 0)
		panel:NumSlider("Portal Size Z", "seamless_portals_size_z", 1, 100, 1)
		panel:CheckBox("Has Backface (Invisible until linked!)", "seamless_portals_backface")
	end

	local beamMat = Material("cable/blue_elec")
	function TOOL:DrawHUD()
		local pos, ang, scl = self:GetPlacementPosition()
        if not pos then return end

        ang:Add(Angle(90, 0, 0))

        cam.Start3D()
        	if self:GetStage() == 2 then
				local target = self:GetLinkTarget()
            if IsValid(target) then
            		local ply = self:GetOwner()
					local tr = ply:GetEyeTrace()
					local to = tr.HitPos
					local from = target:GetPos()
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
				end
			else
				render.SetColorMaterial()
				render.DrawBox(pos, ang, Vector(-scl[1], -scl[2], -zVar:GetFloat()), scl, green)
	         end
        cam.End3D()

        draw.DrawText(string.format("Size X: %.2f\n", scl[1] * 2), "HudDefault", 50, 210, color_white)
        draw.DrawText(string.format("Size Y: %.2f\n", scl[2] * 2), "HudDefault", 50, 230, color_white)
        draw.DrawText(string.format("Ratio: %.2f\n", scl[2] / scl[1]), "HudDefault", 50, 250, color_white)
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
        local pos, ang, scl = self:GetPlacementPosition(trace)
        if not pos then return false end

        local ent = ents.Create("seamless_portal")
        if not IsValid(ent) then return false end
        local ply = self:GetOwner()
        ent:SetPos(pos)
        ent:SetAngles(ang)
        ent:SetCreator(ply)
        ent:Spawn()
        if CPPI then ent:CPPISetOwner(ply) end

        local sizez = math.Clamp(ply:GetInfoNum("seamless_portals_size_z", 1), 1, 100)
        ent:SetSize(Vector(scl[1], scl[2], sizez))
        ent:SetDisableBackface(ply:GetInfoNum("seamless_portals_backface", 1) == 0)
        ent:SetSides(4)

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
			local linkTarget = self:GetLinkTarget()
			-- LinkPortal already contains an IsValid check
			ent:LinkPortal(linkTarget)
			self:SetStage(1)
		end
		return true
	end
end
