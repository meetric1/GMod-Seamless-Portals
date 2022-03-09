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
 * Calculate surface normal angle by using cross products instead of trig
 * This will enable the SWEP to place portals on any sureface and angle
 * You can rotate the angle how you like after being sefined by the hit surface
 * owner > The player that does the trace
 * norm  > The trace hit surface normal vector
 * Returns the angle being tangent to the surface at trace hit position
]]
local function getSurfaceAngle(owner, norm)
	local fwd = owner:GetAimVector()
	local rgh = fwd:Cross(norm); fwd:Set(norm:Cross(rgh))
	return fwd:AngleEx(norm)
end

local gtCheck =
{
	["player"]          = true,
	["seamless_portal"] = true
}

local function checkSeamless(e)
	if(!IsValid(e)) then return false end
	return !gtCheck[e:GetClass()]
end

local function setPortalPlacement(owner, portal)
	local tr = util.TraceLine({
		start = owner:GetShootPos(),
		endpos = owner:GetShootPos() + owner:GetAimVector() * 99999,
		filter = checkSeamless,
		noDetour = true,
	})

	local rotatedAng = getSurfaceAngle(owner, tr.HitNormal)

	portal:SetPos((tr.HitPos + tr.HitNormal * 10 * portal:GetExitSize()[3]))	--20
	portal:SetAngles(rotatedAng)
	if CPPI then portal:CPPISetOwner(owner) end
end

function SWEP:ShootFX(primary)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self.Owner:SetAnimation(PLAYER_ATTACK1)

	if CLIENT then
		EmitSound("NPC_Vortigaunt.Shoot", self:GetPos(), self:EntIndex(), CHAN_AUTO, 0.25)	-- quieter for client
	end
end

function SWEP:PrimaryAttack()
	self:ShootFX(true)
	if CLIENT then return end

	if !self.Portal or !self.Portal:IsValid() then
		self.Portal = ents.Create("seamless_portal")
		self.Portal:Spawn()
		self.Portal:LinkPortal(self.Portal2)
		self.Portal:SetExitSize(Vector(1, 0.6, 1))
	end

	setPortalPlacement(self.Owner, self.Portal)
	self:SetNextPrimaryFire(CurTime() + 0.1)
end

function SWEP:SecondaryAttack()
	self:ShootFX(true)
	if CLIENT then return end

	if !self.Portal2 or !self.Portal2:IsValid() then
		self.Portal2 = ents.Create("seamless_portal")
		self.Portal2:Spawn()
		self.Portal2:LinkPortal(self.Portal)
		self.Portal2:SetExitSize(Vector(1, 0.6, 1))
	end

	setPortalPlacement(self.Owner, self.Portal2)
	self:SetNextSecondaryFire(CurTime() + 0.1)
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
SeamlessPortals.checkSeamless = checkSeamless
SeamlessPortals.getSurfaceAngle = getSurfaceAngle
SeamlessPortals.setPortalPlacement = setPortalPlacement
