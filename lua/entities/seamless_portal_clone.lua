AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category          = "Seamless Portals"
ENT.PrintName         = "Physics Prop"
ENT.Author            = "Meetric"
ENT.Purpose           = ""
ENT.Instructions      = ""
ENT.PhysgunDisabled   = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Child")
    self:NetworkVar("Entity", 1, "Portal1")
    self:NetworkVar("Entity", 2, "Portal2")
end

local function transform_portal_local(portal1, portal2, dir)
	dir = SeamlessPortals.TransformPortal(portal1, portal2, dir + portal1:GetPos())
	dir:Sub(portal2:GetPos())

	return dir
end

function ENT:Think()
	if SERVER then
		self:VerletWeld(self, self:GetChild())
		self:NextThink(CurTime())
		return true
	end

	local child = self:GetChild()
	if !IsValid(child) then return end

	local portal1 = self:GetPortal1()
	local portal2 = self:GetPortal2()
	local new_pos, new_ang = SeamlessPortals.TransformPortal(portal1, portal2, child:GetPos(), child:GetAngles())
    self:SetRenderOrigin(new_pos)
    self:SetRenderAngles(new_ang)

    local clip_up1 = portal1:GetUp()
    local clip_pos1 = portal1:GetPos()
    clip_pos1:Sub(clip_up1 * portal1:GetSize()[3])
    child:SetRenderClipPlaneEnabled(true)
	child:SetRenderClipPlane(clip_up1, clip_up1:Dot(clip_pos1))

	local clip_up2 = portal2:GetUp()
    local clip_pos2 = portal2:GetPos()
    clip_pos2:Sub(clip_up2 * portal2:GetSize()[3])
    self:SetRenderClipPlaneEnabled(true)
	self:SetRenderClipPlane(clip_up2, clip_up2:Dot(clip_pos2))

	self:SetNextClientThink(CurTime())
	return true
end

if SERVER then
	local function abs_ratio(scale1, scale2)
		if scale1 > scale2 then
			return scale1 / scale2
		end

		return scale2 / scale1
	end

	local function unfucked_SetModelScale(self, scale)
		if scale < 1.001 and scale > 0.999 then -- floating point :/
			scale = 1
		end

		local self_phys = self:GetPhysicsObject()
		if !IsValid(self_phys) then return end

		self:SetModelScale(scale)

		-- don't scale if it will likely lag us
		local max_verts = 0
		for _, convex in ipairs(self_phys:GetMeshConvexes()) do
			max_verts = math.max(max_verts, #convex)
		end

		if max_verts < 2000 then
			self:PhysicsInit(self:GetSolid())
			self:Activate()
		end

		self_phys = self:GetPhysicsObject()
		self_phys:SetMass(self_phys:GetMass() * scale * scale) -- realistic mass calculation

		return self_phys
	end

	-- 2 way coupling
	function ENT:VerletWeld(e1, e2, setpos)
		local portal1 = self:GetPortal1()
		local portal2 = self:GetPortal2()

		local e1_phys = e1:GetPhysicsObject()
		local e2_phys = e2:GetPhysicsObject()
		if !IsValid(e1_phys) or !IsValid(e2_phys) then return end

		local motion = e2_phys:IsMotionEnabled()
		e1_phys:EnableMotion(motion)

		local e2_vel = e2_phys:GetVelocity()
		local e2_angvel = e2_phys:GetAngleVelocity()

		if setpos or !motion then
			local e1_pos, e1_ang = SeamlessPortals.TransformPortal(portal1, portal2, e2:GetPos(), e2:GetAngles())
			local e1_vel = transform_portal_local(portal1, portal2, e2_vel)

			-- scaling
			if setpos then
				local e2_scale = e1:GetModelScale()
				if abs_ratio(e2_scale, e2:GetModelScale()) > 1.1 then -- > 10% change
					e2_phys = unfucked_SetModelScale(e2, e2_scale)
					e2_phys:SetVelocity(e2_vel)
					e2_phys:SetAngleVelocity(e2_angvel)
				end

				local e1_scale = e2_scale * (portal2:GetSize()[1] / portal1:GetSize()[1])
				if abs_ratio(e1_scale, e2_scale) > 1.1 then
					e1_phys = unfucked_SetModelScale(e1, e1_scale)
					e1_phys = e1:GetPhysicsObject()
				end
			end

			e1:SetPos(e1_pos)
			e1:SetAngles(e1_ang)
			e1_phys:SetVelocity(e1_vel)
			e1_phys:SetAngleVelocity(e2_angvel) -- already in local frame, no transform needed

			return
		end

		local e1_pos, e1_ang = SeamlessPortals.TransformPortal(portal2, portal1, e1_phys:GetPos(), e1_phys:GetAngles())

		local pos_delta = (e2_phys:GetPos() - e1_pos)
		local ang_delta = e2:WorldToLocalAngles(e1_ang)
		ang_delta = Vector(ang_delta[3], ang_delta[1], ang_delta[2])

		local bounding_diameter = e1:BoundingRadius() * 2
		local e1_percentage_through = math.Clamp((e1_pos - portal1:GetPos()):Dot(portal1:GetUp()) / bounding_diameter + 0.5, 0.5, 0.9)
		local e2_percentage_through = 1 - e1_percentage_through

		local e1_vel = transform_portal_local(portal2, portal1, e1_phys:GetVelocity())
		local e1_angvel = e1_phys:GetAngleVelocity() -- already in local frame
		local vel_average = (e2_vel * e1_percentage_through + e1_vel * e2_percentage_through)
		local angvel_average = (e2_angvel * e1_percentage_through + e1_angvel * e2_percentage_through)

		local pos_delta_frametime = pos_delta / (FrameTime() * 2)
		local e1_phys_vel = (vel_average + pos_delta_frametime * e1_percentage_through)
		local e2_phys_vel = (vel_average - pos_delta_frametime * e2_percentage_through)
		e1_phys_vel = transform_portal_local(portal1, portal2, e1_phys_vel)

		local ang_delta_frametime = ang_delta / (FrameTime() * 2)
		local e1_phys_angvel = (angvel_average - ang_delta_frametime * e1_percentage_through)
		local e2_phys_angvel = (angvel_average + ang_delta_frametime * e2_percentage_through)

		e1_phys:SetVelocity(e1_phys_vel)
	    e1_phys:SetAngleVelocity(e1_phys_angvel)

	    e2_phys:SetVelocity(e2_phys_vel)
	    e2_phys:SetAngleVelocity(e2_phys_angvel)
	end

	function ENT:Initialize()
		local child = self:GetChild()
		local portal1 = self:GetPortal1()
		local portal2 = self:GetPortal2()

		self:SetCollisionGroup(child:GetCollisionGroup())
		self:SetColor(child:GetColor())
		self:SetModel(child:GetModel())
		self:SetMaterial(child:GetMaterial())
		self:SetSkin(child:GetSkin())
		self:SetSolid(child:GetSolid())
		self:SetMoveType(child:GetMoveType())
		if !self:PhysicsInit(child:GetSolid()) then return end
		self:SetLightingOriginEntity(child)
		self:SetModelScale(child:GetModelScale())
		self:GetPhysicsObject():SetMass(child:GetPhysicsObject():GetMass())
		self:VerletWeld(self, child, true)
		child:DeleteOnRemove(self)
		portal1:DeleteOnRemove(self)
		portal2:DeleteOnRemove(self)
		constraint.NoCollide(self, game.GetWorld(), 0, 0, false)
	end

	function ENT:OnTakeDamage(damage)
		local child = self:GetChild()
		local portal1 = self:GetPortal1()
		local portal2 = self:GetPortal2()
		damage:SetDamagePosition(child:LocalToWorld(self:WorldToLocal(damage:GetDamagePosition())))
		damage:SetDamageForce(transform_portal_local(portal2, portal1, damage:GetDamageForce()))
		child:TakeDamageInfo(damage)
	end
else
	function ENT:OnRemove()
        local child = self:GetChild()
		if !IsValid(child) then return end

		child:SetRenderClipPlaneEnabled(false)
	end
end

function ENT:CanTool()
    return false
end
