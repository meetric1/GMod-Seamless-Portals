include("sh_init.lua")

local varDrawDistance = CreateClientConVar(
	"seamless_portals_drawdistance",
    "250",
    true,
    true,
    "Sets the multiplier of how far a portal should render",
    0
)

function ENT:Initialize()
	table.insert(SeamlessPortals.Portals, self)
end

function ENT:OnRemove()
	timer.Simple(0, function()
		if IsValid(self) then return end
		table.RemoveByValue(SeamlessPortals.Portals, self)
	end)
end

local drawMat = Material("models/dav0r/hoverball")

local render_matrix = Matrix()
function ENT:GetRenderMesh()
	return {
		Mesh     = SeamlessPortals.GetRenderMesh(self:GetSides()),
		Matrix   = render_matrix,
		Material = drawMat
	}
end

function ENT:DrawModelMesh(portal_size, nudge_z)
	local draw_mesh = SeamlessPortals.GetRenderMesh(self:GetSides())
	local render_matrix = self:GetWorldTransformMatrix()
	render_matrix:SetScale(portal_size)
	if nudge_z then render_matrix:Translate(Vector(0, 0, (nudge_z - 1))) end
	cam.PushModelMatrix(render_matrix)
		draw_mesh:Draw()
	cam.PopModelMatrix()
end

-- So the size is in source units (remember we are using sine/cosine)
local size_mult = Vector(math.sqrt(2) / 2, math.sqrt(2) / 2, 1)

-- DrawModel inside of a non Draw hook will call Draw instead of DrawModel (thanks, gmod API)
-- this check is so we can call DrawModel inside of DrawStenciled
local draw_model = false
function ENT:DrawStenciled(texture, flip, nudge_z)
	draw_model = true

	local portal_size = self:GetSize()
	portal_size:Mul(size_mult)

	-- little nudge for MSAA, otherwise it will sample the edges outside the portal
	-- and lead to some pretty nasty artifacting
	portal_size:Mul(nudge_z or 1)

	local backface_disabled = self:GetDisableBackface()

	render_matrix:Identity()
	render_matrix:SetScale(portal_size)

	-- outside frame (backface)
	if !backface_disabled then
		self:DrawModel()
	end

	-- frame flat face
	if SeamlessPortals.Rendering or !IsValid(self:GetExitPortal()) then
		if !backface_disabled then
			portal_size[3] = 0
			render.CullMode(1)
				self:DrawModelMesh(portal_size)
			render.CullMode(0)
		end
	else
		render.ClearStencil()
		render.SetStencilWriteMask(255)
		render.SetStencilTestMask(255)
		render.SetStencilReferenceValue(1)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilPassOperation(STENCIL_REPLACE)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilEnable(true)
		render.SetMaterial(drawMat)

		-- Draw inside of portal
		render.CullMode(1)
			self:DrawModelMesh(portal_size, nudge_z)
		render.CullMode(0)

		render.SetStencilCompareFunction(STENCIL_EQUAL)

		if flip then
			render.DrawTextureToScreenRect(texture, ScrW(), 0, -ScrW(), ScrH())
		else
			render.DrawTextureToScreen(texture)
		end

		render.SetStencilEnable(false)
	end

	draw_model = false
end

function ENT:Draw(flags)
	-- resetting the stencil buffer when drawing halos will cause horrible flashing
	-- also, don't render the portal we're rendering out of
	if halo.RenderedEntity() == self or SeamlessPortals.Rendering == self then return end

	if draw_model then
		self:DrawModel(flags)
	else
		self:DrawStenciled(SeamlessPortals.PortalRT)
	end
end

function ENT:Think()
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
		phys:SetPos(self:GetPos())
		phys:SetAngles(self:GetAngles())
	else
		self:UpdatePhysmesh()
	end
end

-- Hacky bullet fix
if game.SinglePlayer() then
	function ENT:TestCollision(startpos, delta, isbox, extents, mask)
		if bit.band(mask, CONTENTS_GRATE) != 0 then return true end
	end
end

SeamlessPortals.DrawPlayerInView = true
SeamlessPortals.GetDrawDistance = function()
	return varDrawDistance:GetFloat()
end

-- Create meshes used for the portals
-- They can have a dynamic amount of sides
SeamlessPortals.PortalMeshes = {}
SeamlessPortals.GetRenderMesh = function(sides)
	if !SeamlessPortals.PortalMeshes[sides] then
		SeamlessPortals.PortalMeshes[sides] = Mesh()
		local meshTable = {}
		local ang_mul = 360 / sides
		local ang_pick = sides % 4 != 0 and 0 or 45
		local rad_offset = math.rad(sides * 90 + ang_pick)
		for side = 1, sides do
			local side1 = Vector(0, 0, -1)
			local sidex = math.rad(side * ang_mul) + rad_offset
			local sidey = math.rad((side + 1) * ang_mul) + rad_offset
			local side2 = Vector(math.sin(sidex), math.cos(sidex), -1)
			local side3 = Vector(math.sin(sidey), math.cos(sidey), -1)

			local streach1 = (side / sides) * 4
			local streach2 = ((side + 1) / sides) * 4

			table.insert(meshTable, {pos = side2, u = 0, v = 0})
			table.insert(meshTable, {pos = side1, u = 0, v = 1})
			table.insert(meshTable, {pos = side3, u = 1, v = 0})

			table.insert(meshTable, {pos = Vector(side2[1], side2[2], 0), u = streach1, v = 1})
			table.insert(meshTable, {pos = side2, u = streach1, v = 0})
			table.insert(meshTable, {pos = side3, u = streach2, v = 0})

			table.insert(meshTable, {pos = side3, u = streach2, v = 0})
			table.insert(meshTable, {pos = Vector(side3[1], side3[2], 0), u = streach2, v = 1})
			table.insert(meshTable, {pos = Vector(side2[1], side2[2], 0), u = streach1, v = 1})
		end
		SeamlessPortals.PortalMeshes[sides]:BuildFromTriangles(meshTable)
	end

	return SeamlessPortals.PortalMeshes[sides]
end

--Funny flipped scene
local mirrored = false
function SeamlessPortals.ToggleMirror(enable)
	if enable == nil then -- what the fuck is this
		return mirrored
	end

	mirrored = enable

	if (!enable) then
		hook.Remove("PreDrawViewModels", "seamless_portals_flip")
		hook.Remove("InputMouseApply", "seamless_portals_flip")
		hook.Remove("CreateMove", "seamless_portals_flip")

		return mirrored
	end

	hook.Add("PreDrawViewModels", "seamless_portals_flip", function()
		if SeamlessPortals.Rendering then return end

		render.UpdateScreenEffectTexture()
		render.DrawTextureToScreenRect(render.GetScreenEffectTexture(), ScrW(), 0, -ScrW(), ScrH())

		if LocalPlayer():Health() <= 0 then
			SeamlessPortals.ToggleMirror(false)
		end
	end)

	-- Invert mouse x
	hook.Add("InputMouseApply", "seamless_portals_flip", function(cmd, x, y, ang)
		cmd:SetViewAngles(ang + Angle(0, x / 22.5, 0))
	end)

	-- Invert movement x
	hook.Add("CreateMove", "seamless_portals_flip", function(cmd)
		cmd:SetSideMove(-cmd:GetSideMove())
	end)

	return mirrored
end

SeamlessPortals.ToggleMirror(false)
