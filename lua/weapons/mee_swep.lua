SWEP.Base = "weapon_base"
SWEP.PrintName = "Portal Gun"

SWEP.ViewModel = "models/weapons/c_irifle.mdl"
SWEP.ViewModelFlip = false
SWEP.UseHands = false

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

-- from portal gun addon
local function VectorAngle(vec1, vec2)
	local costheta = vec1:Dot(vec2) / (vec1:Length() * vec2:Length())
	local theta = math.acos(costheta)
	return math.deg(theta)
end

function SWEP:PrimaryAttack()
	local tr = self.Owner:GetEyeTrace()
	local offset = math.abs(tr.HitNormal:Dot(Vector(0, 0, 1))) * 7
	local rotatedAng = tr.HitNormal:Angle() + Angle(90, 0, 0)

	local elevationangle = VectorAngle(vector_up, tr.HitNormal)
	if elevationangle < 1 or (elevationangle > 179 and elevationangle < 181) then 
		rotatedAng.y = self.Owner:EyeAngles().y + 180
	end

	self.Portals:SetPos((tr.HitPos + tr.HitNormal * 18) + Vector(0, 0, offset))
	self.Portals:SetAngles(rotatedAng)
	self:SetNextPrimaryFire(1)
end

function SWEP:OnRemove()
	SafeRemoveEntity(self.Portals)
	SafeRemoveEntity(self.Portals:ExitPortal())
end

function SWEP:SecondaryAttack() 
	local tr = self.Owner:GetEyeTrace()
	local offset = math.abs(tr.HitNormal:Dot(Vector(0, 0, 1))) * 7
	local rotatedAng = tr.HitNormal:Angle() + Angle(90, 0, 0)

	local elevationangle = VectorAngle(vector_up, tr.HitNormal)
	if elevationangle <= 15 or (elevationangle >= 175 and elevationangle <= 185) then 
		rotatedAng.y = self.Owner:EyeAngles().y + 180
	end

	self.Portals:ExitPortal():SetPos((tr.HitPos + tr.HitNormal * 18) + Vector(0, 0, offset))
	self.Portals:ExitPortal():SetAngles(rotatedAng)
	self:SetNextSecondaryFire(1)
end

