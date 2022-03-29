-- Seamless portals addon by Mee
-- You may use this code as a reference for your own projects, but please do not publish this addon as your own.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category     = "Seamless Portals"
ENT.PrintName    = "Seamless Portal"
ENT.Author       = "Mee"
ENT.Purpose      = ""
ENT.Instructions = ""
ENT.Spawnable    = true


local gbSvFlag = bit.bor(FCVAR_ARCHIVE)
-- create global table
SeamlessPortals = SeamlessPortals or {}
SeamlessPortals.VarDrawDistance = CreateClientConVar("seamless_portal_drawdistance", "2500", true, false, "Sets the size of the portal along the Y axis", 0)

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "PortalExit")
	self:NetworkVar("Vector", 0, "PortalScale")
	self:NetworkVar("Bool", 0, "DisableBackface")
end

-- get exit portal
function ENT:ExitPortal()
	if CLIENT then
		return self:GetPortalExit()
	end
	return self.PORTAL_EXIT
end

function ENT:LinkPortal(ent)
	if !ent or !ent:IsValid() then return end
	self.PORTAL_EXIT = ent
	ent.PORTAL_EXIT = self
	self:SetPortalExit(ent)
	ent:SetPortalExit(self)
end

-- custom size for portal
function ENT:SetExitSize(n)
	self.PORTAL_SCALE = n
	self:SetPortalScale(n)
	self:UpdatePhysmesh(n)
end

function ENT:GetExitSize()
	if CLIENT then
		return self:GetPortalScale()
	end
	return self.PORTAL_SCALE
end

local function incrementPortal(ent)
	if CLIENT then
		if ent.UpdatePhysmesh then
			ent:UpdatePhysmesh()
		else
			-- takes a minute to try and find the portal, if it cant, oh well...
			timer.Create("seamless_portal_init" .. SeamlessPortals.PortalIndex, 1, 60, function()
				if !ent or !ent:IsValid() or !ent.UpdatePhysmesh then return end

				ent:UpdatePhysmesh()
				timer.Remove("seamless_portal_init" .. SeamlessPortals.PortalIndex)
			end)
		end
	end
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
end

function ENT:Initialize()
	if CLIENT then
		incrementPortal(self)
	else
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetMaterial("debug/debugempty")	-- missing texture
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)
		self:SetExitSize(Vector(1, 1, 1))
		SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex + 1
	end
end

function ENT:SpawnFunction(ply, tr)
	local portal1 = ents.Create("seamless_portal")
	portal1:SetPos(tr.HitPos + tr.HitNormal * 150)
	portal1:Spawn()

	local portal2 = ents.Create("seamless_portal")
	portal2:SetPos(tr.HitPos + tr.HitNormal * 50)
	portal2:Spawn()

	if CPPI then portal2:CPPISetOwner(ply) end

	portal1:LinkPortal(portal2)
	portal2:LinkPortal(portal1)
	portal1.PORTAL_REMOVE_EXIT = true
	portal2.PORTAL_REMOVE_EXIT = true

	return portal1
end

function ENT:OnRemove()
	SeamlessPortals.PortalIndex = SeamlessPortals.PortalIndex - 1
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:ExitPortal())
	end
end

local function DrawQuadEasier(e, multiplier, offset, rotate)
	local ex, ey, ez = e:GetForward(), e:GetRight(), e:GetUp()
	local rotate = (tonumber(rotate) or 0)
	local mx = ey * multiplier.x
	local my = ex * multiplier.y
	local mz = ez * multiplier.z
	local ox = ey * offset.x -- currently zero
	local oy = ex * offset.y -- currently zero
	local oz = ez * offset.z

	local pos = e:GetPos() + ox + oy + oz
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

local drawMat = Material("models/props_combine/combine_interface_disp")
function ENT:Draw()
	local exsize = self:GetExitSize()
	local backAmt = 3 * exsize[3]
	local backVec = Vector(0, 0, -backAmt)
	local epos, spos, vup = EyePos(), self:GetPos(), self:GetUp()
	local scalex = (self:OBBMaxs().x - self:OBBMins().x) * 0.5 - 0.1
	local scaley = (self:OBBMaxs().y - self:OBBMins().y) * 0.5 - 0.1

	-- optimization checks
	local exitInvalid = !self:ExitPortal() or !self:ExitPortal():IsValid()
	local shouldRenderPortal = false
	if !SeamlessPortals.Rendering and !exitInvalid then
		local margnPortal = SeamlessPortals.VarDrawDistance:GetFloat()^2
		local behindPortal = (epos - spos):Dot(vup) < (-10 * exsize[1]) -- true if behind the portal, false otherwise
		local distPortal = epos:DistToSqr(spos) > (margnPortal * exsize[1]) -- too far away

		shouldRenderPortal = behindPortal or distPortal
	end

	self.PORTAL_SHOULDRENDER = !shouldRenderPortal

	render.SetMaterial(drawMat)

	-- holy shit lol this if statment
	if SeamlessPortals.Rendering or exitInvalid or shouldRenderPortal or halo.RenderedEntity() == self then
		if !self:GetDisableBackface() then
			render.DrawBox(spos, self:LocalToWorldAngles(Angle(0, 90, 0)), Vector(-scaley, -scalex, -backAmt * 2), Vector(scaley, scalex, 0))
		end
		return
	end

	-- outer quads
	if !self:GetDisableBackface() then
		DrawQuadEasier(self, Vector( scaley, -scalex, -backAmt), backVec)
		DrawQuadEasier(self, Vector( scaley, -scalex,  backAmt), backVec, 1)
		DrawQuadEasier(self, Vector( scaley,  scalex, -backAmt), backVec, 1)
		DrawQuadEasier(self, Vector( scaley, -scalex,  backAmt), backVec, 2)
		DrawQuadEasier(self, Vector(-scaley, -scalex, -backAmt), backVec, 2)
	end

	-- do cursed stencil stuff
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(1)
	render.SetStencilTestMask(1)
	render.SetStencilReferenceValue(1)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)

	-- draw the quad that the 2d texture will be drawn on
	-- teleporting causes flashing if the quad is drawn right next to the player, so we offset it
	DrawQuadEasier(self, Vector( scaley,  scalex, -backAmt), backVec)
	DrawQuadEasier(self, Vector( scaley,  scalex,  backAmt), backVec, 1)
	DrawQuadEasier(self, Vector( scaley, -scalex, -backAmt), backVec, 1)
	DrawQuadEasier(self, Vector( scaley,  scalex,  backAmt), backVec, 2)
	DrawQuadEasier(self, Vector(-scaley,  scalex, -backAmt), backVec, 2)

	-- draw the actual portal texture
	render.SetMaterial(SeamlessPortals.PortalMaterials[self.PORTAL_RT_NUMBER or 1])
	render.SetStencilCompareFunction(STENCIL_EQUAL)

	-- draw quad reversed if the portal is linked to itself
	if self.ExitPortal and self:ExitPortal() == self then
		render.DrawScreenQuadEx(ScrW(), 0, -ScrW(), ScrH())
	else
		render.DrawScreenQuad()
	end

	render.SetStencilEnable(false)
end

-- scale the physmesh
function ENT:UpdatePhysmesh()
	self:PhysicsInit(6)
	if self:GetPhysicsObject():IsValid() then
		local finalMesh = {}
		for k, tri in pairs(self:GetPhysicsObject():GetMeshConvexes()[1]) do
			tri.pos = tri.pos * self:GetExitSize()
			table.insert(finalMesh, tri.pos)
		end
		self:PhysicsInitConvex(finalMesh)
		self:EnableCustomCollisions(true)
		self:GetPhysicsObject():EnableMotion(false)
		self:GetPhysicsObject():SetMaterial("glass")
		self:GetPhysicsObject():SetMass(250)

		if CLIENT then 
			local mins, maxs = self:GetModelBounds()
			self:SetRenderBounds(mins * self:GetExitSize(), maxs * self:GetExitSize())
		end
	else
		self:PhysicsDestroy()
		self:EnableCustomCollisions(false)
		print("Failure to create a portal physics mesh " .. self:EntIndex())
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

SeamlessPortals.PortalIndex = 0 --#ents.FindByClass("seamless_portal")
SeamlessPortals.MaxRTs = 6
SeamlessPortals.TransformPortal = function(a, b, pos, ang)
	if !a or !b or !b:IsValid() or !a:IsValid() then return Vector(), Angle() end
	local editedPos = Vector()
	local editedAng = Angle()

	if pos then
		editedPos = a:WorldToLocal(pos) * (b:GetExitSize()[1] / a:GetExitSize()[1])
		editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
		editedPos = editedPos + b:GetUp()
	end

	if ang then
		local localAng = a:WorldToLocalAngles(ang)
		editedAng = b:LocalToWorldAngles(Angle(-localAng[1], -localAng[2], localAng[3] + 180))

		if a == b then
			if pos then editedPos = a:LocalToWorld(a:WorldToLocal(pos) * Vector(1, 1, -1)) end
			local localAng = a:WorldToLocalAngles(ang)
			editedAng = a:LocalToWorldAngles(Angle(-localAng[1], localAng[2], -localAng[3] + 180))
		end
	end

	return editedPos, editedAng
end

-- set physmesh pos on client
if CLIENT then
	function ENT:Think()
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:EnableMotion(false)
			phys:SetMaterial("glass")
			phys:SetPos(self:GetPos())
			phys:SetAngles(self:GetAngles())
		end
	end

	hook.Add("InitPostEntity", "seamless_portal_init", function()
		for k, v in ipairs(ents.FindByClass("seamless_portal")) do
			print("Initializing portal " .. v:EntIndex())
			incrementPortal(v)
		end

		-- this code creates the rendertargets to be used for the portals
		SeamlessPortals.PortalRTs = {}
		SeamlessPortals.PortalMaterials = {}

		for i = 1, SeamlessPortals.MaxRTs do
			SeamlessPortals.PortalRTs[i] = GetRenderTarget("SeamlessPortal" .. i, ScrW(), ScrH())
			SeamlessPortals.PortalMaterials[i] = CreateMaterial("SeamlessPortalsMaterial" .. i, "GMODScreenspace", {
				["$basetexture"] = SeamlessPortals.PortalRTs[i]:GetName(),
				["$model"] = "1"
			})
		end
	end)

	--funny flipped scene
	local rendering = false
	local cursedRT = GetRenderTarget("Portal_Flipscene", ScrW(), ScrH())
	local cursedMat = CreateMaterial("Portal_Flipscene", "GMODScreenspace", {
		["$basetexture"] = cursedRT:GetName(),
	})

	local mirrored = false
	function SeamlessPortals.ToggleMirror(enable)
		if enable then
			hook.Add("PreRender", "portal_flip_scene", function()
				rendering = true
				render.PushRenderTarget(cursedRT)
				render.RenderView({drawviewmodel = false})
				render.PopRenderTarget()
				rendering = false
			end)

			hook.Add("PostDrawTranslucentRenderables", "portal_flip_scene", function(_, sky, sky3d)
				if rendering or SeamlessPortals.Rendering then return end
				render.SetMaterial(cursedMat)
				render.DrawScreenQuadEx(ScrW(), 0, -ScrW(), ScrH())

				if LocalPlayer():Health() <= 0 then
					SeamlessPortals.ToggleMirror(false)
				end
			end)

			-- invert mouse x
			hook.Add("InputMouseApply", "portal_flip_scene", function(cmd, x, y, ang)
				if LocalPlayer():WaterLevel() < 3 then
					cmd:SetViewAngles(ang + Angle(0, x / 22.5, 0))
				end
			end)

			-- invert movement x
			hook.Add("CreateMove", "portal_flip_scene", function(cmd)
				if LocalPlayer():WaterLevel() < 3 then
					cmd:SetSideMove(-cmd:GetSideMove())
				end
			end)

			mirrored = true
		elseif enable == false then
			hook.Remove("PreRender", "portal_flip_scene")
			hook.Remove("PostDrawTranslucentRenderables", "portal_flip_scene")
			hook.Remove("InputMouseApply", "portal_flip_scene")
			hook.Remove("CreateMove", "portal_flip_scene")

			mirrored = false
		end

		return mirrored
	end

	SeamlessPortals.ToggleMirror(false)
end
