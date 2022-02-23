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

function ENT:ExitPortal()
	if CLIENT then 
		return self:GetNWEntity("EXIT_PORTAL")
	end
	return self.EXIT_PORTAL
end

function ENT:LinkPortal(ent)
	if !ent or !ent:IsValid() then return end
	self.EXIT_PORTAL = ent
	ent.EXIT_PORTAL = self
	self:SetNWEntity("EXIT_PORTAL", ent)
	ent:SetNWEntity("EXIT_PORTAL", self)
end

local function incrementPortal(ent)
	ent.PORTAL_RT = GetRenderTarget("SeamlessPortal" .. SeamlessPortals.PortalIndex, ScrW(), ScrH())
	ent.PORTAL_MATERIAL = CreateMaterial("SeamlessPortalsMaterial" .. SeamlessPortals.PortalIndex, "GMODScreenspace", {
		["$basetexture"] = ent.PORTAL_RT:GetName(), 
		["$model"] = "1"
	})
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
	local backAmt = 3
	local scalex = (self:OBBMaxs().x - self:OBBMins().x) * 0.5 - 0.1
	local scaley = (self:OBBMaxs().y - self:OBBMins().y) * 0.5 - 0.1

	render.SetMaterial(drawMat)

	if drawPlayerInView or !self:ExitPortal() or !self:ExitPortal():IsValid() then
		render.DrawBox(self:GetPos(), self:GetAngles(), Vector(-scaley, -scalex, -backAmt * 2), Vector(scaley, scalex, 0))
		return
	end

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
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)

	-- draw the quad that the 2d texture will be drawn on
	-- weapon rendering causes flashing if the quad is drawn right next to the player, so we offset it
	local plane = self:WorldToLocal(util.IntersectRayWithPlane(self:GetPos() - self:GetUp() * backAmt * 1.1, self:GetUp(), EyePos() - self:GetUp() * 2, -self:GetUp()) or self:GetPos())
	DrawQuadEasier(self, Vector(scaley, scalex, math.Min(plane.z, backAmt)), Vector(0, 0, -backAmt))
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
	local editedPos = a:WorldToLocal(pos)-- * (b.PORTAL_SCALE or 1)
	editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
	editedPos = editedPos + b:GetUp() * (mul or 1)
	
	angle:RotateAroundAxis(a:GetForward(), 180)
	local editedAng = b:LocalToWorldAngles(a:WorldToLocalAngles(angle))

	return editedPos, editedAng
end

