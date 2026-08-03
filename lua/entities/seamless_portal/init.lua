-- sv_init.lua
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("sh_init.lua")

include("sh_init.lua")

local function setDupeLink(ply, ent, dat)
	if CLIENT then return true end
	if not IsValid(ply) then return end
	ent.PORTAL_DUPE_LINK = ent.PORTAL_DUPE_LINK or {}
	ent.PORTAL_DUPE_LINK = table.Merge(ent.PORTAL_DUPE_LINK, dat, true)
	duplicator.StoreEntityModifier(ent, "seamless_portal_dupelink", ent.PORTAL_DUPE_LINK)
end

duplicator.RegisterEntityModifier("seamless_portal_dupelink", setDupeLink)

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


local outputs = {
	["OnTeleportFrom"] = true,
	["OnTeleportTo"]   = true
}

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
	elseif key == "sides" then
		self:SetSides(tonumber(value) or 4)
	elseif outputs[key] then
		self:StoreOutput(key, value)
	end
end

function ENT:AcceptInput(input, activator, caller, data)
	if input == "Link" then
		self:SetExitPortal(ents.FindByName(data)[1])
	end
end

function ENT:Initialize()
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

	table.insert(SeamlessPortals.Portals, self)
end

function ENT:OnRemove()
	if self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:GetExitPortal())
	end

	table.RemoveByValue(SeamlessPortals.Portals, self)
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

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end
