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

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "PortalExit")
	self:NetworkVar("Vector", 0, "PortalScale")
end

-- Get exit portal
function ENT:ExitPortal()
	if CLIENT then
		return self:GetPortalExit()
	end
	return self.PORTAL_EXIT
end

function ENT:LinkPortal(ent)
	if !ent or !ent:IsValid() then return end
	self.PORTAL_EXIT = ent
	ent.PORTAL_EXIT = self
	self:SetPortalExit(ent)
	ent:SetPortalExit(self)
end

-- Custom size for portal
function ENT:SetExitSize(n)
	self.PORTAL_SCALE = n
	self:SetPortalScale(n)
	self:UpdatePhysmesh(n)
end

function ENT:GetExitSize()
	if CLIENT then
		return self:GetPortalScale()
	end
	return self.PORTAL_SCALE
end

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetMaterial("debug/debugempty")	-- Missing texture
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)
		self:SetExitSize(Vector(1, 1, 1))
	end

	SeamlessPortals.IncrementPortal(self) -- Increment portal index
end

function ENT:SpawnFunction(ply, tr)
	local portal1 = SeamlessPortals.NewPortal(ply, tr.HitPos + tr.HitNormal * 150)
	local portal2 = SeamlessPortals.NewPortal(ply, tr.HitPos + tr.HitNormal * 50)

	portal1:LinkPortal(portal2)
	portal1.PORTAL_REMOVE_EXIT = true

	return portal1
end

function ENT:OnRemove()
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex - 1
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:ExitPortal())
	end
end

function ENT:Draw()
	local exsize = self:GetExitSize()[3]
	local backAmt = 3 * exsize
	local backVec = Vector(0, 0, -backAmt)
	local epos, spos, vup = EyePos(), self:GetPos(), self:GetUp()
	local scalex = (self:OBBMaxs().x - self:OBBMins().x) * 0.5 - 0.1
	local scaley = (self:OBBMaxs().y - self:OBBMins().y) * 0.5 - 0.1

	-- Optimization checks
	local exitInvalid = !self:ExitPortal() or !self:ExitPortal():IsValid()
	local shouldRenderPortal = false
	if !SeamlessPortals.Rendering and !exitInvalid then
	  local margnPortal = SeamlessPortals.VarDrawDistance:GetFloat()^2
		local behindPortal = (epos - spos):Dot(vup) < (-10 * exsize) -- True if behind the portal, false otherwise
		local distPortal = epos:DistToSqr(spos) > (margnPortal * exsize) -- Too far away (make this a convar later!)
		local lookingPortal = EyeAngles():Forward():Dot(vup) >= (0.6 * exsize) -- Looking away from the portal

		shouldRenderPortal = behindPortal or distPortal or lookingPortal
	end

	render.SetMaterial(SeamlessPortals.PortalDrawMat)

	-- Holy shit lol this if statment
	if SeamlessPortals.Rendering or exitInvalid or
		 shouldRenderPortal or halo.RenderedEntity() == self
	then
		local wang = self:LocalToWorldAngles(Angle(0, 90, 0))
		local vstr = Vector(-scaley, -scalex, -backAmt * 2)
		local vend = Vector(scaley, scalex, 0)

		render.DrawBox(spos, wang, vstr, vend)

		if !SeamlessPortals.Rendering then
			self.PORTAL_SHOULDRENDER = !shouldRenderPortal
		end
		return
	end

	-- Outer quads
	SeamlessPortals.DrawQuadEasier(self, Vector( scaley, -scalex, -backAmt), backVec)
	SeamlessPortals.DrawQuadEasier(self, Vector( scaley, -scalex,  backAmt), backVec, 1)
	SeamlessPortals.DrawQuadEasier(self, Vector( scaley,  scalex, -backAmt), backVec, 1)
	SeamlessPortals.DrawQuadEasier(self, Vector( scaley, -scalex,  backAmt), backVec, 2)
	SeamlessPortals.DrawQuadEasier(self, Vector(-scaley, -scalex, -backAmt), backVec, 2)

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

	-- Draw the quad that the 2d texture will be drawn on
	-- Teleporting causes flashing if the quad is drawn right next to the player, so we offset it
	SeamlessPortals.DrawQuadEasier(self, Vector( scaley,  scalex, -backAmt), backVec)
	SeamlessPortals.DrawQuadEasier(self, Vector( scaley,  scalex,  backAmt), backVec, 1)
	SeamlessPortals.DrawQuadEasier(self, Vector( scaley, -scalex, -backAmt), backVec, 1)
	SeamlessPortals.DrawQuadEasier(self, Vector( scaley,  scalex,  backAmt), backVec, 2)
	SeamlessPortals.DrawQuadEasier(self, Vector(-scaley,  scalex, -backAmt), backVec, 2)

	-- Draw the actual portal texture
	render.SetMaterial(SeamlessPortals.PortalMaterials[self.PORTAL_RT_NUMBER or 1])
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.DrawScreenQuad()
	render.SetStencilEnable(false)

	self.PORTAL_SHOULDRENDER = true
end

-- Scale the physmesh
function ENT:UpdatePhysmesh()
	self:PhysicsInit(SOLID_VPHYSICS)
	if self:GetPhysicsObject():IsValid() then
		local finalMesh = {}
		for k, tri in pairs(self:GetPhysicsObject():GetMeshConvexes()[1]) do
			tri.pos = tri.pos * self:GetExitSize()
			table.insert(finalMesh, tri)
		end
		self:PhysicsFromMesh(finalMesh)
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

-- Set physmesh pos on client
if CLIENT then
	function ENT:Think()
		local phys = self:GetPhysicsObject()
		if phys:IsValid() and phys:GetPos() != self:GetPos() then
			phys:EnableMotion(false)
			phys:SetMaterial("glass")
			phys:SetPos(self:GetPos())
			phys:SetAngles(self:GetAngles())
		end
	end

	hook.Add("InitPostEntity", "seamless_portal_init", function()
		for k, v in ipairs(ents.FindByClass("seamless_portal")) do
			print("Initializing portal " .. v:EntIndex())
			SeamlessPortals.IncrementPortal(v)
		end

		-- This code creates the rendertargets to be used for the portals
		SeamlessPortals.PortalRTs = {}
		SeamlessPortals.PortalMaterials = {}

		for i = 1, SeamlessPortals.MaxRTs do
			SeamlessPortals.PortalRTs[i] = GetRenderTarget("SeamlessPortal" .. i, ScrW(), ScrH())
			SeamlessPortals.PortalMaterials[i] = CreateMaterial("SeamlessPortalsMaterial" .. i, "GMODScreenspace", {
				["$basetexture"] = SeamlessPortals.PortalRTs[i]:GetName(),
				["$model"] = "1"
			})
		end
	end)
end
