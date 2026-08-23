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

-- clear the framebuffer with the 2d skybox (Thanks to Fafy2801 for the sky material reference)
local function draw_sky(eye_pos)
	for i, dir in ipairs(sky_directions) do
		render.SetMaterial(sky_materials[i])
		--render.SetMaterial(Material("models/props_combine/combine_interface_disp"))
		render.DrawQuadEasy(eye_pos - dir * 996, dir, 2000, 2000, color_white, i >= 5 and 0 or 180)
	end
end

local function get_framebuffer(name)
	return GetRenderTargetEx(name, 1, 1,
	    RT_SIZE_FULL_FRAME_BUFFER,
	    MATERIAL_RT_DEPTH_SEPARATE,
	    4 + 8 + 256 + 512,
	    0,
	    IMAGE_FORMAT_RGBA8888
	)
end

-- TODO: ideally use pre-allocated framebuffers
SeamlessPortals.PortalRT = get_framebuffer("seamless_portals_backbuffer")
local framebuffer = get_framebuffer("seamless_portals_framebuffer")

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

-- Oh boy... VVIS with renderview.. my favorite problem
-- When the virtual camera is inside of a wall, it will cause problems with PVS
	-- unrendering the map... turning off the skybox... etc.
-- this sucks! it ruins immersion and causes horrendous flashing
-- what we can do is set the actual RenderView origin inside the map, so PVS gets set up correctly
	-- and then modify the camera location afterwords with a 3d cam. context
-- Unfortunately, source doesn't make this process easy and camera contexts can ONLY be set up at specific times in the renderer
-- But.. it is doable

local clip_pos = Vector()
local clip_up = Vector()
local clip_offset = Vector()
local num_cam_matrix = 0
local num_cam_3d = 0
local offset_matrix = Matrix()

local function push_cam(scale)
	cam.Start3D(EyePos() - clip_offset * scale, EyeAngles())
	num_cam_3d = num_cam_3d + 1
end

local function push_matrix(scale)
	offset_matrix:Identity()
	offset_matrix:SetTranslation(clip_offset * scale)
	cam.PushModelMatrix(offset_matrix)
	render.PushCustomClipPlane(clip_up, clip_up:Dot(clip_pos + clip_offset * scale))
	num_cam_matrix = num_cam_matrix + 1
end

local function pop_cams()
	for _ = 1, num_cam_3d do
		cam.End3D()
	end

	for _ = 1, num_cam_matrix do
		cam.PopModelMatrix()
		render.PopCustomClipPlane()
	end

	num_cam_3d = 0
	num_cam_matrix = 0
end

local skybox_info = nil
local skybox_rendered = false
hook.Add("PreDrawSkyBox", "seamless_portals_renderview", function()
	if !SeamlessPortals.Rendering then return end

	render.EnableClipping(false) -- disable clipping in the skybox
	skybox_info = skybox_info or game.Get3DSkyboxInfo()
	skybox_rendered = true
end)

hook.Add("PostDraw2DSkyBox", "seamless_portals_renderview", function()
	if !SeamlessPortals.Rendering or !skybox_info then return end

	if skybox_rendered then
		pop_cams()
		push_matrix(0)
		push_cam(1 / skybox_info.scale)
		skybox_rendered = false
	end
end)

hook.Add("PostDrawSkyBox", "seamless_portals_renderview", function()
	if !SeamlessPortals.Rendering then return end

	render.EnableClipping(true)
end)

hook.Add("PreDrawOpaqueRenderables", "seamless_portals_renderview", function(_, _, sky3d)
	if !SeamlessPortals.Rendering then return end

	pop_cams()
	push_matrix(0)
	if sky3d and skybox_info then
		push_cam(1 / skybox_info.scale)
	else
		push_cam(1)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "seamless_portals_renderview", function()
	if !SeamlessPortals.Rendering then return end

	pop_cams()
	push_matrix(1)
end)

-- The implementation of halos sucks.
-- We must disable clipping so that the framebuffer doesn't become corrupted
-- we only do this during portal rendering, so it shouldnt affect other operations,
-- since the clip state gets set back after rendering
hook.Add("PreDrawEffects", "seamless_portals_effects", function()
	if !SeamlessPortals.Rendering then return end

	render.EnableClipping(false)
end)

-- TODO: ideally we could "clip" the edges that we know are going to be discarded
local function render_scene()
	SeamlessPortals.Rendering = SeamlessPortals.Rendering or true

	local clip = render.EnableClipping(true)
	push_matrix(1)
	render.RenderView(renderview_table)
	pop_cams()
	render.EnableClipping(clip)
	SeamlessPortals.Rendering = false
end

hook.Add("RenderScene", "seamless_portals_draw", function(eye_pos, eye_ang, fov)
	if !SeamlessPortals or #SeamlessPortals.Portals < 1 then return end

	skip = (skip + 1) % skip_render:GetInt()
	if skip != 0 then return end

	cam.Start3D(eye_pos, eye_ang, fov)
	render.PushRenderTarget(SeamlessPortals.PortalRT)

	-- clear framebuffer (PortalRT) with 2d sky
	render.ClearDepth(true)
	draw_sky(eye_pos)

	local portal_render_max = max_render:GetInt()
	local portals_rendered = 0
	for _, portal in ipairs(SeamlessPortals.Portals) do
		if !IsValid(portal) then continue end

		local exit_portal = portal:GetExitPortal()
		if !IsValid(exit_portal) then continue end

		if SeamlessPortals.ShouldRender(portal, eye_pos, eye_ang, SeamlessPortals.GetDrawDistance()) then
			local new_pos, new_ang = SeamlessPortals.TransformPortal(portal, exit_portal, eye_pos, eye_ang)
			clip_up:Set(exit_portal:GetUp())

			-- figure out where virtual camera VVIS should be set up. This is clamped within portal bounds
			local exit_portal_size = exit_portal:GetSize() exit_portal_size:Mul(1 / 2)
			local exit_portal_pos = exit_portal:GetPos()
			local exit_portal_forward = exit_portal:GetForward()
			local exit_portal_right = exit_portal:GetRight()
			local new_pos_delta = new_pos - exit_portal_pos
			local exit_portal_forward_length = math.Clamp(new_pos_delta:Dot(exit_portal_forward), -(exit_portal_size[1]), exit_portal_size[1])
			local exit_portal_right_length = math.Clamp(new_pos_delta:Dot(exit_portal_right), -(exit_portal_size[2]), exit_portal_size[2])
			clip_pos:Set(exit_portal_pos)
			exit_portal_forward:Mul(exit_portal_forward_length)
			exit_portal_right:Mul(exit_portal_right_length)
			clip_pos:Add(exit_portal_forward)
			clip_pos:Add(exit_portal_right)
			clip_pos:Sub(clip_up * 0.1)
			clip_offset:Set(clip_pos)
			clip_offset:Sub(new_pos)
			--debugoverlay.Sphere(clip_pos, 10, 0.05)

			renderview_table.origin:Set(clip_pos)
			renderview_table.angles:Set(new_ang)
			renderview_table.fov = fov
			renderview_table.drawviewer = SeamlessPortals.DrawPlayerInView

			render.PushRenderTarget(framebuffer)
			SeamlessPortals.Rendering = exit_portal
			render_scene()
			render.PopRenderTarget()

			-- Draw quad reversed if the portal is linked to itself
			portal:DrawStenciled(framebuffer, portal == exit_portal, 1.01)

			portals_rendered = portals_rendered + 1
			if portals_rendered >= portal_render_max then
				break
			end
		end
	end

	render.PopRenderTarget()
	cam.End3D()
end)
