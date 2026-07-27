-- this is the rendering code for the portals. Rewritten on 7/25/2026

AddCSLuaFile()

if SERVER then return end

-- Skybox doesn't render when inside of the world, so we must manually draw it ourselves.
local sky_convar = GetConVar("sv_skyname")
local sky_name = nil
local sky_materials = {}
local sky_directions = {
	Vector(-1,  0,  0),
	Vector( 1,  0,  0),
	Vector( 0, -1,  0),
	Vector( 0,  1,  0),
	Vector( 0,  0, -1),
	Vector( 0,  0,  1),
}

local function update_sky()
	local new_sky_name = sky_convar:GetString()
	if sky_name == new_sky_name then return end
	sky_name = new_sky_name

	local prefix = "skybox/" .. sky_name
	sky_materials[1] = Material(prefix .. "rt")
	sky_materials[2] = Material(prefix .. "lf")
	sky_materials[3] = Material(prefix .. "bk")
	sky_materials[4] = Material(prefix .. "ft")
	sky_materials[5] = Material(prefix .. "up")
	sky_materials[6] = Material(prefix .. "dn")
end

update_sky()

-- draw the 2d skybox in place of the black (Thanks to Fafy2801 for the sky material reference)
local function draw_sky(eye_pos)
	for i, dir in ipairs(sky_directions) do
		render.SetMaterial(sky_materials[i])
		--render.SetMaterial(Material("models/props_combine/combine_interface_disp"))
		render.DrawQuadEasy(eye_pos - dir * 996, dir, 2000, 2000, color_white, i >= 5 and 0 or 180)
	end
end

hook.Add("PreDrawOpaqueRenderables", "seamless_portal_skybox", function()
	local eye_pos = EyePos()
	if util.IsSkyboxVisibleFromPoint(eye_pos) or !SeamlessPortals.Rendering then return end

	-- the "skybox" may get clipped
	local clip = render.EnableClipping(false)
	render.DepthRange(1, 2)
		draw_sky(eye_pos)
	render.DepthRange(0, 1)
	render.EnableClipping(clip)
end)

-- prevent portals from "snipping" the sky in half
local sky_clip = false
hook.Add("PreDrawSkyBox", "seamless_portal_skybox", function()
	if !SeamlessPortals.Rendering then return end

	sky_clip = render.EnableClipping(false)
end)

hook.Add("PostDrawSkyBox", "seamless_portal_skybox", function()
	if !SeamlessPortals.Rendering then return end

	render.EnableClipping(sky_clip)
end)

-- The implementation of halos sucks.
-- We must disable clipping so that the framebuffer doesn't become corrupted
-- we only do this during portal rendering, so it shouldnt affect other operations,
-- since the clip state gets set back after rendering
hook.Add("PreDrawEffects", "", function()
	if !SeamlessPortals.Rendering then return end

	render.EnableClipping(false)
end)

-- draw the player in renderview
hook.Add("ShouldDrawLocalPlayer", "seamless_portal_drawplayer", function()
	if SeamlessPortals.Rendering and SeamlessPortals.DrawPlayerInView then
		return true
	end
end)

local maxRender = CreateClientConVar("seamless_portal_maxrender", "6", true, false, "maximum number of portals to render per frame", 0)
local skipConvar = CreateClientConVar("seamless_portal_refreshrate", "1", false, false, "How many frames to skip when rendering portals", 1)
local skip = 0
local renderViewTable = {
	x = 0,
	y = 0,
	w = ScrW(),
	h = ScrH(),
	origin = Vector(),
	angles = Angle(),
	drawviewmodel = false,
	view = 2,
}

-- render portals closest to us
local portals = {}
timer.Create("seamless_portal_distance_fix", 0.5, 0, function()
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	portals = ents.FindByClass("seamless_portal")
	table.sort(portals, function(a, b)
		return a:GetPos():DistToSqr(EyePos()) < b:GetPos():DistToSqr(EyePos())
	end)

	update_sky()
end)

local framebuffer = GetRenderTarget("seamless_portals_framebuffer", ScrW(), ScrH())
local no_function = function() end
hook.Add("RenderScene", "seamless_portal_draw", function(eyePos, eyeAngles, fov)
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end

	skip = (skip + 1) % skipConvar:GetInt()
	if skip != 0 then return end

	render.PushRenderTarget(SeamlessPortals.PortalRT)
	render.Clear(0, 0, 0, 0, true, true)
	cam.Start3D(eyePos, eyeAngles, fov)

	local eye_forward = eyeAngles:Forward()
	local portal_render_max = maxRender:GetInt()
	local portals_rendered = 0
	for _, portal in ipairs(portals) do
		if !IsValid(portal) or !IsValid(portal:GetExitPortal()) then continue end

		if SeamlessPortals.ShouldRender(portal, eyePos, eyeAngles, SeamlessPortals.GetDrawDistance()) then
			local exitPortal = portal:GetExitPortal()
			local editedPos, editedAng = SeamlessPortals.TransformPortal(portal, exitPortal, eyePos, eyeAngles)

			renderViewTable.origin = editedPos
			renderViewTable.angles = editedAng
			renderViewTable.fov = fov

			-- znear
			-- we need to figure out where to place the near clipping plane
			-- ideally we need this as close as possible to the portal, for minimal artifacting
			-- you could use a hull plane intersection, but a sphere is easier to calculate
			local plane_pos = portal:GetPos()
			plane_pos:Sub(eye_forward * portal:BoundingRadius())
			plane_pos:Sub(eyePos)
			local t = eye_forward:Dot(plane_pos)
			renderViewTable.znear = math.max(t, 0.3) -- 0.3 = default znear (overridable w/ calcview)

			-- render the scene
			-- TODO: ideally we could "clip" the edges that we know are going to be discarded
			SeamlessPortals.Rendering = true
			local up = exitPortal:GetUp()
			render.PushRenderTarget(framebuffer)
			local oldClip = render.EnableClipping(true)
			render.PushCustomClipPlane(up, up:Dot(exitPortal:GetPos()))
			render.RenderView(renderViewTable)
			render.PopCustomClipPlane()
			render.EnableClipping(oldClip)
			render.PopRenderTarget()
			SeamlessPortals.Rendering = false

			-- Draw quad reversed if the portal is linked to itself
			portal:DrawStenciled(framebuffer, exitPortal == portal)

			portals_rendered = portals_rendered + 1
			if portals_rendered >= portal_render_max then
				break
			end
		end
	end

	cam.End3D()
	render.PopRenderTarget()
end)
