if (E2Lib==nil) then return end

--[[
Some notes:
	Only functions such as linkPortal() checks for CPPI ownership on portal pairs as we assume that once paired, ownership is assumed.

	Requesting information from a portal and/or its pair does not require authorization as we aren't modifying anything.
]]

E2Lib.RegisterExtension("SeamlessPortalsCore", true)

__e2setcost( 35 )

e2function array createPortalPair(vector pos1, angle ang1, vector pos2, angle ang2)
	local portal1 = ents.Create("seamless_portal")
	local portal2 = ents.Create("seamless_portal")

	portal1:Spawn()
	portal1:SetPos(Vector(pos1[1],pos1[2],pos1[3]))
	portal1:SetAngles(Angle(ang1[1], ang1[2], ang1[3]) + Angle(90, 0, 0))
	portal1.PORTAL_REMOVE_EXIT = true

	portal2:Spawn()
	portal2:SetPos(Vector(pos2[1],pos2[2],pos2[3]))
	portal2:SetAngles(Angle(ang2[1], ang2[2], ang2[3]) + Angle(90, 0, 0))
	portal2.PORTAL_REMOVE_EXIT = true

	portal1:LinkPortal(portal2)

	if CPPI then
		portal1:CPPISetOwner(self.player)
		portal2:CPPISetOwner(self.player)
	end

	return {portal1, portal2}
end

e2function entity createPortal(vector pos, angle ang)
	local portal = ents.Create("seamless_portal")

	portal:Spawn()
	portal:SetPos(Vector(pos[1],pos[2],pos[3]))
	portal:SetAngles(Angle(ang[1], ang[2], ang[3]) + Angle(90, 0, 0))

	if CPPI then
		portal:CPPISetOwner(self.player)
	end

	return portal
end

__e2setcost( 10 )

e2function entity entity:getPortalExit()
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return nil end
	if not IsValid(this:GetExitPortal()) then return nil end
	return this:GetExitPortal()
end

e2function vector entity:getPortalSize()
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return nil end
	return this:GetExitSize()
end

e2function vector entity:getPortalExitSize()
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return nil end
	if not IsValid(this:GetExitPortal()) then return nil end
	return this:GetExitPortal():GetExitSize()
end

__e2setcost( 25 )

e2function number entity:linkPortal(entity targetPortal)
	if (not IsValid(this) or not this:GetClass() == "seamless_portal") or (not IsValid(targetPortal) or not targetPortal:GetClass() == "seemless_portal") then return 0 end
	if CPPI == nil or ((this:CPPIGetOwner() == self.player or E2Lib.isFriend(this:CPPIGetOwner(), self.player)) and (targetPortal:CPPIGetOwner() == self.player or E2Lib.isFriend(targetPortal:CPPIGetOwner(), self.player))) then
		this:LinkPortal(targetPortal)
		return 1
	end
	return 0
end

e2function number entity:setPortalSize(vector2 size)
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return 0 end 
	if CPPI == nil or (this:CPPIGetOwner() == self.player or E2Lib.isFriend(this:CPPIGetOwner(), self.player)) then
		this:SetExitSize(Vector(math.Clamp(size[2],0.01,10), math.Clamp(size[1],0.01,10), 1))
		return 1
	end
	return 0
end

e2function number entity:setPortalSize(number x, number y)
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return 0 end 
	if CPPI == nil or (this:CPPIGetOwner() == self.player or E2Lib.isFriend(this:CPPIGetOwner(), self.player)) then
		this:SetExitSize(Vector(math.Clamp(y,0.01,10), math.Clamp(x,0.01,10), 1))
		return 1
	end
	return 0
end

e2function number entity:setPortalExitSize(vector2 size)
	if (not (IsValid(this) or not this:GetClass() == "seamless_portal") and IsValid(this:GetExitPortal())) then return 0 end
	if CPPI == nil or (this:GetExitPortal():CPPIGetOwner() == self.player or E2Lib.isFriend(this:GetExitPortal():CPPIGetOwner(), self.player)) then
		this:GetExitPortal():SetExitSize(Vector(math.Clamp(size[2],0.01,10), math.Clamp(size[1],0.01,10), 1))
		return 1
	end
	return 0
end

e2function number entity:setPortalExitSize(number x, number y)
	if (not (IsValid(this) or not this:GetClass() == "seamless_portal") and IsValid(this:GetExitPortal())) then return 0 end
	if CPPI == nil or (this:GetExitPortal():CPPIGetOwner() == self.player or E2Lib.isFriend(this:GetExitPortal():CPPIGetOwner(), self.player)) then
		this:GetExitPortal():SetExitSize(Vector(math.Clamp(y,0.01,10), math.Clamp(x,0.01,10), 1))
		return 1
	end
	return 0
end

e2function number entity:setPortalSides(number sides)
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return 0 end
	if CPPI == nil or (this:CPPIGetOwner() == self.player or E2Lib.isFriend(this:CPPIGetOwner(), self.player)) then
		this:SetSides(sides) -- Function already internally clamps the value, no need to do it on our end.
		return 1
	end
	return 0
end

e2function number entity:setPortalExitSides(number sides)
	if (not (IsValid(this) or not this:GetClass() == "seamless_portal") and IsValid(this:GetExitPortal())) then return 0 end
	if CPPI == nil or (this:GetExitPortal():CPPIGetOwner() == self.player or E2Lib.isFriend(this:GetExitPortal():CPPIGetOwner(), self.player)) then
		this:GetExitPortal():SetSides(sides)
		return 1
	end
	return 0
end

e2function number entity:removePortal()
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return 0 end
	if CPPI == nil or (this:CPPIGetOwner() == self.player or E2Lib.isFriend(this:CPPIGetOwner(), self.player)) then
		SafeRemoveEntity(this)
		return 1
	end
	return 0
end