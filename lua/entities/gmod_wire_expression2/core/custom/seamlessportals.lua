if (E2Lib==nil) then return end

--[[
Some notes:
	Requesting information from a portal and/or its pair does not require authorization as we aren't modifying anything.
]]

E2Lib.RegisterExtension("SeamlessPortalsCore", true)
SeamlessPortalsCore = {}
local sbox_wire_portals_max = CreateConVar("sbox_wire_portals_max", 8, {FCVAR_ARCHIVE})

local E2totalspawnedportals = 0

function SeamlessPortalsCore.IsPortal(ent)
	if (ent and ent:GetClass() == "seamless_portal") then
		return true
	end
	return false
end

function SeamlessPortalsCore.CanManipPortal(ent, ply)
	if !SeamlessPortalsCore.IsPortal(ent) then return false end
	--if ply:IsAdmin() then return true end -- I leave it to your discretion if you think this should be included.
	if CPPI then
		if ent:CPPIGetOwner() == ply then return true end
		if E2Lib.isFriend(ent:CPPIGetOwner(), ply) then return true end
	else
		return true
	end
	return false
end

function SeamlessPortalsCore.WithinPortalLimits()
	return (sbox_wire_portals_max:GetInt() <= 0 or E2totalspawnedportals < sbox_wire_portals_max:GetInt())
end

function SeamlessPortalsCore.CreatePortal(self, Pos, Ang, Clear)
	if !SeamlessPortalsCore.WithinPortalLimits() then error("Wire Portal limit ("..sbox_wire_portals_max:GetInt()..") exceeded.", 0) end
	local ent = ents.Create("seamless_portal")
	ent:Spawn()
	ent:SetPos(Pos)
	ent:SetAngles(Ang + Angle(90, 0, 0))
	ent.PORTAL_REMOVE_EXIT = Clear or false
	self.entity:DeleteOnRemove(ent)
	ent:CallOnRemove("wire_portal_remove",
		function(ent)
			E2totalspawnedportals = E2totalspawnedportals - 1
		end
	)
	if CPPI and IsValid(self.player) then
		ent:CPPISetOwner(self.player)
	end
	E2totalspawnedportals = E2totalspawnedportals + 1
	return ent
end

function SeamlessPortalsCore.GetPortalExit(ent)
	if !SeamlessPortalsCore.IsPortal(ent) then return nil end
	return ent:GetExitPortal() or nil
end

function SeamlessPortalsCore.SetPortalSize(ent, x, y)
	if !SeamlessPortalsCore.IsPortal(ent) then return 0 end

	local SizeX = math.Clamp(x, 0.01, 10)
	local SizeY = math.Clamp(y, 0.01, 10)
	local FinalVec = Vector(SizeY, SizeX, 1)
	ent:SetExitSize(FinalVec)
	return 1
end

--------------------------------------------------------------------------------

__e2setcost( 35 )

e2function array createPortalPair(vector pos1, angle ang1, vector pos2, angle ang2)
	local portal1 = SeamlessPortalsCore.CreatePortal(self, Vector(pos1[1],pos1[2],pos1[3]), Angle(ang1[1], ang1[2], ang1[3]), true)
	local portal2 = SeamlessPortalsCore.CreatePortal(self, Vector(pos2[1],pos2[2],pos2[3]), Angle(ang2[1], ang2[2], ang2[3]), true)
	if !IsValid(portal1) or !IsValid(portal2) then return {nil,nil} end
	portal1:LinkPortal(portal2)

	return {portal1, portal2}
end

e2function entity createPortal(vector pos, angle ang)
	local portal = SeamlessPortalsCore.CreatePortal(self, Vector(pos[1],pos[2],pos[3]), Angle(ang[1], ang[2], ang[3]))
	if !IsValid(portal) then return nil end
	return portal
end

__e2setcost( 10 )

e2function entity entity:getPortalExit()
	return SeamlessPortalsCore.GetPortalExit(this)
end

e2function vector entity:getPortalSize()
	if !SeamlessPortalsCore.IsPortal(this) then return nil end
	return this:GetPortalSize()
end

e2function vector entity:getPortalExitSize()
	if !SeamlessPortalsCore.IsPortal(this) then return nil end
	return SeamlessPortalsCore.GetPortalExit(this):GetPortalSize() or nil
end

__e2setcost( 25 )

e2function number entity:linkPortal(entity targetPortal)
	if SeamlessPortalsCore.CanManipPortal(this, self.player) and SeamlessPortalsCore.CanManipPortal(targetPortal, self.player) then
		this:LinkPortal(targetPortal)
		return 1
	end
	return 0
end

e2function number entity:setPortalSize(vector2 size)
	if !SeamlessPortalsCore.CanManipPortal(this, self.player) then return 0 end
	return SeamlessPortalsCore.SetPortalSize(this, size[1], size[2])
end

e2function number entity:setPortalSize(number x, number y)
	if !SeamlessPortalsCore.CanManipPortal(this, self.player) then return 0 end
	return SeamlessPortalsCore.SetPortalSize(this, x, y)
end

e2function number entity:setPortalExitSize(vector2 size)
	local Exit = SeamlessPortalsCore.GetPortalExit(this) or nil
	if !Exit then return 0 end
	if !SeamlessPortalsCore.CanManipPortal(Exit, self.player) then return 0 end
	return SeamlessPortalsCore.SetPortalSize(Exit, size[1], size[2])
end

e2function number entity:setPortalExitSize(number x, number y)
	local Exit = SeamlessPortalsCore.GetPortalExit(this) or nil
	if !Exit then return 0 end
	if !SeamlessPortalsCore.CanManipPortal(Exit, self.player) then return 0 end
	return SeamlessPortalsCore.SetPortalSize(Exit, x, y)
end

e2function number entity:setPortalSize(number squaredsize)
	if !SeamlessPortalsCore.CanManipPortal(this, self.player) then return 0 end
	return SeamlessPortalsCore.SetPortalSize(this, squaredsize, squaredsize)
end

e2function number entity:setPortalExitSize(number squaredsize)
	local Exit = SeamlessPortalsCore.GetPortalExit(this) or nil
	if !Exit then return 0 end
	if !SeamlessPortalsCore.CanManipPortal(Exit, self.player) then return 0 end
	return SeamlessPortalsCore.SetPortalSize(Exit, squaredsize, squaredsize)
end

e2function number entity:setPortalSides(number sides)
	if !SeamlessPortalsCore.CanManipPortal(this, self.player) then return 0 end
	this:SetSides(sides) -- Function already internally clamps the value, no need to do it on our end.
	return 1
end

e2function number entity:setPortalExitSides(number sides)
	if !SeamlessPortalsCore.CanManipPortal(this, self.player) then return 0 end
	local Exit = SeamlessPortalsCore.GetPortalExit(this) or nil
	if !Exit then return 0 end
	if !SeamlessPortalsCore.CanManipPortal(Exit, self.player) then return 0 end
	Exit:SetSides(sides)
	return 1
end

e2function number entity:removePortal()
	if !SeamlessPortalsCore.CanManipPortal(this, self.player) then return 0 end
	SafeRemoveEntity(this)
	return 1
end