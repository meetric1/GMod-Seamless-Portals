ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     = "Seamless Portals"
ENT.PrintName    = "Seamless Portal"
ENT.Author       = "Mee"
ENT.Purpose      = "Seamlessly connects two locations"
ENT.Instructions = ""
ENT.Spawnable    = true
ENT.RenderGroup  = RENDERGROUP_OPAQUE

SeamlessPortals  = SeamlessPortals or {}

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "ExitPortal")
	self:NetworkVar("Vector", 0, "SizeInternal")
	self:NetworkVar("Vector", 1, "Size")
	self:NetworkVar("Bool", 0, "DisableBackface")
	self:NetworkVar("Int", 0, "Sides")

	-- rebuild collision mesh if resized
	self:NetworkVarNotify("Size", function(self, _, old, new)
		if !self.SEAMLESS_PORTALS_INITIALIZED or old == new then return end
		self:UpdatePhysmesh(new, nil)
	end)

	self:NetworkVarNotify("Sides", function(self, _, old, new)
		if !self.SEAMLESS_PORTALS_INITIALIZED or old == new then return end
		self:UpdatePhysmesh(nil, new)
	end)
end

-- So the size is in source units (remember we are using sine/cosine)
local size_mult = Vector(math.sqrt(2) / 2, math.sqrt(2) / 2, 1)

-- Scale the phys mesh
function ENT:UpdatePhysmesh(size, sides)
	size = (size or self:GetSize()) * size_mult
	sides = sides or self:GetSides()

	local finalMesh = {}
	local angleMul = 360 / sides
	local degreeOffset = (sides * 90 + (sides % 4 != 0 and 0 or 45)) * (math.pi / 180)
	for side = 1, sides do
		local sidea = math.rad(side * angleMul) + degreeOffset
		local sidex = math.sin(sidea)
		local sidey = math.cos(sidea)
		local side1 = Vector(sidex, sidey, -1) side1:Mul(size)
		local side2 = Vector(sidex, sidey,  0) side2:Mul(size)
		table.insert(finalMesh, side1)
		table.insert(finalMesh, side2)
	end
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	if !self:PhysicsInitConvex(finalMesh) then
		print("[Seamless Portals]: WARNING! TRIED TO CREATE PORTAL WITH INVALID SIZE")
		return
	end
	self:EnableCustomCollisions(true)

	if CLIENT then
		--self:MakePhysicsObjectAShadow(false, false)
		self:SetRenderBounds(-size, size)
	end

	local phys = self:GetPhysicsObject()
	phys:EnableMotion(false)
	phys:SetMaterial("glass")
	phys:SetMass(250)
end

SeamlessPortals.Portals = SeamlessPortals.Portals or {}
SeamlessPortals.TransformPortal = function(a, b, pos, ang)
	if !IsValid(a) or !IsValid(b) then return Vector(), Angle() end
	local editedPos = Vector()
	local editedAng = Angle()

	if pos then
		editedPos = a:WorldToLocal(pos) * (b:GetSize()[1] / a:GetSize()[1])
		editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
		editedPos = editedPos + b:GetUp() * 0.01 -- So you don't become trapped
	end

	if ang then
		local localAng = a:WorldToLocalAngles(ang)
		editedAng = b:LocalToWorldAngles(Angle(-localAng[1], -localAng[2], localAng[3] + 180))
	end

	-- Mirror portal
	if a == b then
		if pos then
			editedPos = a:LocalToWorld(a:WorldToLocal(pos) * Vector(1, 1, -1))
		end

		if ang then
			local localAng = a:WorldToLocalAngles(ang)
			editedAng = a:LocalToWorldAngles(Angle(-localAng[1], localAng[2], -localAng[3] + 180))
		end
	end

	return editedPos, editedAng
end

-- Only render the portals that are in the frustum, or should be rendered
SeamlessPortals.ShouldRender = function(portal, eyePos, eyeAngle, distance)
  if portal:IsDormant() then return false end
	local portalPos, portalUp, exitSize = portal:GetPos(), portal:GetUp(), portal:GetSize()
	local max, eye = math.max(exitSize[1], exitSize[2]), (eyePos - portalPos)
	-- (eyePos - portalPos):Dot(portalUp) > (-10 * max) -- true if behind the portal, false otherwise
	-- eyePos:DistToSqr(portalPos) < distance^2 * max -- true if close enough
	-- (eyePos - portalPos):Dot(eyeAngle:Forward()) < 50 * max -- true if looking at the portal, false otherwise
	if(eye:Dot(portalUp) <= -exitSize[3]) then return false end -- First condition is not met so bail put
	if(eye:LengthSqr() >= distance^2 * max) then return false end -- Second condition is not met so bail put
	return (eye:Dot(eyeAngle:Forward()) < max) -- Decides the return value of the function
end
