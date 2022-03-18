-- Create global table. Index the global table
SeamlessPortals = SeamlessPortals or {}
-- Server tells all clients what value must be used
SeamlessPortals.FlagVarSC = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_PRINTABLEONLY, FCVAR_REPLICATED)
-- Server and all the clients use separate indipendent values
SeamlessPortals.FlagVarIV = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_PRINTABLEONLY)
-- Store material here so it can be used in other files
SeamlessPortals.PortalDrawMat = Material("models/props_combine/combine_interface_disp")
SeamlessPortals.BeamMaterHUD  = Material("cable/blue_elec")
-- Put dedicated convears here
SeamlessPortals.VarDrawDistance = CreateConVar("seamless_portal_drwdist", 2500, SeamlessPortals.FlagVarSC, "Ditance margin for portlas being drawn", 0, 5000)
-- For hotreloading
SeamlessPortals.PortalIndex = #ents.FindByClass("seamless_portal")
SeamlessPortals.MaxRTs = 6
-- For seamless check
SeamlessPortals.SeamlessClass =
{
	["player"]          = true,
	["seamless_portal"] = true
}

function SeamlessPortals.IncrementPortal(ent)
	if CLIENT then
		local bounding1, bounding2 = ent:GetRenderBounds()
		-- For some reason this fixes a black flash when going backwards through a portal
		ent:SetRenderBounds(bounding1 * 1024, bounding2 * 1024)
		if ent.UpdatePhysmesh then
			ent:UpdatePhysmesh()
		else
			-- Takes a minute to try and find the portal, if it cant, oh well...
			timer.Create("seamless_portal_init" .. SeamlessPortals.PortalIndex, 1, 60, function()
				if !ent or !ent:IsValid() or !ent.UpdatePhysmesh then return end

				ent:UpdatePhysmesh()
				timer.Remove("seamless_portal_init" .. SeamlessPortals.PortalIndex)
			end)
		end
	end
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
end

function SeamlessPortals.DrawQuadEasier(ent, multiplier, offset, rotate)
	local ex, ey = ent:GetForward(), ent:GetRight()
  local ez, ep = ent:GetUp(), ent:GetPos()
	local rotate = (tonumber(rotate) or 0)
	local mx = ey * multiplier.x
	local my = ex * multiplier.y
	local mz = ez * multiplier.z
	local ox = ey * offset.x -- Currently zero
	local oy = ex * offset.y -- Currently zero
	local oz = ez * offset.z

	local pos = ep + ox + oy + oz
	if rotate == 0 then
		render.DrawQuad(
			pos + mx - my + mz,
			pos - mx - my + mz,
			pos - mx + my + mz,
			pos + mx + my + mz
		)
	elseif rotate == 1 then
		render.DrawQuad(
			pos + mx + my - mz,
			pos - mx + my - mz,
			pos - mx + my + mz,
			pos + mx + my + mz
		)
	elseif rotate == 2 then
		render.DrawQuad(
			pos + mx - my + mz,
			pos + mx - my - mz,
			pos + mx + my - mz,
			pos + mx + my + mz
		)
	else
		print("Failed processing rotation:", tostring(rotate))
	end
end

function SeamlessPortals.TransformPortal(a, b, pos, ang)
	local ePos, eAng = Vector(), Angle()
	if !a or !b or !b:IsValid() or !a:IsValid() then return ePos, eAng end

	if pos then -- Use data copy instead of assign target
		ePos:Set(a:WorldToLocal(pos))
		ePos:Mul(b:GetExitSize()[1] / a:GetExitSize()[1])
		ePos:Set(b:LocalToWorld(Vector(ePos[1], -ePos[2], -ePos[3])))
		ePos:Add(b:GetUp()) -- Reduces vector object creation. Keep reference
	end

	if ang then -- Rotatearoundaxis modifies original variable
		local cAng = Angle(ang[1], ang[2], ang[3])
		cAng:RotateAroundAxis(a:GetForward(), 180)
		eAng:Set(b:LocalToWorldAngles(a:WorldToLocalAngles(cAng)))
	end

	return ePos, eAng
end

--[[
 * Calculate surface normal angle by using cross products
 * owner > The player that does the trace
 * norm  > The trace hit surface normal vector
 * Returns the angle tangent to the surface hit position
]]
function SeamlessPortals.GetSurfaceAngle(owner, norm)
	local fwd = owner:GetAimVector()
	local rgh = fwd:Cross(norm); fwd:Set(norm:Cross(rgh))
	return fwd:AngleEx(norm)
end

function SeamlessPortals.SeamlessCheck(ent)
	if(!IsValid(ent)) then return end
	return !SeamlessPortals.SeamlessClass[ent:GetClass()]
end

function SeamlessPortals.UpdateAngle(owner, tr, ang)
  local ang = ang or Angle()

	-- Align portals on 45 degree surfaces
	if math.abs(tr.HitNormal:Dot(ang:Up())) < 0.71 then
		ang:Set(tr.HitNormal:Angle())
		ang:RotateAroundAxis(ang:Right(), -90)
		ang:RotateAroundAxis(ang:Up(), 180)
	else -- Place portals on any surface and angle
		ang:Set(SeamlessPortals.GetSurfaceAngle(owner, tr.HitNormal))
	end

  return ang
end

function SeamlessPortals.SetPortalPlacement(owner, portal, tr, ang)
	local pos, tr = owner:GetShootPos(), tr
	local aim = owner:GetAimVector()
	local mul = 10 * portal:GetExitSize()[3]

  if !tr then -- No base trace result
    tr = util.TraceLine({
      start = pos,
      endpos = pos + aim * 99999,
      filter = SeamlessPortals.SeamlessCheck,
      noDetour = true,
    }) -- Do a trace when not provided
  end
  -- The portal angle created or updated
  local ang = SeamlessPortals.UpdateAngle(owner, tr, ang)
  -- Adjust the portal position and angles
	portal:SetPos((tr.HitPos + mul * tr.HitNormal))
	portal:SetAngles(ang)
  -- Register to CPPI
	if CPPI then portal:CPPISetOwner(owner) end
end

--[[
 * Until PR: https://github.com/Mee12345/GMod-Seamless-Portals/pull/36
 * Keep the implementation when it becomes handy sometimes
 * And the user can easily call VEC1:AngleBetween(VEC2)
]]
function SeamlessPortals.VectorAngle(vec1, vec2)
	local coth = vec1:Dot(vec2) / (vec1:Length() * vec2:Length())
	return math.deg(math.acos(coth))
end
