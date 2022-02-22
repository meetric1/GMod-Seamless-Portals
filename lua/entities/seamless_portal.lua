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

function ENT:Initialize()
	if CLIENT then return end
	self:SetModel("models/hunter/plates/plate2x2.mdl")
	self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysWake()
	self:SetMaterial("debug/debugempty")
	self:SetRenderMode(RENDERMODE_TRANSCOLOR)
	self:GetPhysicsObject():EnableMotion(false)
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	self:DrawShadow(false)
	print("Portal " .. tostring(self) .." was initialized")
end

function ENT:SpawnFunction()
	return nil
end

function ENT:OnRemove()
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex - 1
end

-- initialize doesn't run when an incoming client joins, so im just use think hook and make it run once
function ENT:Think()
	if !self.PORTAL_INITIALIZED then
		if CLIENT then
			self.PORTAL_RT = GetRenderTarget("SeamlessPortal" .. SeamlessPortals.PortalIndex, ScrW(), ScrH())
			self.PORTAL_MATERIAL = CreateMaterial("SeamlessPortalsMaterial" .. SeamlessPortals.PortalIndex, "GMODScreenspace", {
				["$basetexture"] = self.PORTAL_RT:GetName(), 
				["$model"] = "1"
			})
		end
		SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
		self.PORTAL_INITIALIZED = true
	end
end

function ENT:Draw()
	
end

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

