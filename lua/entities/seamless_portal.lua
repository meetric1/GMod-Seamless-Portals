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

local gbSvFlag = bit.bor(FCVAR_ARCHIVE)
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
	setDupeLink(self:GetCreator(), self, {Dest = ent:EntIndex()})
end

function ENT:UnlinkPortal()
	local exit = self:GetExitPortal()
	if IsValid(exit) then
		exit:SetExitPortal(nil)
	end
	self:SetExitPortal(nil)
	setDupeLink(self:GetCreator(), self, {Dest = false})
end

function ENT:SetSides(sides)
	local umesh = (self:GetSidesInternal() != sides)
	self:SetSidesInternal(math.Clamp(sides, 3, 100))
	if umesh then self:UpdatePhysmesh() end
	setDupeLink(self:GetCreator(), self, {Side = sides})
end

-- custom size for portal
function ENT:SetSize(v)
	self:SetSizeInternal(v)
	self:UpdatePhysmesh(v)
	setDupeLink(self:GetCreator(), self, {Size = v})
end

function ENT:GetSize()
	return self:GetSizeInternal()
end

function ENT:SetRemoveExit(bool)
	self.PORTAL_REMOVE_EXIT = bool
	setDupeLink(self:GetCreator(), self, {Reme = true})
end

function ENT:GetRemoveExit(bool)
	return self.PORTAL_REMOVE_EXIT
end

local outputs = {
	["OnTeleportFrom"] = true,
	["OnTeleportTo"]   = true
}

if SERVER then

	function ENT:PostEntityPaste(ply, ent, cre)
		if not IsValid(ply) then return end
			-- Validate dupe data table
		local link = self.PORTAL_DUPE_LINK
		if not link then return end
		-- Check destination portal
		if link.Dest then
			local dest = cre[link.Dest]
			if IsValid(dest) then
				self:LinkPortal(dest)
			end
		end
		-- Check portal sides
		if link.Side then
			self:SetSides(link.Side)
		end
		-- Check portal size
		if link.Size then
			self:SetSize(link.Size)
		end
		-- Create link and load remove exit
		self:SetRemoveExit(tobool(link.Reme))
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

local function incrementPortal(ent)
	if CLIENT then	-- Single player is weird... Don't generate a phys mesh if its single player
		if ent.UpdatePhysmesh then
			ent:UpdatePhysmesh()
		else
			-- takes a minute to try and find the portal, if it cant, oh well...
			timer.Create("seamless_portal_init" .. SeamlessPortals.PortalIndex, 1, 60, function()
				if !ent or !ent:IsValid() or !ent.UpdatePhysmesh then return end

				ent:UpdatePhysmesh()
				timer.Remove("seamless_portal_init" .. SeamlessPortals.PortalIndex)
			end)
		end

		local size = ent:GetSize() * size_mult
		ent:SetRenderBounds(-size, size)
	end
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
end

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

		SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
	end
	SeamlessPortals.UpdateTraceline()
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
	SeamlessPortals.PortalIndex = math.Max(SeamlessPortals.PortalIndex - 1, 0)
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:GetExitPortal())
	end

	SeamlessPortals.UpdateTraceline()
end

-- There's gonna be a bunch of magic numbers in this rendering code
-- Garry decided a hunter plate should be 47.9 rendering units wide and 51 physical units
if CLIENT then
	local drawMat = Material("models/dav0r/hoverball")

	function ENT:GetRenderMesh()
		local side = self:GetSidesInternal()
		return {
			Mesh     = SeamlessPortals.GetRenderMesh(side)[1],
			Matrix   = self.RENDER_MATRIX_LOCAL,
			Material = drawMat
		}
	end

	local cam, render = cam, render
	function ENT:Draw()
		if halo.RenderedEntity() == self then return end
		local size = self:GetSize()
		-- Render the outside frame
		local portalSize = size * size_mult
		local backface = self:GetDisableBackface()
		if self.RENDER_MATRIX:GetTranslation() != self:GetPos() or
		   self.RENDER_MATRIX:GetScale() != portalSize
		then
			self.RENDER_MATRIX:Identity()
			self.RENDER_MATRIX:SetTranslation(self:GetPos())
			self.RENDER_MATRIX:SetAngles(self:GetAngles())
			self.RENDER_MATRIX:SetScale(portalSize * 0.999)

			if self.RENDER_MATRIX_LOCAL then
				self.RENDER_MATRIX_LOCAL:Identity()
			else
				self.RENDER_MATRIX_LOCAL = Matrix()
			end
			self.RENDER_MATRIX_LOCAL:SetScale(portalSize)

			if not self.RENDER_MATRIX_FLAT then
				self.RENDER_MATRIX_FLAT = Matrix()
			end

			self:SetRenderBounds(-portalSize, portalSize)

			portalSize[3] = 0
			self.RENDER_MATRIX_FLAT:Set(self.RENDER_MATRIX)
			self.RENDER_MATRIX_FLAT:SetScale(portalSize)
		end

		if !backface then
			self:DrawModel()
		end

		-- Draw inside of portal
		if SeamlessPortals.Rendering or
		   !IsValid(self:GetExitPortal()) or
		   !SeamlessPortals.ShouldRender(self, EyePos(), EyeAngles(), SeamlessPortals.GetDrawDistance())
		then
			if !backface then
				cam.PushModelMatrix(self.RENDER_MATRIX_FLAT)
					SeamlessPortals.GetRenderMesh(self:GetSidesInternal())[2]:Draw()
				cam.PopModelMatrix()
			end
			return
		end

		-- Do cursed stencil stuff
		render.ClearStencil()
		render.SetStencilEnable(true)
		render.SetStencilWriteMask(1)
		render.SetStencilTestMask(1)
		render.SetStencilReferenceValue(1)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilPassOperation(STENCIL_REPLACE)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetMaterial(drawMat)

		-- Draw inside of portal
		cam.PushModelMatrix(self.RENDER_MATRIX)
			SeamlessPortals.GetRenderMesh(self:GetSidesInternal())[2]:Draw()
		cam.PopModelMatrix()

		-- Draw the actual portal texture
		local portalmat = SeamlessPortals.PortalMaterials
		render.SetMaterial(portalmat[self.PORTAL_RT_NUMBER or 1])
		render.SetStencilCompareFunction(STENCIL_EQUAL)

		-- Draw quad reversed if the portal is linked to itself
		local flip = self.GetExitPortal and self:GetExitPortal() == self
		if SeamlessPortals.ToggleMirror() then flip = !flip end
		if flip then
			render.DrawScreenQuadEx(ScrW(), 0, -ScrW(), ScrH())
		else
			render.DrawScreenQuadEx(0, 0, ScrW(), ScrH())
		end

		render.SetStencilEnable(false)
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
	self:PhysicsInit(6)
	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		local finalMesh = {}
		local angMul = (360 / sides)
		local sizev = self:GetSize() * size_mult
		local sides = self:GetSidesInternal()
		local angPick = (sides % 4 != 0 and 0 or 45)
		local degOffset =  math.rad(sides * 90 + angPick)
		for side = 1, sides do
			local sidea = math.rad(side * angMul) + degOffset
			local sidex, sidey = math.sin(sidea), math.cos(sidea)
			local side1 = Vector(sidex, sidey, -1)
			local side2 = Vector(sidex, sidey,  0)
			side1:Mul(sizev); side2:Mul(sizev)
			table.insert(finalMesh, side1)
			table.insert(finalMesh, side2)
		end
		self:PhysicsInitConvex(finalMesh)
		self:EnableCustomCollisions(true)
		phys:EnableMotion(false)
		phys:SetMaterial("glass")
		phys:SetMass(250)
	else
		self:PhysicsDestroy()
		self:EnableCustomCollisions(false)
		print("Failure to create a portal physics mesh " .. self:EntIndex())
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

SeamlessPortals.PortalIndex = 0 -- The number of portals in the map
SeamlessPortals.MaxRTs = 6      -- Max amount of portals being rendered at a time
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

SeamlessPortals.UpdateTraceline = function()
	if SeamlessPortals.PortalIndex > 0 then
		util.TraceLine = SeamlessPortals.NewTraceLine -- Trace line that can go through portals
	else
		util.TraceLine = SeamlessPortals.TraceLine    -- Original trace line
	end
end

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

	-- This code creates the render targets to be used for the portals
	SeamlessPortals.PortalRTs = {}
	SeamlessPortals.PortalMaterials = {}

	for i = 1, SeamlessPortals.MaxRTs do
		SeamlessPortals.PortalRTs[i] = GetRenderTarget("SeamlessPortal" .. i, ScrW(), ScrH())
		SeamlessPortals.PortalMaterials[i] = CreateMaterial("SeamlessPortalsMaterial" .. i, "GMODScreenspace", {
			["$basetexture"] = SeamlessPortals.PortalRTs[i]:GetName(),
			["$model"] = "1"
		})
	end

	-- Create meshes used for the portals
	-- They can have a dynamic amount of sides
	SeamlessPortals.PortalMeshes = {}
	SeamlessPortals.GetRenderMesh = function(sides)
		if !SeamlessPortals.PortalMeshes[sides] then
			SeamlessPortals.PortalMeshes[sides] = {Mesh(), Mesh()}

			local meshTable, invMeshTable = {}, {}
			local angMul = (360 / sides)
			local angPick = (sides % 4 != 0 and 0 or 45)
			local degOffset = math.rad(sides * 90 + angPick)
			for side = 1, sides do
				local side1 = Vector(0, 0, -1)
				local sidex = math.rad(side * angMul) + degOffset
				local sidey = math.rad((side + 1) * angMul) + degOffset
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

				table.insert(invMeshTable, {pos = side2, u = 0, v = 0})
				table.insert(invMeshTable, {pos = side3, u = 1, v = 0})
				table.insert(invMeshTable, {pos = side1, u = 0, v = 1})

				table.insert(invMeshTable, {pos = side2, u = streach1, v = 0})
				table.insert(invMeshTable, {pos = Vector(side2[1], side2[2], 0), u = streach1, v = 1})
				table.insert(invMeshTable, {pos = side3, u = streach2, v = 0})

				table.insert(invMeshTable, {pos = side3, u = streach2, v = 0})
				table.insert(invMeshTable, {pos = Vector(side2[1], side2[2], 0), u = streach1, v = 1})
				table.insert(invMeshTable, {pos = Vector(side3[1], side3[2], 0), u = streach2, v = 1})

			end
			SeamlessPortals.PortalMeshes[sides][1]:BuildFromTriangles(meshTable)
			SeamlessPortals.PortalMeshes[sides][2]:BuildFromTriangles(invMeshTable)
		end

		return SeamlessPortals.PortalMeshes[sides]
	end

	function ENT:Think()
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:EnableMotion(false)
			phys:SetMaterial("glass")
			phys:SetPos(self:GetPos())
			phys:SetAngles(self:GetAngles())
		elseif self:GetVelocity() == Vector() then
			self:UpdatePhysmesh()
		end
	end

	hook.Add("NetworkEntityCreated", "seamless_portal_init", function(ent)
		if ent:GetClass() == "seamless_portal" then
			ent.RENDER_MATRIX = Matrix()
			timer.Simple(0, function()
				incrementPortal(ent)
			end)
		end
	end)

	--Funny flipped scene
	local rendering = false
	local mirrored = false
	function SeamlessPortals.ToggleMirror(enable)
		if enable == nil then return mirrored end -- 2024 Mee here: what the fuck is this
		mirrored = enable

		if (!enable) then
			hook.Remove("PreDrawViewModels", "FlippedWorld")
			hook.Remove("InputMouseApply", "FlippedWorld")
			hook.Remove("CreateMove", "FlippedWorld")

			return mirrored
		end

		hook.Add("PreDrawViewModels", "FlippedWorld", function()
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
