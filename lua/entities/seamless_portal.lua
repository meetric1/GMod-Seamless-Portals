-- Seamless portals addon by Mee
-- You may use this code as a reference for your own projects, but please do not publish this addon as your own.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     = "Seamless Portals"
ENT.PrintName    = "Seamless Portal"
ENT.Author       = "Mee"
ENT.Purpose      = ""
ENT.Instructions = ""
ENT.Spawnable    = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

-- create global table
SeamlessPortals = SeamlessPortals or {}

local varDrawDistance = CreateClientConVar("seamless_portal_drawdistance", "250", true, true, "Sets the multiplier of how far a portal should render", 0)

local function setDupeLink(ply, ent, dat)
	if CLIENT then return true end
	if not IsValid(ply) then return end
	ent.PORTAL_DUPE_LINK = ent.PORTAL_DUPE_LINK or {}
	ent.PORTAL_DUPE_LINK = table.Merge(ent.PORTAL_DUPE_LINK, dat, true)
	duplicator.StoreEntityModifier(ent, "seamless_portal_dupelink", ent.PORTAL_DUPE_LINK)
end

duplicator.RegisterEntityModifier("seamless_portal_dupelink", setDupeLink)

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "ExitPortal")
	self:NetworkVar("Vector", 0, "SizeInternal")
	self:NetworkVar("Bool", 0, "DisableBackface")
	self:NetworkVar("Int", 0, "SidesInternal")

	if self:GetSidesInternal() < 1 then
		self:SetSidesInternal(4)
	end
end

function ENT:LinkPortal(ent)
	if !IsValid(ent) then return end
	self:SetExitPortal(ent)
	ent:SetExitPortal(self)
	setDupeLink(self:GetCreator(), self, {Sors = self:EntIndex(), Dest = ent:EntIndex()})
end

function ENT:UnlinkPortal()
	local exitPortal = self:GetExitPortal()
	if IsValid(exitPortal) then
		exitPortal:SetExitPortal(nil)
	end
	self:SetExitPortal(nil)
	setDupeLink(self:GetCreator(), self, {Sors = false, Dest = false})
end

function ENT:SetSides(sides)
	local shouldUpdatePhysmesh = self:GetSidesInternal() != sides
	self:SetSidesInternal(math.Clamp(sides, 3, 100))
	if shouldUpdatePhysmesh then self:UpdatePhysmesh() end
end

-- custom size for portal
function ENT:SetSize(n)
	self:SetSizeInternal(n)
	self:UpdatePhysmesh(n)
end

function ENT:SetRemoveExit(bool)
	self.PORTAL_REMOVE_EXIT = bool
	setDupeLink(self:GetCreator(), self, {Reme = true})
end

function ENT:GetRemoveExit(bool)
	return self.PORTAL_REMOVE_EXIT
end

function ENT:GetSize()
	return self:GetSizeInternal()
end

local outputs = {
	["OnTeleportFrom"] = true,
	["OnTeleportTo"]   = true
}

if SERVER then
	function ENT:PostEntityPaste(ply, ent, cre)
		if not IsValid(ply) then return end
		for key, ent in pairs(cre) do
			-- Validate dupe data table
			local link = ent.PORTAL_DUPE_LINK
			if not link then break end
			-- Check source portal
			if not link.Sors then break end
			local sors = cre[link.Sors]
			if not IsValid(sors) then break end
			-- Check destination portal
			if not link.Dest then break end
			local dest = cre[link.Dest]
			if not IsValid(dest) then break end
			-- Create link and load remove exit
			sors:LinkPortal(dest)
			sors:SetRemoveExit(tobool(link.Reme))
		end
	end

	function ENT:KeyValue(key, value)
		if key == "link" then
			timer.Simple(0, function() self:SetExitPortal(ents.FindByName(value)[1]) end)
		elseif key == "backface" then
			self:SetDisableBackface(value == "1")
		elseif key == "size" then
			local size = string.Split(value, " ")
			self:SetSizeInternal(Vector(size[2] * 0.5, size[1] * 0.5, size[3]))
		elseif outputs[key] then
			self:StoreOutput(key, value)
		end
	end

	function ENT:AcceptInput(input, activator, caller, data)
		if input == "Link" then
			self:SetExitPortal(ents.FindByName(data)[1])
		end
	end
end

-- So the size is in source units (remember we are using sine/cosine)
local size_mult = Vector(math.sqrt(2), math.sqrt(2), 1)

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)

		if self:GetSize() == Vector() then
			self:SetSize(Vector(50, 50, 8))
		else
			self:SetSize(self:GetSize())
		end
	end

	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
end

function ENT:SpawnFunction(ply, tr)
	local portal1 = ents.Create("seamless_portal")
	if not IsValid(portal1) then return end

	portal1:SetPos(tr.HitPos + tr.HitNormal * 160)
	portal1:SetCreator(ply)
	portal1:Spawn()

	local portal2 = ents.Create("seamless_portal")
	if not IsValid(portal2) then return end

	portal2:SetPos(tr.HitPos + tr.HitNormal * 50)
	portal2:SetCreator(ply)
	portal2:Spawn()

	if CPPI then portal2:CPPISetOwner(ply) end

	portal1:LinkPortal(portal2)
	portal2:LinkPortal(portal1)

	portal1:SetRemoveExit(true)
	portal2:SetRemoveExit(true)

	return portal1
end

function ENT:OnRemove()
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:GetExitPortal())
	end

	SeamlessPortals.PortalIndex = math.max(SeamlessPortals.PortalIndex - 1, 0)
end

-- There's gonna be a bunch of magic numbers in this rendering code
-- Garry decided a hunter plate should be 47.9 rendering units wide and 51 physical units
if CLIENT then
	local drawMat = Material("models/dav0r/hoverball")

	local render_matrix = Matrix()
	function ENT:GetRenderMesh()
		return {
			Mesh     = SeamlessPortals.GetRenderMesh(self:GetSidesInternal()),
			Matrix   = render_matrix,
			Material = drawMat
		}
	end

	function ENT:DrawModelMesh(portalSize)
		local draw_mesh = SeamlessPortals.GetRenderMesh(self:GetSidesInternal())
		local render_matrix = self:GetWorldTransformMatrix()
		render_matrix:SetScale(portalSize)
		cam.PushModelMatrix(render_matrix)
			draw_mesh:Draw()
		cam.PopModelMatrix()
	end

	-- DrawModel inside of a non Draw hook will call Draw instead of DrawModel (thanks, gmod API)
	-- this check is so we can call DrawModel inside of DrawStenciled
	local draw_model = false
	function ENT:DrawStenciled(texture, flip)
		draw_model = true

		local portalSize = self:GetSize()
		portalSize:Mul(size_mult)

		local backface_disabled = self:GetDisableBackface()

		self:SetRenderBounds(-portalSize, portalSize)

		render_matrix:Identity()
		render_matrix:SetScale(portalSize)

		-- outside frame (backface)
		if !backface_disabled then
			self:DrawModel()
		end

		-- frame flat face
		if SeamlessPortals.Rendering or !IsValid(self:GetExitPortal()) then
			if !backface_disabled then
				portalSize[3] = 0
				render.CullMode(1)
					self:DrawModelMesh(portalSize)
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
				self:DrawModelMesh(portalSize)
			render.CullMode(0)

			render.SetStencilCompareFunction(STENCIL_EQUAL)

			if flip then
				render.DrawTextureToScreenRect(texture, ScrW(), 0, -ScrW(), ScrH())
			else
				render.DrawTextureToScreenRect(texture, 0, 0, ScrW(), ScrH())
			end

			render.SetStencilEnable(false)
		end

		draw_model = false
	end

	function ENT:Draw(flags)
		-- resetting the stencil buffer when drawing halos will cause horrible flashing
		if draw_model or halo.RenderedEntity() == self then
			self:DrawModel(flags)
		else
			self:DrawStenciled(SeamlessPortals.PortalRT)
		end
	end

	-- Hacky bullet fix
	if game.SinglePlayer() then
		function ENT:TestCollision(startpos, delta, isbox, extents, mask)
			if bit.band(mask, CONTENTS_GRATE) != 0 then return true end
		end
	end
end

-- Scale the phys mesh
function ENT:UpdatePhysmesh()
	if SERVER or !self:GetPhysicsObject():IsValid() then
		local finalMesh = {}
		local sizev = self:GetSize() * size_mult
		local sides = self:GetSidesInternal()
		local angleMul = 360 / sides
		local degreeOffset = (sides * 90 + (sides % 4 != 0 and 0 or 45)) * (math.pi / 180)
		for side = 1, sides do
			local sidea = math.rad(side * angleMul) + degreeOffset
			local sidex = math.sin(sidea)
			local sidey = math.cos(sidea)
			local side1 = Vector(sidex, sidey, -1)
			local side2 = Vector(sidex, sidey,  0)
			table.insert(finalMesh, side1 * sizev)
			table.insert(finalMesh, side2 * sizev)
		end
		self:PhysicsInitConvex(finalMesh)
		self:EnableCustomCollisions(true)
		self:GetPhysicsObject():EnableMotion(false)
		self:GetPhysicsObject():SetMaterial("glass")
		self:GetPhysicsObject():SetMass(250)
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

SeamlessPortals.TransformPortal = function(a, b, pos, ang)
	if !IsValid(a) or !IsValid(b) then return Vector(), Angle() end
	local editedPos = Vector()
	local editedAng = Angle()

	if pos then
		editedPos = a:WorldToLocal(pos) * (b:GetSize()[1] / a:GetSize()[1])
		editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
		editedPos = editedPos + b:GetUp() * 0.01 -- So you don't become trapped
	end

	if ang then
		local localAng = a:WorldToLocalAngles(ang)
		editedAng = b:LocalToWorldAngles(Angle(-localAng[1], -localAng[2], localAng[3] + 180))
	end

	-- Mirror portal
	if a == b then
		if pos then
			editedPos = a:LocalToWorld(a:WorldToLocal(pos) * Vector(1, 1, -1))
		end

		if ang then
			local localAng = a:WorldToLocalAngles(ang)
			editedAng = a:LocalToWorldAngles(Angle(-localAng[1], localAng[2], -localAng[3] + 180))
		end
	end

	return editedPos, editedAng
end

util.TraceLine = SeamlessPortals.NewTraceLine -- Trace line that can go through portals
SeamlessPortals.PortalIndex = 0

-- Only render the portals that are in the frustum, or should be rendered
SeamlessPortals.ShouldRender = function(portal, eyePos, eyeAngle, distance)
  if portal:IsDormant() then return false end
	local portalPos, portalUp, exitSize = portal:GetPos(), portal:GetUp(), portal:GetSize()
	local max, eye = math.max(exitSize[1], exitSize[2]), (eyePos - portalPos)
	-- (eyePos - portalPos):Dot(portalUp) > (-10 * max) -- true if behind the portal, false otherwise
	-- eyePos:DistToSqr(portalPos) < distance^2 * max -- true if close enough
	-- (eyePos - portalPos):Dot(eyeAngle:Forward()) < 50 * max -- true if looking at the portal, false otherwise
	if(eye:Dot(portalUp) <= -exitSize[3]) then return false end -- First condition is not met so bail put
	if(eye:LengthSqr() >= distance^2 * max) then return false end -- Second condition is not met so bail put
	return (eye:Dot(eyeAngle:Forward()) < max) -- Decides the return value of the function
end

-- Set phys mesh position on client
if CLIENT then
	SeamlessPortals.GetDrawDistance = function()
		return varDrawDistance:GetFloat()
	end

	SeamlessPortals.PortalRT = GetRenderTarget("seamless_portal_rt", ScrW(), ScrH())

	-- Create meshes used for the portals
	-- They can have a dynamic amount of sides
	SeamlessPortals.PortalMeshes = {}
	SeamlessPortals.GetRenderMesh = function(sides)
		if !SeamlessPortals.PortalMeshes[sides] then
			SeamlessPortals.PortalMeshes[sides] = Mesh()

			local meshTable = {}
			local angleMul = 360 / sides
			local degreeOffset = (sides * 90 + (sides % 4 != 0 and 0 or 45)) * (math.pi / 180)
			for side = 1, sides do
				local side1 = Vector(0, 0, -1)
				local sidex = math.rad(side * angleMul) + degreeOffset
				local sidey = math.rad((side + 1) * angleMul) + degreeOffset
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

	function ENT:Think()
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:EnableMotion(false)
			phys:SetPos(self:GetPos())
			phys:SetAngles(self:GetAngles())

		-- if held with gravity gun it will rebuild the physmesh every frame. ensure to check velocity
		elseif self:GetVelocity() == Vector() then
			self:UpdatePhysmesh()
		end
	end

	--Funny flipped scene
	local rendering = false
	local mirrored = false
	function SeamlessPortals.ToggleMirror(enable)
		if enable == nil then -- what the fuck is this
			return mirrored
		end

		mirrored = enable

		if (!enable) then
			hook.Remove("PreDrawViewModels", "FlippedWorld")
			hook.Remove("InputMouseApply", "FlippedWorld")
			hook.Remove("CreateMove", "FlippedWorld")

			return mirrored
		end

		hook.Add("PreDrawViewModels", "FlippedWorld", function(_, sky, sky3d)
			if SeamlessPortals.Rendering then return end

			render.UpdateScreenEffectTexture()
			render.DrawTextureToScreenRect(render.GetScreenEffectTexture(), ScrW(), 0, -ScrW(), ScrH())

			if LocalPlayer():Health() <= 0 then
				SeamlessPortals.ToggleMirror(false)
			end
		end)

		-- Invert mouse x
		hook.Add("InputMouseApply", "FlippedWorld", function(cmd, x, y, ang)
			cmd:SetViewAngles(ang + Angle(0, x / 22.5, 0))
		end)

		-- Invert movement x
		hook.Add("CreateMove", "FlippedWorld", function(cmd)
			cmd:SetSideMove(-cmd:GetSideMove())
		end)

		return mirrored
	end

	SeamlessPortals.ToggleMirror(false)
end
