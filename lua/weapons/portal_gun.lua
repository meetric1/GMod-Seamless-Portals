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
 * Calculates surface normal angle by using cross products
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

-- so the size is in source units (remember we are using sine/cosine)
local size_mult = Vector(math.sqrt(2) / 2, math.sqrt(2) / 2, 1)
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

	-- Extrude portal from the ground
	local port_fw, port_up = ang:Forward(), ang:Right()
	local copy_fw, copy_up = Vector(port_fw), Vector(port_fw)
	local hit_pos = tr.HitPos + tr.HitNormal
	copy_fw:Mul(siz[1] * size_mult[1])
	copy_up:Mul(siz[2] * size_mult[2])

	local angTab = {
		copy_fw, copy_fw:GetNegated(),
		copy_up, copy_up:GetNegated()
	}
	for i = 1, 4 do
		local extr = SeamlessPortals.TraceLine({
			start  = hit_pos,
			endpos = hit_pos - angTab[i],
			filter = seamlessCheck,
		})

		if extr.Hit then
			tr.HitPos:Add(angTab[i] * (1 - extr.Fraction))
		end
	end

	pos:Set(tr.HitNormal)
	pos:Mul(mul)
	pos:Add(tr.HitPos)

	portal:SetPos(pos)
	portal:SetAngles(ang)
	if CPPI then portal:CPPISetOwner(owner) end
end

function SWEP:ShootFX(sfx, rel)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

	if IsFirstTimePredicted() then
		local sfx = tostring(sfx or ""):Trim()
		if CLIENT or game.SinglePlayer() then
			-- literally cannot change the volume. Wtf
			EmitSound(sfx, Vector(), self:EntIndex(), 1, 1)
			--self:EmitSound(sfx, 60, 100, 0.25, CHAN_AUTO)
		end
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
		ent:SetSize(Vector(66, 34, 8))
		ent:SetSides(50)
		self[key] = ent
	end
	return ent
end

function SWEP:ClearSpawn(base, link)
	if base then SafeRemoveEntity(self[base]) end
	if link then SafeRemoveEntity(self[link]) end
end

function SWEP:DoLink(base, link, colr)
	local ent = self:DoSpawn(base)
	if !ent or !ent:IsValid() then self:ClearSpawn(base)
		ErrorNoHalt("Failed linking seamless portal "..base.." > "..link.."!\n"); return end
	ent:SetColor(colr)
	ent:LinkPortal(self[link])
	setPortalPlacement(self:GetOwner(), ent)
	self:SetNextPrimaryFire(CurTime() + 0.25)
end

function SWEP:PrimaryAttack()
	self:ShootFX("NPC_Vortigaunt.Shoot")
	if CLIENT then return end
	self:DoLink("Portal1", "Portal2", Color(0, 0, 255))
end

function SWEP:SecondaryAttack()
	self:ShootFX("NPC_Vortigaunt.Shoot")
	if CLIENT then return end
	self:DoLink("Portal2", "Portal1", Color(0, 255, 0))
end

function SWEP:OnRemove()
	self:ClearSpawn("Portal1", "Portal2")
end

function SWEP:Reload()
	self:SendWeaponAnim(ACT_VM_RELOAD)
	self:GetOwner():SetAnimation(PLAYER_RELOAD)

	if CLIENT then return end
	self:ClearSpawn("Portal1", "Portal2")
end

-- Index the global table
SeamlessPortals = SeamlessPortals or {}
SeamlessPortals.SeamlessCheck = seamlessCheck
SeamlessPortals.GetSurfaceAngle = getSurfaceAngle
SeamlessPortals.SetPortalPlacement = setPortalPlacement
