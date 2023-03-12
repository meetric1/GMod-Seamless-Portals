-- Seamless portals addon by Mee
-- You may use this code as a reference for your own projects, but please do not publish this addon as your own.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category     = "Seamless Portals"
ENT.PrintName    = "Seamless Portal"
ENT.Author       = "Mee"
ENT.Purpose      = ""
ENT.Instructions = ""
ENT.Spawnable    = true


local gbSvFlag = bit.bor(FCVAR_ARCHIVE)
-- create global table
SeamlessPortals = SeamlessPortals or {}
local varDrawDistance = CreateClientConVar("seamless_portal_drawdistance", "250", true, false, "Sets the multiplier of how far a portal should render", 0)

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
end

function ENT:UnlinkPortal()
	local exitPortal = self:GetExitPortal()
	if IsValid(exitPortal) then 
		exitPortal:SetExitPortal(nil)
	end
	self:SetExitPortal(nil)
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
end

function ENT:GetRemoveExit(bool)
	return self.PORTAL_REMOVE_EXIT
end

function ENT:GetSize()
	return self:GetSizeInternal()
end

local function incrementPortal(ent)
	if CLIENT then	-- singleplayer is weird... dont generate a physmesh if its singleplayer
		ent.RENDER_MATRIX = Matrix()
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
		ent:SetRenderBounds(-ent:GetSize(), ent:GetSize())
	end
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
end

function ENT:Initialize()
	if CLIENT then
		incrementPortal(self)
	else
		self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
		self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)
		self:SetRemoveExit(false)

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
	portal1:SetPos(tr.HitPos + tr.HitNormal * 160)
	portal1:Spawn()

	local portal2 = ents.Create("seamless_portal")
	portal2:SetPos(tr.HitPos + tr.HitNormal * 50)
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

-- theres gonna be a bunch of magic numbers in this rendering code, since garry decided a hunterplate should be 47.9 rendering units wide and 51 physical units
local size_mult = Vector(math.sqrt(2), math.sqrt(2), 1)	// so the size is in source units (remember we are using sine/cosine)
if CLIENT then
	local drawMat = Material("models/dav0r/hoverball")
	function ENT:GetRenderMesh()
		return {Mesh = SeamlessPortals.GetRenderMesh(self:GetSidesInternal())[1], Material = drawMat, Matrix = self.RENDER_MATRIX_LOCAL}
	end

	function ENT:Draw()
		if halo.RenderedEntity() == self then return end
		local render = render
		local cam = cam
	
		-- render the outside frame
		local portalSize = self:GetSize() * size_mult
		local backface = self:GetDisableBackface()
		if self.RENDER_MATRIX:GetTranslation() != self:GetPos() or self.RENDER_MATRIX:GetScale() != portalSize then
			self.RENDER_MATRIX = Matrix()
			self.RENDER_MATRIX:SetTranslation(self:GetPos())
			self.RENDER_MATRIX:SetAngles(self:GetAngles())
			self.RENDER_MATRIX:SetScale(portalSize * 0.999)
			
			self.RENDER_MATRIX_LOCAL = Matrix()
			self.RENDER_MATRIX_LOCAL:SetScale(portalSize)

			portalSize[3] = 0
			self.RENDER_MATRIX_FLAT = Matrix(self.RENDER_MATRIX:ToTable())
			self.RENDER_MATRIX_FLAT:SetScale(portalSize)	
			
			self:SetRenderBounds(-self:GetSize(), self:GetSize())
		end

		if !backface then
			self:DrawModel()
		end
	
		-- draw inside of portal
		if SeamlessPortals.Rendering or !IsValid(self:GetExitPortal()) or !SeamlessPortals.ShouldRender(self, EyePos(), EyeAngles()) then
			if !backface then 
				cam.PushModelMatrix(self.RENDER_MATRIX_FLAT)
					SeamlessPortals.GetRenderMesh(self:GetSidesInternal())[2]:Draw()
				cam.PopModelMatrix()
			end
			return 
		end

		-- do cursed stencil stuff
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

		-- draw inside of portal
		cam.PushModelMatrix(self.RENDER_MATRIX)
			SeamlessPortals.GetRenderMesh(self:GetSidesInternal())[2]:Draw()
		cam.PopModelMatrix()

		-- draw the actual portal texture
		local portalmat = SeamlessPortals.PortalMaterials
		render.SetMaterial(portalmat[self.PORTAL_RT_NUMBER or 1])
		render.SetStencilCompareFunction(STENCIL_EQUAL)

		-- draw quad reversed if the portal is linked to itself
		if self.GetExitPortal and self:GetExitPortal() == self then
			render.DrawScreenQuadEx(ScrW(), 0, -ScrW(), ScrH())
		else
			render.DrawScreenQuadEx(0, 0, ScrW(), ScrH())
		end

		render.SetStencilEnable(false)
	end

	-- hacky bullet fix
	if game.SinglePlayer() then
		function ENT:TestCollision(startpos, delta, isbox, extents, mask)
			if bit.band(mask, CONTENTS_GRATE) != 0 then return true end
		end
	end
end

-- scale the physmesh
function ENT:UpdatePhysmesh()
	self:PhysicsInit(6)
	if self:GetPhysicsObject():IsValid() then
		local finalMesh = {}
		local sides = self:GetSidesInternal()
		local angleMul = 360 / sides
		local degreeOffset = (sides * 90 + (sides % 4 != 0 and 0 or 45)) * (math.pi / 180)
		for side = 1, sides do
			local side1 = Vector(math.sin(math.rad(side * angleMul) + degreeOffset), math.cos(math.rad(side * angleMul) + degreeOffset), -1)
			local side2 = Vector(math.sin(math.rad(side * angleMul) + degreeOffset), math.cos(math.rad(side * angleMul) + degreeOffset), 0)
			table.insert(finalMesh, side1 * self:GetSize() * size_mult)
			table.insert(finalMesh, side2 * self:GetSize() * size_mult)
		end
		self:PhysicsInitConvex(finalMesh)
		self:EnableCustomCollisions(true)
		self:GetPhysicsObject():EnableMotion(false)
		self:GetPhysicsObject():SetMaterial("glass")
		self:GetPhysicsObject():SetMass(250)
	else
		self:PhysicsDestroy()
		self:EnableCustomCollisions(false)
		print("Failure to create a portal physics mesh " .. self:EntIndex())
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

SeamlessPortals.PortalIndex = 0		-- the number of portals in the map
SeamlessPortals.MaxRTs = 6			-- max amount of portals being rendered at a time
SeamlessPortals.TransformPortal = function(a, b, pos, ang)
	if !IsValid(a) or !IsValid(b) then return Vector(), Angle() end
	local editedPos = Vector()
	local editedAng = Angle()

	if pos then
		editedPos = a:WorldToLocal(pos) * (b:GetSize()[1] / a:GetSize()[1])
		editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
		editedPos = editedPos + b:GetUp() * 0.01	// so you dont become trapped
	end

	if ang then
		local localAng = a:WorldToLocalAngles(ang)
		editedAng = b:LocalToWorldAngles(Angle(-localAng[1], -localAng[2], localAng[3] + 180))
	end

	-- mirror portal
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
		util.TraceLine = SeamlessPortals.NewTraceLine	-- traceline that can go through portals
	else
		util.TraceLine = SeamlessPortals.TraceLine	-- original traceline
	end
end

-- set physmesh pos on client
if CLIENT then
	-- only render the portals that are in the frustum, or should be rendered
	SeamlessPortals.ShouldRender = function(portal, eyePos, eyeAngle)
		if portal:IsDormant() then return false end
		local portalPos, portalUp, exitSize = portal:GetPos(), portal:GetUp(), portal:GetSize()
		local max = math.max(exitSize[1], exitSize[2])
		-- (eyePos - portalPos):Dot(portalUp) > (-10 * max) -- true if behind the portal, false otherwise
		-- eyePos:DistToSqr(portalPos) < SeamlessPortals.VarDrawDistance:GetFloat()^2 * max -- true if close enough
		-- (eyePos - portalPos):Dot(eyeAngle:Forward()) < 50 * max -- true if looking at the portal, false otherwise
		-- why return on 1 line? well.. its faster
		return ((eyePos - portalPos):Dot(portalUp) > -max and 
		eyePos:DistToSqr(portalPos) < varDrawDistance:GetFloat()^2 * max and 
		(eyePos - portalPos):Dot(eyeAngle:Forward()) < max)
	end

	-- this code creates the rendertargets to be used for the portals
	SeamlessPortals.PortalRTs = {}
	SeamlessPortals.PortalMaterials = {}

	for i = 1, SeamlessPortals.MaxRTs do
		SeamlessPortals.PortalRTs[i] = GetRenderTarget("SeamlessPortal" .. i, ScrW(), ScrH())
		SeamlessPortals.PortalMaterials[i] = CreateMaterial("SeamlessPortalsMaterial" .. i, "GMODScreenspace", {
			["$basetexture"] = SeamlessPortals.PortalRTs[i]:GetName(),
			["$model"] = "1"
		})
	end

	-- create meshes used for the portals
	-- they can have a dynamic amount of sides
	SeamlessPortals.PortalMeshes = {}
	SeamlessPortals.GetRenderMesh = function(sides)
		if !SeamlessPortals.PortalMeshes[sides] then
			SeamlessPortals.PortalMeshes[sides] = {Mesh(), Mesh()}

			local meshTable = {}
			local invMeshTable = {}
			local angleMul = 360 / sides
			local degreeOffset = (sides * 90 + (sides % 4 != 0 and 0 or 45)) * (math.pi / 180)
			for side = 1, sides do
				local side1 = Vector(0, 0, -1)
				local side2 = Vector(math.sin(math.rad(side * angleMul) + degreeOffset), math.cos(math.rad(side * angleMul) + degreeOffset), -1)
				local side3 = Vector(math.sin(math.rad((side + 1) * angleMul) + degreeOffset), math.cos(math.rad((side + 1) * angleMul) + degreeOffset), -1)

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

	hook.Add("InitPostEntity", "seamless_portal_init", function()
		timer.Simple(0, function()
			for k, v in ipairs(ents.FindByClass("seamless_portal")) do
				print("Initializing portal " .. v:EntIndex())
				incrementPortal(v)
			end
		end)
	end)

	--funny flipped scene
	local rendering = false
	local mirrored = false
	function SeamlessPortals.ToggleMirror(enable)
		if enable then
			hook.Add("PreRender", "portal_flip_scene", function()
				rendering = true
				render.PushRenderTarget(SeamlessPortals.PortalRTs[SeamlessPortals.MaxRTs])
				render.RenderView({drawviewmodel = false})
				render.PopRenderTarget()
				rendering = false
			end)

			hook.Add("PostDrawTranslucentRenderables", "portal_flip_scene", function(_, sky, sky3d)
				if rendering or SeamlessPortals.Rendering then return end
				render.SetMaterial(SeamlessPortals.PortalMaterials[SeamlessPortals.MaxRTs])
				render.DrawScreenQuadEx(ScrW(), 0, -ScrW(), ScrH())

				if LocalPlayer():Health() <= 0 then
					SeamlessPortals.ToggleMirror(false)
				end
			end)

			-- invert mouse x
			hook.Add("InputMouseApply", "portal_flip_scene", function(cmd, x, y, ang)
				if LocalPlayer():WaterLevel() < 3 then
					cmd:SetViewAngles(ang + Angle(0, x / 22.5, 0))
				end
			end)

			-- invert movement x
			hook.Add("CreateMove", "portal_flip_scene", function(cmd)
				if LocalPlayer():WaterLevel() < 3 then
					cmd:SetSideMove(-cmd:GetSideMove())
				end
			end)

			mirrored = true
		elseif enable == false then
			hook.Remove("PreRender", "portal_flip_scene")
			hook.Remove("PostDrawTranslucentRenderables", "portal_flip_scene")
			hook.Remove("InputMouseApply", "portal_flip_scene")
			hook.Remove("CreateMove", "portal_flip_scene")

			mirrored = false
		end

		return mirrored
	end

	SeamlessPortals.ToggleMirror(false)
end
