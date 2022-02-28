local skins = {
	[0] = {
		["viewModel"] = "models/weapons/c_irifle.mdl",
		["worldModel"] = "models/weapons/w_irifle.mdl",
		["useHands"] = true,
		["shootPrimarySound"] = "Weapon_AR2.Single",
		["shootSecondarySound"] = "Weapon_AR2.Single"
	},
	[1] = {
		["viewModel"] = "models/weapons/v_portalgun.mdl",
		["worldModel"] = "models/weapons/w_portalgun.mdl",
		["useHands"] = false,
		["shootPrimarySound"] = "weapons/portalgun/portalgun_shoot_red1.wav",
		["shootSecondarySound"] = "weapons/portalgun/portalgun_shoot_blue1.wav"
	},
	[2] = {
		["viewModel"] = "models/weapons/v_portalgun.mdl",
		["worldModel"] = "models/weapons/w_portalgun.mdl",
		["useHands"] = false,
		["shootPrimarySound"] = { "weapons/portalgun/portalgun_shoot_blue1.wav", "weapons/portalgun/wpn_portal_gun_fire_blue_01.wav", "weapons/portalgun/wpn_portal_gun_fire_blue_02.wav","weapons/portalgun/wpn_portal_gun_fire_blue_03.wav" },
		["shootSecondarySound"] = { "weapons/portalgun/portalgun_shoot_red1.wav", "weapons/portalgun/wpn_portal_gun_fire_red_01.wav", "weapons/portalgun/wpn_portal_gun_fire_red_02.wav","weapons/portalgun/wpn_portal_gun_fire_red_03.wav" }
	}
}

local skn = IsMounted("portal2") and 2 or (IsMounted("portal") and 1 or 0)

SWEP.Skin = skn

SWEP.Base = "weapon_base"
SWEP.PrintName = "Portal Gun"

SWEP.ViewModel = skins[skn]["viewModel"]
SWEP.ViewModelFlip = false
SWEP.UseHands = skins[skn]["useHands"]

SWEP.WorldModel = skins[skn]["worldModel"]
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

-- from portal gun addon
local function VectorAngle(vec1, vec2)
	local costheta = vec1:Dot(vec2) / (vec1:Length() * vec2:Length())
	local theta = math.acos(costheta)
	return math.deg(theta)
end

local seamless_check = function(e) return !(e:GetClass() == "seamless_portal" or e:GetClass() == "player") end 
local function setPortalPlacement(owner, portal)
	local tr = util.TraceLine({
		start = owner:GetShootPos(),
		endpos = owner:GetShootPos() + owner:GetAimVector() * 99999,
		filter = seamless_check,
	})
	local offset = tr.HitNormal:Dot(Vector(0, 0, 1)) * 23
	if offset < 0 then offset = offset * 0.1 end
	local rotatedAng = tr.HitNormal:Angle() + Angle(90, 0, 0)

	local elevationangle = VectorAngle(vector_up, tr.HitNormal)
	if elevationangle < 1 or (elevationangle > 179 and elevationangle < 181) then 
		rotatedAng.y = owner:EyeAngles().y + 180
	end

	portal:SetPos((tr.HitPos + tr.HitNormal * 6.5) + Vector(0, 0, offset, 0))	--20
	portal:SetAngles(rotatedAng)
end

SWEP.RandSalt = 0
function SWEP:ShootFX(primary)
	if (IsFirstTimePredicted()) then
		self.RandSalt = self.RandSalt + 1
	end
	local snd = skins[self.Skin][primary and "shootPrimarySound" or "shootSecondarySound"]
	if (istable(snd)) then
		local key = math.floor(util.SharedRandom("mee_swep_rand", 0, #snd, self.RandSalt)) + 1
		snd = snd[ key ]
	end
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self.Owner:SetAnimation(PLAYER_ATTACK1)
	self.Owner:EmitSound(snd)
end

function SWEP:PrimaryAttack()
	self:ShootFX(true)
	if CLIENT then return end

	if !self.Portal or !self.Portal:IsValid() then
		self.Portal = ents.Create("seamless_portal")
		self.Portal:Spawn()
		SafeRemoveEntity(self.Portal:ExitPortal()) -- is this necessary? it should only have an exit portal if it was spawned in the Q menu
		self.Portal:LinkPortal(self.Portal2)
		--self.Portal:SetExitSize(0.1)
	end

	setPortalPlacement(self.Owner, self.Portal)
	self:SetNextPrimaryFire(1)

	--walk through walls fix?
	--ply:SetHull(Vector(0, 0, 56), Vector(0, 0, 80))
	--ply:SetHullDuck(Vector(0, 0, 56), Vector(0, 0, 80))
end


function SWEP:SecondaryAttack() 
	self:ShootFX(false)
	if CLIENT then return end

	if !self.Portal2 or !self.Portal2:IsValid() then
		self.Portal2 = ents.Create("seamless_portal")
		self.Portal2:Spawn()
		SafeRemoveEntity(self.Portal2:ExitPortal())
		self.Portal2:LinkPortal(self.Portal)
	end

	setPortalPlacement(self.Owner, self.Portal2)
	self:SetNextSecondaryFire(1)
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

