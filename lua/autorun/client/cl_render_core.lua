-- this is the rendering code for the portals, some references from: https://github.com/MattJeanes/world-portals

AddCSLuaFile()

if SERVER then return end

local portals = {}
local renderViewTable = {
	origin = Vector(),
	angles = Angle(),
	drawviewmodel = false,
	zfar = zfar,
}

-- sort the portals by distance since draw functions do not obey the z buffer
local haloChanged = false
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
end)

-- update the rendertarget here since we cant do it in postdraw (cuz of infinite recursion)
local oldHalo = 0
local drawPlayerInView = false
local timesRendered = 0
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

print("-------------------------------------")
print("Successfully loaded Seamless Portals!")
print("Made by Mee, do not reupload!")
print("-------------------------------------")
