-- this is the rendering code for the portals, some references from: https://github.com/MattJeanes/world-portals

AddCSLuaFile()

if SERVER then return end

local sky_cvar = GetConVar("sv_skyname")
local sky_name = ""
local sky_materials = {}

local portals = {}
local oldHalo = 0
local haloChanged = false
local drawPlayerInView = false
local timesRendered = 0

local skysize = 16384	--2^14, default zfar limit
local angle_zero = Angle(0, 0, 0)
local COLOR_WHITE = Color(255, 255, 255)

local renderViewTable = {
	origin = Vector(),
	angles = Angle(),
	drawviewmodel = false,
	zfar = zfar,
}

-- sort the portals by distance since draw functions do not obey the z buffer
timer.Create("seamless_portal_distance_fix", 0.25, 0, function()
	portals = ents.FindByClass("seamless_portal")
	table.sort(portals, function(a, b) 
		return a:GetPos():DistToSqr(EyePos()) < b:GetPos():DistToSqr(EyePos())
	end)

	if SeamlessPortals.PortalIndex < 1 then		-- black halo fix
		if haloChanged then
			LocalPlayer():ConCommand("physgun_halo 1")	-- sorry animators, but we need to turn this back on
			LocalPlayer():ConCommand("effects_freeze 1")
			LocalPlayer():ConCommand("effects_unfreeze 1")
			haloChanged = false
		end
	else
		haloChanged = true
		LocalPlayer():ConCommand("physgun_halo 0")
		LocalPlayer():ConCommand("effects_freeze 0")
		LocalPlayer():ConCommand("effects_unfreeze 0")
	end

	-- update sky material (I guess it can change?)
	if sky_name != sky_cvar:GetString() then
		sky_name = sky_cvar:GetString()

		local prefix = "skybox/" .. sky_name
		sky_materials[1] = Material(prefix .. "bk")
		sky_materials[2] = Material(prefix .. "dn")
		sky_materials[3] = Material(prefix .. "ft")
		sky_materials[4] = Material(prefix .. "lf")
		sky_materials[5] = Material(prefix .. "rt")
		sky_materials[6] = Material(prefix .. "up")
	end
end)

-- update the rendertarget here since we cant do it in postdraw (cuz of infinite recursion)
hook.Add("RenderScene", "seamless_portals_draw", function(eyePos, eyeAngles)
	if !SeamlessPortals or SeamlessPortals.PortalIndex < 1 then return end
	drawPlayerInView = !SeamlessPortals.drawPlayerInView
	for k, v in ipairs(portals) do
		if !v:IsValid() or !v:ExitPortal():IsValid() then continue end
		if timesRendered < 6 and v.PORTAL_SHOULDRENDER == 1 then
			-- optimization checks
			if eyePos:DistToSqr(v:GetPos()) > 2500 * 2500 then continue end
			if (eyePos - v:GetPos()):Dot(v:GetUp()) < -10 then continue end

			local exitPortal = v:ExitPortal()
			local editedPos, editedAng = SeamlessPortals.TransformPortal(v, exitPortal, eyePos, Angle(eyeAngles[1], eyeAngles[2], eyeAngles[3]))

			renderViewTable.origin = editedPos
			renderViewTable.angles = editedAng

			-- render the scene
			local oldClip = render.EnableClipping(true)
			render.PushRenderTarget(v.PORTAL_RT)
			render.PushCustomClipPlane(exitPortal:GetUp(), exitPortal:GetUp():Dot(exitPortal:GetPos() + exitPortal:GetUp() * 0.1))
			render.RenderView(renderViewTable)
			render.PopCustomClipPlane()
			render.EnableClipping(oldClip)
			render.PopRenderTarget()

			timesRendered = timesRendered + 1
		end
		
		v.PORTAL_SHOULDRENDER = 0
	end

	drawPlayerInView = false
	SeamlessPortals.drawPlayerInView = false
	timesRendered = 0
end)

-- draw the player in renderview
hook.Add("ShouldDrawLocalPlayer", "seamless_portal_drawplayer", function()
	if drawPlayerInView then 
		return true 
	end
end)

-- draw the skybox
local drawsky = function(pos, ang, size, size_2, color, materials)
	-- BACK
	render.SetMaterial(materials[1])
	render.DrawQuadEasy(pos + Vector(0, size, 0), ang:Right(), size_2, size_2, color, 0)
	-- DOWN
	render.SetMaterial(materials[2])
	render.DrawQuadEasy(pos - Vector(0, 0, size), ang:Up(), size_2, size_2, color, 180)
	-- FRONT
	render.SetMaterial(materials[3])
	render.DrawQuadEasy(pos - Vector(0, size, 0), -ang:Right(), size_2, size_2, color, 0)
	-- LEFT
	render.SetMaterial(materials[4])
	render.DrawQuadEasy(pos - Vector(size, 0, 0), ang:Forward(), size_2, size_2, color, 0)
	-- RIGHT
	render.SetMaterial(materials[5])
	render.DrawQuadEasy(pos + Vector(size, 0, 0), -ang:Forward(), size_2, size_2, color, 0)
	-- UP
	render.SetMaterial(materials[6])
	render.DrawQuadEasy(pos + Vector(0, 0, size), -ang:Up(), size_2, size_2, color, 180)
end

hook.Add("PostDrawTranslucentRenderables", "seamless_portal_skybox", function()
	if !drawPlayerInView or util.IsSkyboxVisibleFromPoint(renderViewTable.origin) then return end

	render.OverrideDepthEnable(true, false) -- Fixes drawing over map
	drawsky(renderViewTable.origin, angle_zero, skysize, -skysize * 2, COLOR_WHITE, sky_materials)
	render.OverrideDepthEnable(false , false)
end)

print("-------------------------------------")
print("Successfully loaded Seamless Portals!")
print("Made by Mee, do not reupload!")
print("-------------------------------------")
