-- sv_init.lua
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("sh_init.lua")

include("sh_init.lua")

-- dupe/save support
local function set_dupe_link(_, ent, data)
	if CLIENT then return end

	ent.SEAMLESS_PORTALS_DUPE_LINK = table.Merge(ent.SEAMLESS_PORTALS_DUPE_LINK or {}, data, true)
	duplicator.StoreEntityModifier(ent, "seamless_portals_dupe_link", ent.SEAMLESS_PORTALS_DUPE_LINK)
end

duplicator.RegisterEntityModifier("seamless_portals_dupe_link", set_dupe_link)

function ENT:PostEntityPaste(_, _, created_entites)
	local dupelink = self.SEAMLESS_PORTALS_DUPE_LINK
	if !dupelink then return end

	local portal_exit = created_entites[dupelink.exit_id]

	if IsValid(portal_exit) then
		self:LinkPortal(portal_exit)
	end

	if dupelink.exit_remove then
		self:SetRemoveExit(true)
	end
end

function ENT:LinkPortal(exit_portal)
	if !IsValid(exit_portal) then return end -- not sure I like this, ideally should throw an error

	self:SetExitPortal(exit_portal)
	set_dupe_link(self:GetCreator(), self, {exit_id = exit_portal:EntIndex()})

	exit_portal:SetExitPortal(self)
	set_dupe_link(exit_portal:GetCreator(), exit_portal, {exit_id = self:EntIndex()})
end

function ENT:UnlinkPortal()
	local exit_portal = self:GetExitPortal()
	self:SetExitPortal(nil)
	set_dupe_link(self:GetCreator(), self, {exit_id = -1})

	if !IsValid(exit_portal) then return end

	exit_portal:SetExitPortal(nil)
	set_dupe_link(exit_portal:GetCreator(), exit_portal, {exit_id = -1})
end

function ENT:SetRemoveExit(bool)
	bool = bool and true or false

	self.SEAMLESS_PORTALS_REMOVE_EXIT = bool
	set_dupe_link(self:GetCreator(), self, {exit_remove = bool})
end

function ENT:GetRemoveExit(bool)
	return self.SEAMLESS_PORTALS_REMOVE_EXIT
end

local outputs = {
	["OnTeleportFrom"] = true,
	["OnTeleportTo"]   = true
}

function ENT:KeyValue(key, value)
	self.SEAMLESS_PORTALS_MAP_FORMAT = self.SEAMLESS_PORTALS_MAP_FORMAT or 0

	if key == "link" then
		timer.Simple(0, function() self:SetExitPortal(ents.FindByName(value)[1]) end)
	elseif key == "backface" then
		self:SetDisableBackface(value == "1")
	elseif key == "size" then
		local size = string.Split(value, " ")
		self:SetSize(Vector(size[2], size[1], size[3]))
	elseif key == "sides" then
		self:SetSides(tonumber(value) or 4)
	elseif key == "version" then
		self.SEAMLESS_PORTALS_MAP_FORMAT = tonumber(value) or 0
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
	self:SetCollisionGroup(COLLISION_GROUP_WORLD) -- no collide
	self:DrawShadow(false)

	-- defaults and portal format conversion. welcome to tech debt hell
	local map_format = self.SEAMLESS_PORTALS_MAP_FORMAT
	if map_format then
		if map_format == 0 then
			self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		end
	end

	local sides = self:GetSides()
	if sides <= 0 then
		self:SetSides(4)
	end

	local size_internal = self:GetSizeInternal()
	if !size_internal:IsZero() then
		size_internal:Mul(Vector(2, 2, 1))
		self:SetSize(size_internal)
	end

	local size = self:GetSize()
	if size:IsZero() then
		self:SetSize(Vector(100, 100, 8))
	end

	-- clamp to prevent exploiting, no fun allowed :)
	size = self:GetSize()
	for i = 1, 3 do
		size[i] = math.Clamp(size[i], 1, 1000)
	end
	self:SetSize(size)

	sides = self:GetSides()
	sides = math.Clamp(sides, 1, 100)
	self:SetSides(sides)

	self.SEAMLESS_PORTALS_INITIALIZED = true
	self:UpdatePhysmesh()

	table.insert(SeamlessPortals.Portals, self)
end

function ENT:OnRemove()
	if self:GetRemoveExit() then
		SafeRemoveEntity(self:GetExitPortal())
	end

	table.RemoveByValue(SeamlessPortals.Portals, self)
end

function ENT:SpawnFunction(ply, tr)
	local portal1 = ents.Create("seamless_portal")
	if not IsValid(portal1) then return end

	portal1:SetPos(tr.HitPos + tr.HitNormal * 160)
	portal1:SetAngles(tr.HitNormal:AngleEx(Vector(0, 0, -1)))
	portal1:SetCreator(ply)
	portal1:Spawn()

	local portal2 = ents.Create("seamless_portal")
	if not IsValid(portal2) then return end

	portal2:SetPos(tr.HitPos + tr.HitNormal * 50)
	portal2:SetAngles(tr.HitNormal:AngleEx(Vector(0, 0, -1)))
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
