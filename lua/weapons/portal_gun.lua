SWEP.Base = "weapon_base"
SWEP.PrintName = "Portal Gun"

SWEP.ViewModel = "models/weapons/c_irifle.mdl"
SWEP.ViewModelFlip = false
SWEP.UseHands = true

SWEP.WorldModel = "models/weapons/w_irifle.mdl"
SWEP.SetHoldType = "pistol"

SWEP.Weight = 5
SWEP.AutoSwichTo = true
SWEP.AutoSwichFrom = false

SWEP.Category = "Seamless Portals"
SWEP.Slot = 0
SWEP.SlotPos = 1

SWEP.DrawAmmo = true
SWEP.DrawChrosshair = true

SWEP.Spawnable = true
SWEP.AdminSpawnable = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false

--[[
 * Calculate surface normal angle by using cross products
 * owner > The player that does the trace
 * norm  > The trace hit surface normal vector
 * Returns the angle tangent to the surface hit position
]]
local function getSurfaceAngle(owner, norm)
	local fwd = owner:GetAimVector()
	local rgh = fwd:Cross(norm)
	      fwd:Set(norm:Cross(rgh))
	return fwd:AngleEx(norm)
end

local gtCheck =
{
	["player"]          = true,
	["seamless_portal"] = true
}

local function seamlessCheck(e)
	if(!IsValid(e)) then return end
	return !gtCheck[e:GetClass()]
end

local size_mult = Vector(math.sqrt(2), math.sqrt(2), 1)	// so the size is in source units (remember we are using sine/cosine)
local function setPortalPlacement(owner, portal)
	local ang = Angle() -- The portal angle
	local siz = portal:GetSize()
	local pos = owner:GetShootPos()
	local aim = owner:GetAimVector()
	local mul = siz[3] * 1.1

	local tr = SeamlessPortals.TraceLine({
		start  = pos,
		endpos = pos + aim * 99999,
		filter = seamlessCheck
	})

	-- Align portals on 45 degree surfaces
	if math.abs(tr.HitNormal:Dot(ang:Up())) < 0.71 then
		ang:Set(tr.HitNormal:Angle())
		ang:RotateAroundAxis(ang:Right(), -90)
		ang:RotateAroundAxis(ang:Up(), 180)
	else -- Place portals on any surface and angle
		ang:Set(getSurfaceAngle(owner, tr.HitNormal))
	end

	-- extrude portal from the ground
	local af, au = ang:Forward(), ang:Right()
	local angTab = {
		 af * siz[1] * size_mult[1],
		-af * siz[1] * size_mult[1],
		 au * siz[2] * size_mult[2],
		-au * siz[2] * size_mult[2]
	}
	for i = 1, 4 do
		local extr = SeamlessPortals.TraceLine({
			start  = tr.HitPos + tr.HitNormal,
			endpos = tr.HitPos + tr.HitNormal - angTab[i],
			filter = seamlessCheck,
		})

		if extr.Hit then
			tr.HitPos = tr.HitPos + angTab[i] * (1 - extr.Fraction)
		end
	end

	portal:SetPos((tr.HitPos + mul * tr.HitNormal))	--20
	portal:SetAngles(ang)
	if CPPI then portal:CPPISetOwner(owner) end
end

function SWEP:ShootFX()
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self.Owner:SetAnimation(PLAYER_ATTACK1)

	if CLIENT and IsFirstTimePredicted() then
		EmitSound("NPC_Vortigaunt.Shoot", self:GetPos(), self:EntIndex(), CHAN_AUTO, 0.25)	-- quieter for client
	end
end

function SWEP:DoSpawn(key)
	if not key then return NULL end
	local ent = self[key]
	if !ent or !ent:IsValid() then
		ent = ents.Create("seamless_portal")
		if !ent or !ent:IsValid() then return NULL end
		ent:SetCreator(self:GetOwner())
		ent:Spawn()
		ent:SetSize(Vector(33, 17, 8))
		ent:SetSides(50)
		setPortalPlacement(self.Owner, ent)
		self[key] = ent
	end

	return ent
end

function SWEP:PrimaryAttack()
	self:ShootFX()
	if CLIENT then return end
	local ent = self:DoSpawn("Portal")
	if !ent or !ent:IsValid() then SafeRemoveEntity(ent)
		ErrorNoHalt("Failed to create blue portal!"); return end
	ent:SetColor(Color(0, 0, 255)) -- Blue
	ent:LinkPortal(self.Portal2)
	self:SetNextPrimaryFire(CurTime() + 0.25)
end

function SWEP:SecondaryAttack()
	self:ShootFX()
	if CLIENT then return end
	local ent = self:DoSpawn("Portal2")
	if !ent or !ent:IsValid() then SafeRemoveEntity(ent)
		ErrorNoHalt("Failed to create orange portal!"); return end
	ent:SetColor(Color(255, 165, 0)) -- Orange
	ent:LinkPortal(self.Portal)
	self:SetNextSecondaryFire(CurTime() + 0.25)
end

function SWEP:OnRemove()
	if CLIENT then return end
	SafeRemoveEntity(self.Portal)
	SafeRemoveEntity(self.Portal2)
end

function SWEP:Reload()
	if CLIENT then return end
	SafeRemoveEntity(self.Portal)
	SafeRemoveEntity(self.Portal2)
end

-- Index the global table
SeamlessPortals = SeamlessPortals or {}
SeamlessPortals.SeamlessCheck = seamlessCheck
SeamlessPortals.GetSurfaceAngle = getSurfaceAngle
SeamlessPortals.SetPortalPlacement = setPortalPlacement
