ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     = "Seamless Portals"
ENT.PrintName    = "Cutout"
ENT.Author       = "Meetric"
ENT.Purpose      = ""
ENT.Instructions = ""
ENT.ENTITIES     = {}
ENT.VERTICES     = {}

-- SERVER only entity
-- physically cuts a hole in the world,
-- code reused from Earthbending

-- tris are in the format {pos1, pos2, pos3, ...}
-- code based on Glass: Rewrite
local function cut_concave(tris, plane_pos, plane_dir)
	plane_dir = plane_dir:GetNormalized()

	local split_tris = {}
	local intersect = util.IntersectRayWithPlane

	local function inside(p)
		return (p - plane_pos):Dot(plane_dir) >= 0
	end

	-- sutherland-hodgman
	local function clip(poly)
		local result = {}

		for i = 1, #poly do
			local a = poly[i] -- current
			local b = poly[i % #poly + 1] -- previous
			local a_in = inside(a)
			local b_in = inside(b)

			if a_in and b_in then
				result[#result + 1] = b
			elseif a_in then
				result[#result + 1] = intersect(a, b - a, plane_pos, plane_dir) or b
			elseif b_in then
				result[#result + 1] = intersect(a, b - a, plane_pos, plane_dir) or b
				result[#result + 1] = b
			end
		end

		return result
	end

	for i = 1, #tris, 3 do
		local poly = clip({
			tris[i    ],
			tris[i + 1],
			tris[i + 2]
		})

		for j = 2, #poly - 1 do
			split_tris[#split_tris + 1] = poly[1    ]
			split_tris[#split_tris + 1] = poly[j    ]
			split_tris[#split_tris + 1] = poly[j + 1]
		end
	end

	return split_tris
end

-- __eq vector comparisons are too precise
local function vector_equal(v0, v1)
    return (v0 - v1):LengthSqr() < 1e-3
end

local function trace_local(self, start_pos, end_pos)
	local tr_table = {
        start = self:LocalToWorld(start_pos),
        endpos = self:LocalToWorld(end_pos),
        mask = 131083, -- world only
    }

    local tr = SeamlessPortals.TraceLine(tr_table)

	if tr.Fraction == 1 and tr.StartSolid then
		return start_pos
	end

    return self:WorldToLocal(tr.HitPos)
end

function ENT:SetPortal(portal)
	self.SEAMLESS_PORTALS_CUTOUT_PORTAL = portal
end

function ENT:GetPortal()
	return self.SEAMLESS_PORTALS_CUTOUT_PORTAL
end

function ENT:Initialize()
    self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR) -- props only
    self:SetTrigger(true)
end

-- approximates the world surface with a hole cut into it
function ENT:GeneratePhysmesh(portal, new)
	local size = portal:GetSize()
	local offset = size / 2

	if new then self.VERTICES = {} end
	local vertices = {}

	local function pos_local(x, y, z)
		return Vector(x * size[1] - offset[1], y * size[2] - offset[2], z - size[3])
	end

	local inset = -2
	local pos00 = pos_local(0, 0, inset)
	local pos10 = pos_local(1, 0, inset)
	local pos01 = pos_local(0, 1, inset)
	local pos11 = pos_local(1, 1, inset)

	local function generate_tri(pos0, pos1, pos2)
		-- check for degen triangles
		if vector_equal(pos0, pos1) or vector_equal(pos0, pos2) or vector_equal(pos1, pos2) then return end

		local len = #vertices
		vertices[len + 1] = pos0
		vertices[len + 2] = pos1
		vertices[len + 3] = pos2
	end

	local function generate_quad(pos0, pos1, pos2, pos3)
		-- check for degen triangles
		if vector_equal(pos0, pos1) or vector_equal(pos0, pos3) or vector_equal(pos1, pos3) then return end
		if vector_equal(pos3, pos2) or vector_equal(pos3, pos0) or vector_equal(pos2, pos0) then return end

		local len = #vertices
		vertices[len + 1] = pos0
		vertices[len + 2] = pos1
		vertices[len + 3] = pos3
		vertices[len + 4] = pos3
		vertices[len + 5] = pos2
		vertices[len + 6] = pos0
	end

	local function trace_local_generate_quad(start_pos, end_pos)
		local tr = SeamlessPortals.TraceLine({
			start = portal:LocalToWorld(start_pos),
			endpos = portal:LocalToWorld(end_pos),
			mask = 131083, -- world only
		})

		if !tr.Hit then return nil end

		tr.HitAngle = portal:WorldToLocalAngles(tr.HitNormal:Angle())
		tr.HitPos = portal:WorldToLocal(tr.HitPos)

		local right = tr.HitAngle:Right() * size[1] * 1.5
		local front = tr.HitAngle:Up() * size[1] * 1.5
		generate_quad(tr.HitPos - front + right, tr.HitPos + front + right, tr.HitPos - front - right, tr.HitPos + front - right)
	end

    -- ground quads
    trace_local_generate_quad(pos_local(0.5, 0.5, offset[3]), pos_local(2.5, 0.5, offset[3]))
    trace_local_generate_quad(pos_local(0.5, 0.5, offset[3]), pos_local(-1.5, 0.5, offset[3]))
    trace_local_generate_quad(pos_local(0.5, 0.5, offset[3]), pos_local(0.5, 2.5, offset[3]))
    trace_local_generate_quad(pos_local(0.5, 0.5, offset[3]), pos_local(0.5, -1.5, offset[3]))
	trace_local_generate_quad(pos_local(0.5, 0.5, offset[3]), pos_local(0.5, 0.5, offset[1] * 3))

	-- inner quads
	if !new then
		local pos00_z = Vector(pos00[1], pos00[2])
		local pos01_z = Vector(pos01[1], pos01[2])
		local pos10_z = Vector(pos10[1], pos10[2])
		local pos11_z = Vector(pos11[1], pos11[2])
	    generate_quad(pos00_z, pos00_z * 1.1, pos01_z, pos01_z * 1.1)
	    generate_quad(pos10_z, pos10_z * 1.1, pos00_z, pos00_z * 1.1)
	    generate_quad(pos11_z, pos11_z * 1.1, pos10_z, pos10_z * 1.1)
	    generate_quad(pos01_z, pos01_z * 1.1, pos11_z, pos11_z * 1.1)
    end

	if #vertices <= 0 then return end

	vertices = cut_concave(vertices, vector_origin, Vector(0, 0, 1))
	if new then -- invert cut
		local ratio = portal:GetExitPortal():GetSize()[1] / portal:GetSize()[1]
		local negated_verts = {}
		for _, v in ipairs(vertices) do
			if !negated_verts[v] then
				v[2] = -v[2]
				v[3] = -v[3]
				v:Mul(ratio)
				negated_verts[v] = true
			end
		end
	else
		--    f0 f1
		-- l1 01 11 r1
		-- l0 00 10 r0
		--    b0 b1
		local front0 = trace_local(portal, pos01 + Vector(0, 100, -inset), pos01)
		local front1 = trace_local(portal, pos11 + Vector(0, 100, -inset), pos11)
		local back0  = trace_local(portal, pos00 - Vector(0, 100, -inset), pos00)
		local back1  = trace_local(portal, pos10 - Vector(0, 100, -inset), pos10)
		local right0 = trace_local(portal, pos10 + Vector(100, 0, -inset), pos10)
		local right1 = trace_local(portal, pos11 + Vector(100, 0, -inset), pos11)
		local left0  = trace_local(portal, pos00 - Vector(100, 0, -inset), pos00)
		local left1  = trace_local(portal, pos01 - Vector(100, 0, -inset), pos01)

		-- corner triangles
		generate_tri(left0, pos00, back0)
		generate_tri(back1, pos10, right0)
		generate_tri(right1, pos11, front1)
		generate_tri(front0, pos01, left1)

		-- edge quads
		generate_quad(pos00, left0, pos01, left1)
		generate_quad(pos10, back1, pos00, back0)
		generate_quad(pos10, pos11, right0, right1)
		generate_quad(front1, pos11, front0, pos01)
    end
	--[[
	for i = 1, #vertices, 3 do
		debugoverlay.Triangle(
			self:LocalToWorld(vertices[i]), self:LocalToWorld(vertices[i + 1]), self:LocalToWorld(vertices[i + 2]),
			0.5, Color(255, 255, 255, 5), false
		)
	end]]

    for _, v in ipairs(vertices) do
    	table.insert(self.VERTICES, v)
    end
end

function ENT:CreatePhysmesh()
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)
	self:PhysicsFromMesh(self.VERTICES)
	self:EnableCustomCollisions(true)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
		phys:SetPos(self:GetPos())
		phys:SetAngles(self:GetAngles())
	end
end

local allowed_classes = {
	["prop_physics"] = true,
	["prop_vehicle_airboat"] = true,
	["prop_vehicle_prisoner_pod"] = true,
	["prop_combine_ball"] = true,
}

function ENT:Think()
	local portal = self:GetPortal()
	local size = portal:GetSize()
	size[1] = size[1] / 2
	size[2] = size[2] / 2

	local mins, maxs = self:GetRotatedAABB(-size, Vector(size[1], size[2]))
	local self_pos = self:GetPos()
	mins:Add(self_pos)
	maxs:Add(self_pos)

	--debugoverlay.Box(Vector(), mins, maxs, 1/3, Color(0, 255, 0, 0))
	--debugoverlay.BoxAngles(self_pos, -size, Vector(size[1], size[2], 0), self:GetAngles(), 1/3, Color(255, 0, 255, 0))

	-- Add entities to cutout
	local old_ents = table.Copy(self.ENTITIES)
    local valid_ents = ents.FindInBox(mins, maxs)
    local self_forward = self:GetForward()
    local self_right = self:GetRight()
    local self_up = self:GetUp()
    local max_bounding = portal:BoundingRadius() * 4
	for _, ent in ipairs(valid_ents) do
		if !allowed_classes[ent:GetClass()] then continue end
		if ent:BoundingRadius() > max_bounding then continue end

		if ent:GetVelocity():Dot(self_up) >= 0 then
			old_ents[ent] = nil -- if added, don't bother removing
			continue
		end

		-- trim out entities not infront of portal
		local ent_pos = ent:LocalToWorld(ent:OBBCenter()) ent_pos:Sub(self_pos)
		local ent_dot_forward = math.abs(ent_pos:Dot(self_forward))
		if ent_dot_forward > size[1] then continue end
		local ent_dot_right = math.abs(ent_pos:Dot(self_right))
		if ent_dot_right > size[2] then continue end

		if !old_ents[ent] then
			self:AddEntity(ent)
			constraint.RemoveAll(ent) -- yeah. not even gonna try
		end
		old_ents[ent] = nil
	end

	for ent, _ in pairs(old_ents) do
		-- if we're behind portal, don't remove (teleport code will hopefully remove us at some point..)
		if IsValid(ent) and (ent:GetPos() - portal:GetPos()):Dot(portal:GetUp()) < 0 then
			continue
		end

		self:RemoveEntity(ent)
	end

    self:NextThink(CurTime())
    return true
end

local logic_collision_pair = ents.Create("logic_collision_pair")
logic_collision_pair:Spawn()
local function set_collision(ent, ent2, enable)
	if !IsValid(ent) then return end

	local ent_phys = ent:GetPhysicsObject()
	local ent2_phys = ent2:GetPhysicsObject()
	if !IsValid(ent_phys) or !IsValid(ent2_phys) then return end

	logic_collision_pair:SetPhysConstraintObjects(ent_phys, ent2_phys)
	logic_collision_pair:Activate()
	logic_collision_pair:Input(enable and "EnableCollisions" or "DisableCollisions")

	if IsValid(ent_phys) then
		ent_phys:RecheckCollisionFilter()
	end
end

function ENT:AddEntity(ent)
	if self.ENTITIES[ent] then return end
	if ent.SEAMLESS_PORTALS_CUTOUT then return end

	self.ENTITIES[ent] = true
	ent.SEAMLESS_PORTALS_CUTOUT = self
	set_collision(ent, game.GetWorld(), false)
	set_collision(ent, self, true)
end

function ENT:RemoveEntity(ent, keep_clone)
	if IsValid(ent) and ent.SEAMLESS_PORTALS_CUTOUT != self then return end
	if !keep_clone then SafeRemoveEntity(ent.SEAMLESS_PORTALS_CLONE) end

	self.ENTITIES[ent] = nil
	ent.SEAMLESS_PORTALS_CUTOUT = nil
	set_collision(ent, self, false)
	set_collision(ent, game.GetWorld(), true)
end

function ENT:PhysicsCollide(data)
	local ent = data.HitEntity
	if self.ENTITIES[ent] then return end

	set_collision(ent, self, false)

	-- we collided already, force recheck collision filters and undo collision
	local phys = data.HitObject
	if IsValid(data.HitObject) and phys:IsMotionEnabled() then
		phys:EnableMotion(false)
		phys:EnableMotion(true)
		phys:SetVelocity(data.TheirOldVelocity)
		phys:SetAngleVelocity(data.TheirOldAngularVelocity)
	end
end

function ENT:StartTouch(ent)
	timer.Simple(0, function() -- will crash without this!
		self:PhysicsCollide({HitEntity = ent})
	end)
end

function ENT:UpdateTransmitState()
	return TRANSMIT_NEVER
end

function ENT:TestCollision(_, delta, isbox, _, mask)
	return isbox and mask == 33570827 and !delta:IsZero() -- nothing except vphysics spawn trace
end

function ENT:OnRemove()
	for ent, _ in pairs(self.ENTITIES) do
		self:RemoveEntity(ent)
	end
end
