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
	self:NetworkVar("Bool", 0, "DisableBackface")
	self:NetworkVar("Int", 0, "SidesInternal")

	if CLIENT then return end

	-- defaults, i guess?
	if self:GetSidesInternal() < 1 then
		self:SetSidesInternal(4)
	end

	if self:GetSizeInternal() != vector_origin then
		self:SetSizeInternal(Vector(50, 50, 8))
	end
end

function ENT:SetSides(sides)
	local shouldUpdatePhysmesh = self:GetSidesInternal() != sides
	self:SetSidesInternal(math.Clamp(sides, 3, 100))
	if shouldUpdatePhysmesh then self:UpdatePhysmesh() end
end

function ENT:GetSize()
	local size = self:GetSizeInternal()
	size[1] = size[1] * 2
	size[2] = size[2] * 2
	return size
end

-- So the size is in source units (remember we are using sine/cosine)
local size_mult = Vector(math.sqrt(2) / 2, math.sqrt(2) / 2, 1)

-- Scale the phys mesh
function ENT:UpdatePhysmesh()
	local sizev = self:GetSize() * size_mult
	local finalMesh = {}
	local sides = self:GetSidesInternal()
	local angleMul = 360 / sides
	local degreeOffset = (sides * 90 + (sides % 4 != 0 and 0 or 45)) * (math.pi / 180)
	for side = 1, sides do
		local sidea = math.rad(side * angleMul) + degreeOffset
		local sidex = math.sin(sidea)
		local sidey = math.cos(sidea)
		local side1 = Vector(sidex, sidey, -1)
		local side2 = Vector(sidex, sidey,  0)
		table.insert(finalMesh, side1 * sizev)
		table.insert(finalMesh, side2 * sizev)
	end
	self:PhysicsInitConvex(finalMesh)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:EnableCustomCollisions(true)
	self:GetPhysicsObject():EnableMotion(false)
	self:GetPhysicsObject():SetMaterial("glass")
	self:GetPhysicsObject():SetMass(250)

	if CLIENT then
		self:SetRenderBounds(-sizev, sizev)
	end
end

SeamlessPortals.Portals = {}
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
