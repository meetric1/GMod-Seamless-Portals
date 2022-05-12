if (E2Lib==nil) then return end

--[[
Some notes:
	Requesting information from a portal and/or its pair does not require authorization as we aren't modifying anything.
]]

E2Lib.RegisterExtension("SeamlessPortalsCore", true)

local function IsPortal(ent)
	if (ent:IsValid() and ent:GetClass() == "seamless_portal") then
		return true
	end
	return false
end

local function CanManipPortal(ent, ply)
	if !IsPortal(ent) then return false end
	--if !ply:IsAdmin() then return true end -- I leave it to your discretion if you think this should be included.
	if CPPI then
		if ent:CPPIGetOwner() == ply then return true end
		if E2Lib.isFriend(ent:CPPIGetOwner(), ply) then return true end
	else
		return true
	end
	return false
end

local function CreatePortal(Pos, Ang, Owner, Clear)
	Clear = Clear or false
	local ent = ents.Create("seamless_portal")
	ent:Spawn()
	ent:SetPos(Pos)
	ent:SetAngles(Ang + Angle(90, 0, 0))
	ent.PORTAL_REMOVE_EXIT = Clear
	if CPPI and IsValid(Owner) then
		ent:CPPISetOwner(Owner)
	end
	return ent
end

local function GetPortalExit(ent)
	if !IsPortal(ent) then return nil end
	return ent:GetExitPortal() or nil
end

local function SetPortalSize(ent, x, y)
	if !IsPortal(ent) then return 0 end

	local SizeX = math.Clamp(x, 0.01, 10)
	local SizeY = math.Clamp(y, 0.01, 10)
	local FinalVec = Vector(SizeY, SizeX, 1)
	ent:SetExitSize(FinalVec)
	return 1
end


__e2setcost( 35 )

e2function array createPortalPair(vector pos1, angle ang1, vector pos2, angle ang2)
	local portal1 = CreatePortal(Vector(pos1[1],pos1[2],pos1[3]), Angle(ang1[1], ang1[2], ang1[3]), self.player, true)
	local portal2 = CreatePortal(Vector(pos2[1],pos2[2],pos2[3]), Angle(ang2[1], ang2[2], ang2[3]), self.player, true)
	portal1:LinkPortal(portal2)

	return {portal1, portal2}
end

e2function entity createPortal(vector pos, angle ang)
	return CreatePortal(Vector(pos[1],pos[2],pos[3]), Angle(ang[1], ang[2], ang[3]), self.player)
end

__e2setcost( 10 )

e2function entity entity:getPortalExit()
	return GetPortalExit(this)
end

e2function vector entity:getPortalSize()
	if !IsPortal(this) then return nil end
	return this:GetPortalSize()
end

e2function vector entity:getPortalExitSize()
	if !IsPortal(this) then return nil end
	return GetPortalExit(this):GetPortalSize() or nil
end

__e2setcost( 25 )

e2function number entity:linkPortal(entity targetPortal)
	if CanManipPortal(this, self.player) and CanManipPortal(targetPortal, self.player) then
		this:LinkPortal(targetPortal)
		return 1
	end
	return 0
end

e2function number entity:setPortalSize(vector2 size)
	if !CanManipPortal(this, self.player) then return 0 end
	return SetPortalSize(this, size[1], size[2])
end

e2function number entity:setPortalSize(number x, number y)
	if !CanManipPortal(this, self.player) then return 0 end
	return SetPortalSize(this, x, y)
end

e2function number entity:setPortalExitSize(vector2 size)
	local Exit = GetPortalExit(this) or nil
	if !Exit then return 0 end
	if !CanManipPortal(Exit, self.player) then return 0 end
	return SetPortalSize(Exit, size[1], size[2])
end

e2function number entity:setPortalExitSize(number x, number y)
	local Exit = GetPortalExit(this) or nil
	if !Exit then return 0 end
	if !CanManipPortal(Exit, self.player) then return 0 end
	return SetPortalSize(Exit, x, y)
end

e2function number entity:setPortalSize(number squaredsize)
	if !CanManipPortal(this, self.player) then return 0 end
	return SetPortalSize(this, squaredsize, squaredsize)
end

e2function number entity:setPortalExitSize(number squaredsize)
	local Exit = GetPortalExit(this) or nil
	if !Exit then return 0 end
	if !CanManipPortal(Exit, self.player) then return 0 end
	return SetPortalSize(Exit, squaredsize, squaredsize)
end

e2function number entity:setPortalSides(number sides)
	if !CanManipPortal(this, self.player) then return 0 end
	this:SetSides(sides) -- Function already internally clamps the value, no need to do it on our end.
	return 1
end

e2function number entity:setPortalExitSides(number sides)
	if !CanManipPortal(this, self.player) then return 0 end
	local Exit = GetPortalExit(this) or nil
	if !Exit then return 0 end
	if !CanManipPortal(Exit, self.player) then return 0 end
	Exit:SetSides(sides)
	return 1
end

e2function number entity:removePortal()
	if !CanManipPortal(this, self.player) then return 0 end
	SafeRemoveEntity(this)
	return 1
end