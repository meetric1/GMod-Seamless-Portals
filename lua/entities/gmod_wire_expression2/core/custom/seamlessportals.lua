if (E2Lib==nil) then return end

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

	portal1.PORTAL_EXIT = portal2
	portal2.PORTAL_EXIT = portal1
	portal1:SetPortalExit(portal2)
	portal2:SetPortalExit(portal1)

	if CPPI then
		portal1:CPPISetOwner(self.player)
		portal2:CPPISetOwner(self.player)
	end

	return {portal1, portal2}
end

__e2setcost( 10 )

e2function entity entity:getPortalExit()
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return nil end
	if not IsValid(this.PORTAL_EXIT) then return nil end
	return this.PORTAL_EXIT
end

e2function vector entity:getPortalSize()
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return nil end
	return this:GetExitSize()
end

e2function vector entity:getPortalExitSize()
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return nil end
	if not IsValid(this.PORTAL_EXIT) then return nil end
	return this.PORTAL_EXIT:GetExitSize()
end

__e2setcost( 25 )

e2function number entity:setPortalSize(vector2 size)
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return 0 end 
	if CPPI == nil or (this:CPPIGetOwner() == self.player or E2Lib.isFriend(this:CPPIGetOwner(), self.player)) then
		this:SetExitSize(Vector(math.Clamp(size[2],0.01,10), math.Clamp(size[1],0.01,10), 1))
		return 1
	end
end

e2function number entity:setPortalSize(number x, number y)
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return 0 end 
	if CPPI == nil or (this:CPPIGetOwner() == self.player or E2Lib.isFriend(this:CPPIGetOwner(), self.player)) then
		this:SetExitSize(Vector(math.Clamp(y,0.01,10), math.Clamp(x,0.01,10), 1))
		return 1
	end
end

e2function number entity:setPortalExitSize(vector2 size)
	if (not (IsValid(this) or not this:GetClass() == "seamless_portal") and IsValid(this.PORTAL_EXIT)) then return 0 end
	if CPPI == nil or (this.PORTAL_EXIT:CPPIGetOwner() == self.player or E2Lib.isFriend(this.PORTAL_EXIT:CPPIGetOwner(), self.player)) then
		this.PORTAL_EXIT:SetExitSize(Vector(math.Clamp(size[2],0.01,10), math.Clamp(size[1],0.01,10), 1))
		return 1
	end
end

e2function number entity:setPortalExitSize(number x, number y)
	if (not (IsValid(this) or not this:GetClass() == "seamless_portal") and IsValid(this.PORTAL_EXIT)) then return 0 end
	if CPPI == nil or (this.PORTAL_EXIT:CPPIGetOwner() == self.player or E2Lib.isFriend(this.PORTAL_EXIT:CPPIGetOwner(), self.player)) then
		this.PORTAL_EXIT:SetExitSize(Vector(math.Clamp(y,0.01,10), math.Clamp(x,0.01,10), 1))
		return 1
	end
end

e2function number entity:removePortalPair()
	if not IsValid(this) or not this:GetClass() == "seamless_portal" then return 0 end
	if CPPI == nil or (this:CPPIGetOwner() == self.player or E2Lib.isFriend(this:CPPIGetOwner(), self.player)) then
		SafeRemoveEntity(this)
		return 1
	end
	return 0
end