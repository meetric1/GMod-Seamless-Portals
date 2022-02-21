SWEP.Base = "weapon_base"
SWEP.PrintName = "the e"

SWEP.ViewModel = "models/weapons/c_irifle.mdl"
SWEP.ViewModelFlip = false
SWEP.UseHands = false

SWEP.WorldModel = "models/weapons/w_irifle.mdl"
SWEP.SetHoldType = "pistol"

SWEP.Weight = 5
SWEP.AutoSwichTo = true
SWEP.AutoSwichFrom = false

SWEP.Category = "lol"
SWEP.Slot = 0
SWEP.SlotPos = 1

SWEP.DrawAmmo = true
SWEP.DrawChrosshair = true

SWEP.Spawnable = true
SWEP.AdminSpawnable = false

SWEP.Primary.ClipSize = 0
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Ammo = "smg1"
SWEP.Primary.Delay = 1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1 
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false


--language.Add("#weapon_mee", "MEE'S WAPON")

if CLIENT then return end

function SWEP:Initialize()
	self:SetHoldType("pistol")
	self.Portals = ents.Create("seamless_portal")
	self.Portals:Spawn()
end


function SWEP:PrimaryAttack()
	local tr = self.Owner:GetEyeTrace()
	local offset = tr.HitNormal:Dot(Vector(0, 0, 1)) * 5
	self.Portals:SetPos((tr.HitPos + tr.HitNormal * 16) + Vector(0, 0, offset + 10))
	self.Portals:SetAngles(tr.HitNormal:Angle() + Angle(90, 0, 0))
	self:SetNextPrimaryFire(1)
end



function SWEP:SecondaryAttack() 
	local tr = self.Owner:GetEyeTrace()
	local offset = tr.HitNormal:Dot(Vector(0, 0, 1)) * 5
	self.Portals:ExitPortal():SetPos((tr.HitPos + tr.HitNormal * 16) + Vector(0, 0, offset + 10))
	self.Portals:ExitPortal():SetAngles(tr.HitNormal:Angle() + Angle(90, 0, 0))
	self:SetNextSecondaryFire(1)
end

