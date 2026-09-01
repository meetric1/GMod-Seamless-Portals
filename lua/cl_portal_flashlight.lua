-- Mimics the sourceengine flashlight, given the player eyepos and angle
-- returns a projected texture, or nil if the flashlight is off

local light_size = Vector(4, 4, 4)
local light_size_negative = -light_size

-- //========= Copyright Valve Corporation, All rights reserved. ============//

local r_flashlightoffsety = GetConVar("r_flashlightoffsety")
local r_swingflashlight = GetConVar("r_swingflashlight")
local r_flashlightladderdist = GetConVar("r_flashlightladderdist")
local r_flashlightfar = GetConVar("r_flashlightfar")
local r_flashlightquadratic = GetConVar("r_flashlightquadratic")
local r_flashlightlinear = GetConVar("r_flashlightlinear")
local r_flashlightfov = GetConVar("r_flashlightfov")
local r_flashlightconstant = GetConVar("r_flashlightconstant")
local r_flashlightambient = GetConVar("r_flashlightambient")
local r_flashlightnear = GetConVar("r_flashlightnear")

-- Adapted from https://github.com/ValveSoftware/source-sdk-2013/blob/c22529f725414dbb857ace0f170013ab32d35fff/src/mathlib/mathlib_base.cpp#L2102
local mat = Matrix()
local function BasisToQuaternion(forward, right, up)
	mat:SetForward(forward)
	mat:SetRight(-right)
	mat:SetUp(up)
	return mat:GetAngles()
end

-- Adapted from https://github.com/ValveSoftware/source-sdk-2013/blob/c22529f725414dbb857ace0f170013ab32d35fff/src/game/client/flashlighteffect.cpp#L152
local function UpdateLightNew(vecPos, vecAng)
	local LocalPlayer = LocalPlayer()
	if !LocalPlayer:FlashlightIsOn() then
		SeamlessPortals.m_flDistMod = nil
		return nil
	end

	local m_flDistMod = SeamlessPortals.m_flDistMod or 0
	local state = ProjectedTexture()
	local vecForward = vecAng:Forward()
	local vecRight = vecAng:Right()
	local vecUp = vecAng:Up()

	local bPlayerOnLadder = LocalPlayer:GetMoveType() == MOVETYPE_LADDER

	local flEpsilon = 0.1 -- Offset flashlight position along vecUp
	local flDistCutoff = 128.0
	local flDistDrag = 0.2

	local traceFilter = LocalPlayer
	local flOffsetY = r_flashlightoffsety:GetFloat()

	if r_swingflashlight:GetBool() then
		-- This projects the view direction backwards, attempting to raise the vertical
		-- offset of the flashlight, but only when the player is looking down.
		local vecSwingLight = vecPos + vecForward * -12.0
		if vecSwingLight.z > vecPos.z then
			flOffsetY = flOffsetY + (vecSwingLight.z - vecPos.z)
		end
	end

	local vOrigin = vecPos + flOffsetY * vecUp

	-- Not on ladder...trace a hull
	if !bPlayerOnLadder then
		local pmOriginTrace = util.TraceHull({
			start = vecPos,
			endpos = vOrigin,
			mins = light_size_negative,
			maxs = light_size,
			mask = bit.band(MASK_SOLID, bit.bnot(CONTENTS_HITBOX)),
			filter = traceFilter
		})

		if pmOriginTrace.Hit then
			vOrigin = Vector(vecPos)
		end
	else -- on ladder...skip the above hull trace
		vOrigin = Vector(vecPos)
	end

	-- Now do a trace along the flashlight direction to ensure there is nothing within range to pull back from
	local iMask = MASK_OPAQUE_AND_NPCS
	iMask = bit.band(iMask, bit.bnot(CONTENTS_HITBOX))
	iMask = bit.bor(iMask, CONTENTS_WINDOW)

	local vTarget = vecPos + vecForward * r_flashlightfar:GetFloat()

	-- Work with these local copies of the basis for the rest of the function
	local vDir   = vTarget - vOrigin
	local vRight = vecRight
	local vUp    = vecUp
	vDir:Normalize()
	--vRight:Normalize()
	--vUp:Normalize()

	-- Orthonormalize the basis, since the flashlight texture projection will require this later...
	vUp:Sub(vDir:Dot(vUp) * vDir)
	vUp:Normalize()
	vRight:Sub(vDir:Dot(vRight) * vDir)
	vRight:Normalize()
	vRight:Sub(vUp:Dot(vRight) * vUp)
	vRight:Normalize()

	local pmDirectionTrace = util.TraceHull({
		start = vOrigin,
		endpos = vTarget,
		mins = light_size_negative,
		maxs = light_size,
		mask = iMask,
		filter = traceFilter
	})

	local flDist = (pmDirectionTrace.HitPos - vOrigin):Length()
	if flDist < flDistCutoff then
		-- We have an intersection with our cutoff range
		-- Determine how far to pull back, then trace to see if we are clear
		local flPullBackDist = bPlayerOnLadder and r_flashlightladderdist:GetFloat() or flDistCutoff - flDist -- Fixed pull-back distance if on ladder
		m_flDistMod = Lerp(flDistDrag, m_flDistMod, flPullBackDist)

		if !bPlayerOnLadder then
			local pmBackTrace = util.TraceHull({
				start = vOrigin,
				endpos = vOrigin - vDir * (flPullBackDist - flEpsilon),
				mins = light_size_negative,
				maxs = light_size,
				mask = iMask,
				filter = traceFilter
			})

			if pmBackTrace.Hit then
				-- We have an intersection behind us as well, so limit our m_flDistMod
				local flMaxDist = (pmBackTrace.HitPos - vOrigin):Length() - flEpsilon
				if m_flDistMod > flMaxDist then
					m_flDistMod = flMaxDist
				end
			end
		end
	else
		m_flDistMod = Lerp(flDistDrag, m_flDistMod, 0.0)
	end
	vOrigin:Sub(vDir * m_flDistMod)

	state:SetPos(vOrigin)
	state:SetAngles(BasisToQuaternion(vDir, vRight, vUp))

	state:SetQuadraticAttenuation(r_flashlightquadratic:GetFloat())
	state:SetLinearAttenuation(r_flashlightlinear:GetFloat())
	state:SetFOV(r_flashlightfov:GetFloat())

	state:SetConstantAttenuation(r_flashlightconstant:GetFloat())
	state:SetColor(Color(255, 255, 255, r_flashlightambient:GetFloat() * 255))
	state:SetNearZ(r_flashlightnear:GetFloat() + m_flDistMod) -- Push near plane out so that we don't clip the world when the flashlight pulls back
	state:SetFarZ(r_flashlightfar:GetFloat())
	state:SetTexture("effects/flashlight001") -- m_FlashlightTexture
	state:SetTextureFrame(0)
	state:SetEnableShadows(false) -- r_flashlightdepthtexture.GetBool()
	--state:SetShadowDepthBias(0.001) -- mat_depthbias_shadowmap.GetFloat()
	--state:SetShadowSlopeScaleDepthBias(2) -- mat_slopescaledepthbias_shadowmap.GetFloat()

	state:SetNoCull(true)

	SeamlessPortals.m_flDistMod = m_flDistMod
	return state
end

return UpdateLightNew
