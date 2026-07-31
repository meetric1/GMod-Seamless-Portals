-- this is the rendering code for the portals. Rewritten on 7/25/2026

AddCSLuaFile()

if SERVER then return end

local max_render = CreateClientConVar("seamless_portals_maxrender", "6", true, false, "maximum number of portals to render per frame", 0)
local skip_render = CreateClientConVar("seamless_portals_refreshrate", "1", false, false, "How many frames to skip when rendering portals", 1)
local skip = 0
local renderview_table = {
	x = 0,
	y = 0,
	w = ScrW(),
	h = ScrH(),
	origin = Vector(),
	angles = Angle(),
	drawviewmodel = false,
	viewid = 2
}

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
		render.DrawQuadEasy(eye_pos - dir * 9960, dir, 20000, 20000, color_white, i >= 5 and 0 or 180)
	end
end

-- The implementation of halos sucks.
-- We must disable clipping so that the framebuffer doesn't become corrupted
-- we only do this during portal rendering, so it shouldnt affect other operations,
-- since the clip state gets set back after rendering
hook.Add("PreDrawEffects", "seamless_portals_effects", function()
	if !SeamlessPortals.Rendering then return end

	render.EnableClipping(false)
end)

-- same for skybox, ensure clipping is disabled
local skybox_framebuffer = GetRenderTarget("seamless_portals_skybox_framebuffer", ScrW(), ScrH())
local skybox_3dsky = GetConVar("r_3dsky")
local skybox_clip = false
local skybox_rendered = false
hook.Add("PreDrawSkyBox", "seamless_portals_skybox", function()
	if !SeamlessPortals.Rendering then return end
	if renderview_table.viewid == 1 then return true end

	skybox_clip = render.EnableClipping(false)
end)

hook.Add("PostDrawSkyBox", "seamless_portals_skybox", function()
	if !SeamlessPortals.Rendering then return end

	render.EnableClipping(skybox_clip)
	skybox_rendered = true
end)

-- TODO: if we ever get the option to render the scene without clearing the framebuffer, we can avoid a lot of this logic
-- this hook is for if the skybox camera manages to be inside the world
-- setupworldfog is a nice hook to use, since its only called once right after the skybox is drawn
hook.Add("PreDrawOpaqueRenderables", "seamless_portals_skybox", function()
	if !SeamlessPortals.Rendering then return end
	if renderview_table.viewid != 1 then return end

	local clip = render.EnableClipping(false)
	render.DepthRange(1, 1)
	draw_sky(EyePos())
	render.DepthRange(0, 1)
	render.EnableClipping(clip)
end)

-- TODO: wow, this sucks!
local function draw_texture_to_screen_unfucked(texture, eye_pos)
	local clip = render.EnableClipping(false)
	render.ClearStencil()
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilEnable(true)
	render.OverrideDepthEnable(true, false)
	render.DepthRange(1, 1)
	draw_sky(eye_pos)
	render.DepthRange(0, 1)
	render.OverrideDepthEnable(false, false)
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.DrawTextureToScreen(texture)
	render.SetStencilEnable(false)
	render.EnableClipping(clip)
end

-- draw the player in renderview
hook.Add("ShouldDrawLocalPlayer", "seamless_portal_drawplayer", function()
	if SeamlessPortals.Rendering and SeamlessPortals.DrawPlayerInView then
		return true
	end
end)

timer.Create("seamless_portal_distance_fix", 0.5, 0, function()
	local eye_pos = MainEyePos()
	table.sort(SeamlessPortals.Portals, function(a, b)
		local a_distance = a:GetPos():DistToSqr(eye_pos)
		local a_exit = a:GetExitPortal()
		if IsValid(a_exit) then
			a_distance = math.min(a_distance, a_exit:GetPos():DistToSqr(eye_pos))
		end

		local b_distance = b:GetPos():DistToSqr(eye_pos)
		local b_exit = b:GetExitPortal()
		if IsValid(b_exit) then
			b_distance = math.min(b_distance, b_exit:GetPos():DistToSqr(eye_pos))
		end

		return a_distance < b_distance
	end)

	update_sky()
end)

-- TODO: ideally we could "clip" the edges that we know are going to be discarded
local function render_scene(clip_pos, clip_up)
	SeamlessPortals.Rendering = true
	local clip = render.EnableClipping(true)
	render.PushCustomClipPlane(clip_up, clip_up:Dot(clip_pos))
	render.RenderView(renderview_table)
	render.PopCustomClipPlane()
	render.EnableClipping(clip)
	SeamlessPortals.Rendering = false
end

-- TODO: ideally use a pre-allocated framebuffer
local framebuffer = GetRenderTarget("seamless_portals_framebuffer", ScrW(), ScrH())
hook.Add("RenderScene", "seamless_portals_draw", function(eye_pos, eye_ang, fov)
	if !SeamlessPortals or #SeamlessPortals.Portals < 1 then return end

	skip = (skip + 1) % skip_render:GetInt()
	if skip != 0 then return end

	cam.Start3D(eye_pos, eye_ang, fov)
	render.PushRenderTarget(SeamlessPortals.PortalRT)

	-- clear framebuffer (PortalRT) with 2d sky
	render.ClearDepth(true)
	draw_sky(eye_pos)

	local eye_forward = eye_ang:Forward()
	local portal_render_max = max_render:GetInt()
	local portals_rendered = 0
	for _, portal in ipairs(SeamlessPortals.Portals) do
		if !IsValid(portal) then continue end

		local exit_portal = portal:GetExitPortal()
		if !IsValid(exit_portal) then continue end

		if SeamlessPortals.ShouldRender(portal, eye_pos, eye_ang, SeamlessPortals.GetDrawDistance()) then
			local new_pos, new_ang = SeamlessPortals.TransformPortal(portal, exit_portal, eye_pos, eye_ang)
			local clip_pos = exit_portal:GetPos()
			local clip_up = exit_portal:GetUp()

			renderview_table.angles:Set(new_ang)
			renderview_table.fov = fov
			renderview_table.znear = 3
			renderview_table.origin:Set(new_pos)
			renderview_table.viewid = 2

			-- znear
			-- we need to figure out where to place the near clipping plane
			-- ideally we need this as close as possible to the portal, for minimal artifacting
			-- you could use a hull plane intersection, but a sphere is easier to calculate
			local plane_pos = portal:GetPos()
			plane_pos:Sub(eye_forward * portal:BoundingRadius())
			plane_pos:Sub(eye_pos)
			local t = eye_forward:Dot(plane_pos)
			t = t * (exit_portal:GetSize()[1] / portal:GetSize()[1])
			renderview_table.znear = math.max(t, 3) -- 3 = default znear

			render.PushRenderTarget(framebuffer)
			skybox_rendered = false
			render_scene(clip_pos, clip_up)
			render.PopRenderTarget()

			if !skybox_rendered and util.IsSkyboxVisibleFromPoint(clip_pos) then
				local skybox_info = game.Get3DSkyboxInfo()
				render.PushRenderTarget(skybox_framebuffer)
				render.Clear(0, 0, 0, 255, true, true)
				if skybox_info and skybox_3dsky:GetBool() then
					renderview_table.origin:Set(new_pos)
					renderview_table.origin:Div(skybox_info.scale)
					renderview_table.origin:Add(skybox_info.origin)
					renderview_table.viewid = 1

					local clip_pos = Vector(clip_pos)
					clip_pos:Div(skybox_info.scale)
					clip_pos:Add(skybox_info.origin)

					--print("RENDERING SKYBOX", new_pos)
					render_scene(clip_pos, clip_up)
				else
					cam.Start3D(new_pos, new_ang)
					draw_sky(new_pos)
					cam.End3D()
				end
				render.PopRenderTarget()

				render.PushRenderTarget(framebuffer)
				draw_texture_to_screen_unfucked(skybox_framebuffer, new_pos)
				render.PopRenderTarget()
			end

			-- Draw quad reversed if the portal is linked to itself
			portal:DrawStenciled(framebuffer, portal == exit_portal)

			portals_rendered = portals_rendered + 1
			if portals_rendered >= portal_render_max then
				break
			end
		end
	end

	render.PopRenderTarget()
	cam.End3D()
end)
