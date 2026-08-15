TOOL.Category = "Seamless Portals"
TOOL.Name = "Portal Fitter"

TOOL.Information = {
    {name = "left"},
	{name = "right1", stage = 1},
    {name = "right2", stage = 2},
	{name = "reload"}
}

if CLIENT then
	language.Add("Tool.portal_fitter_tool.desc", "Creates a portal, fitted to each wall")
    language.Add("Tool.portal_fitter_tool.left", "Left Click: Create portal")
    language.Add("Tool.portal_fitter_tool.right1", "Right Click: Start linking a portal")
    language.Add("Tool.portal_fitter_tool.right2", "Right Click: Create link to another portal")
	language.Add("Tool.portal_fitter_tool.reload", "Reload: Unlink a portal")

    CreateClientConVar("seamless_portals_snap_angle", "90", false, true, "Portal Snap Angle, in Degrees", 0, 90)

	function TOOL.BuildCPanel(panel)
		panel:AddControl("label", {text = "Creates a fitted portal"})
		panel:NumSlider("Portal Snap Angle", "seamless_portals_snap_angle", 0, 90, 0)
		panel:NumSlider("Portal Size Z", "seamless_portals_size_z", 1, 100, 1)
		panel:CheckBox("Has Backface (Invisible until linked!)", "seamless_portals_backface")
	end
end

function TOOL:EasyTrace(pos, dir)
    return util.TraceLine({
        start = pos,
        endpos = pos + dir * 500,
        filter = self:GetOwner()
    })
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

    local size_x = down.HitPos:Distance(up.HitPos)
    local size_y = left.HitPos:Distance(right.HitPos)

    -- too small
    if size_x < 1 or size_y < 1 then
        return nil
    end

    ang:Add(Angle(90, 0, 0))

    -- subtract 0.1 from size to prevent zfighting
	return pos, ang, Vector(size_x - 0.1, size_y - 0.1, ply:GetInfoNum("seamless_portals_size_z", 1))
end



---
-- rest of the functions (mainly the linking and display) are reused from portal_creator_tool.lua
---
