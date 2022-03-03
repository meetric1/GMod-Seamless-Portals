-- Seamless portals addon by Mee
-- You may use this code as a reference for your own projects, but please do not publish this addon as your own.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "Seamless Portals"
ENT.PrintName		= "Seamless Portal"
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "PortalExit")
	self:NetworkVar("Float", 0, "PortalScale")
end

-- get exit portal
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

-- custom size for portal
function ENT:SetExitSize(n)
	self.PORTAL_SCALE = n
	self:SetPortalScale(n)
	self:Activate()
end

function ENT:GetExitSize()
	if CLIENT then 
		return self:GetPortalScale()
	end
	return self.PORTAL_SCALE
end

local COLOR_BLACK = Color(0, 0, 0, 255)
local function incrementPortal(ent)
	if CLIENT then
		ent.PORTAL_RT = GetRenderTarget("SeamlessPortal" .. SeamlessPortals.PortalIndex, ScrW(), ScrH())
		ent.PORTAL_MATERIAL = CreateMaterial("SeamlessPortalsMaterial" .. SeamlessPortals.PortalIndex, "GMODScreenspace", {
			["$basetexture"] = ent.PORTAL_RT:GetName(), 
			["$model"] = "1"
		})

		render.ClearRenderTarget(ent.PORTAL_RT, COLOR_BLACK)

		local bounding1, bounding2 = ent:GetRenderBounds()
		ent:SetRenderBounds(bounding1 * 3, bounding2 * 3)		-- for some reason this fixes a black flash when going backwards through a portal
	end
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
end

function ENT:Initialize()
	if CLIENT then
		incrementPortal(self)
	else
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetMaterial("debug/debugempty")	-- missing texture
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:GetPhysicsObject():EnableMotion(false)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)
		self:SetExitSize(1)
		print("Portal " .. tostring(self) .." was initialized")
		SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
	end
end

hook.Add("InitPostEntity", "seamless_portal_init", function()
	for k, v in ipairs(ents.FindByClass("seamless_portal")) do
		incrementPortal(v)
	end
end)

function ENT:SpawnFunction(ply, tr)
	local portal1 = ents.Create("seamless_portal")
	portal1:SetPos(tr.HitPos + tr.HitNormal * 150)
	portal1:Spawn()

	local portal2 = ents.Create("seamless_portal")
	portal2:SetPos(tr.HitPos + tr.HitNormal * 50)
	portal2:Spawn()

	portal1:LinkPortal(portal2)
	
	return portal1
end

function ENT:OnRemove()
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex - 1
	if SERVER then
		SafeRemoveEntity(self:ExitPortal())
	end
end

local function DrawQuadEasier(e, multiplier, offset, rotate)
	local right = e:GetRight() * multiplier.x
	local forward = e:GetForward() * multiplier.y 
	local up = e:GetUp() * multiplier.z 

	local pos = e:GetPos() + e:GetRight() * offset.x + e:GetForward() * offset.y + e:GetUp() * offset.z
	if !rotate then
		render.DrawQuad(
			pos + right - forward + up, 
			pos - right - forward + up, 
			pos - right + forward + up, 
			pos + right + forward + up
		)
	elseif rotate == 1 then
		render.DrawQuad(
			pos + right + forward - up, 
			pos - right + forward - up, 
			pos - right + forward + up, 
			pos + right + forward + up
		)
	else
		render.DrawQuad(
			pos + right - forward + up, 
			pos + right - forward - up, 
			pos + right + forward - up, 
			pos + right + forward + up
		)
	end
end

local drawMat = Material("models/props_lab/cornerunit_cloud")
function ENT:Draw()
	local backAmt = 3.3 * self:GetExitSize()
	local backAmt_2 = backAmt * 0.5
	local scalex = (self:OBBMaxs().x - self:OBBMins().x) * 0.5 - 0.1
	local scaley = (self:OBBMaxs().y - self:OBBMins().y) * 0.5 - 0.1
	local dotCheck = (EyePos() - self:GetPos()):Dot(self:GetUp()) < -50

	render.SetMaterial(drawMat)

	-- holy shit lol this if statment
	if SeamlessPortals.Rendering or !self:ExitPortal() or !self:ExitPortal():IsValid() or dotCheck or halo.RenderedEntity() == self then 
		render.DrawBox(self:GetPos(), self:LocalToWorldAngles(Angle(0, 90, 0)), Vector(-scaley, -scalex, -backAmt * 2), Vector(scaley, scalex, 0))
		return
	end

	self.PORTAL_SHOULDRENDER = 1 

	-- outer quads
	DrawQuadEasier(self, Vector(scaley, -scalex, -backAmt), Vector(0, 0, -backAmt))
	DrawQuadEasier(self, Vector(scaley, -scalex, backAmt), Vector(0, 0, -backAmt), 1)
	DrawQuadEasier(self, Vector(scaley, scalex, -backAmt), Vector(0, 0, -backAmt), 1)
	DrawQuadEasier(self, Vector(scaley, -scalex, backAmt), Vector(0, 0, -backAmt), 2)
	DrawQuadEasier(self, Vector(-scaley, -scalex, -backAmt), Vector(0, 0, -backAmt), 2) 

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

	-- draw the quad that the 2d texture will be drawn on
	-- teleporting causes flashing if the quad is drawn right next to the player, so we offset it
	DrawQuadEasier(self, Vector(scaley, scalex, -backAmt), Vector(0, 0, -backAmt))
	DrawQuadEasier(self, Vector(scaley, scalex, backAmt), Vector(0, 0, -backAmt), 1)
	DrawQuadEasier(self, Vector(scaley, -scalex, -backAmt), Vector(0, 0, -backAmt), 1)
	DrawQuadEasier(self, Vector(scaley, scalex, backAmt), Vector(0, 0, -backAmt), 2)
	DrawQuadEasier(self, Vector(-scaley, scalex, -backAmt), Vector(0, 0, -backAmt), 2)

	-- draw the actual portal texture
	render.SetMaterial(self.PORTAL_MATERIAL)
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.DrawScreenQuad()

	render.SetStencilEnable(false)
end


-- create global table
SeamlessPortals = SeamlessPortals or {} 
SeamlessPortals.drawPlayerInView = false
SeamlessPortals.PortalIndex = #ents.FindByClass("seamless_portal")	-- for hotreloading
SeamlessPortals.TransformPortal = function(a, b, pos, angle, mul)
	if !b:IsValid() or !a:IsValid() then return Vector(), Angle() end
	local editedPos = a:WorldToLocal(pos) * (b:GetExitSize() / a:GetExitSize())
	editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
	editedPos = editedPos + b:GetUp() * (mul or 1)
	
	angle:RotateAroundAxis(a:GetForward(), 180)
	local editedAng = b:LocalToWorldAngles(a:WorldToLocalAngles(angle))

	return editedPos, editedAng
end

