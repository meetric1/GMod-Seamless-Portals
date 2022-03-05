 
if (engine.ActiveGamemode() ~= "sandbox") then return end
if (SERVER) then util.AddNetworkString("seamless_portal_spawn") end
cleanup.Register("Seamless Portals")

local entries = {
	{
		["name"] = "2 x 1 x 1 Portals",
		["spawn"] = function(ply, tr)
			local fwd = (ply:GetPos() - tr.HitPos)

			local ang = fwd:Angle()

			local portal1 = ents.Create("seamless_portal")
			portal1:SetPos(tr.HitPos + tr.HitNormal * 150)
			portal1:SetAngles(ang)
			portal1:Spawn()

			local portal2 = ents.Create("seamless_portal")
			portal2:SetPos(tr.HitPos + tr.HitNormal * 50)
			portal2:SetAngles(ang)
			portal2:Spawn()

			if CPPI then portal2:CPPISetOwner(ply) end

			portal1:LinkPortal(portal2)
			
			return portal1
		end,
		["adminOnly"] = false,
		["icon"] = "entities/seamless_portal/icon1.png"
	},
	{
		["name"] = "2 x 0.5 x 1 Portals",
		["spawn"] = function(ply, tr)
			local fwd = (ply:GetPos() - tr.HitPos)
			fwd.z = 0

			local ang = fwd:Angle()
			local rightAng = Angle(ang.p, ang.y, ang.r)
			rightAng:RotateAroundAxis(tr.HitNormal, 90)

			local root = tr.HitPos + tr.HitNormal * 50
			local right = rightAng:Forward() * 25
			local portal1 = ents.Create("seamless_portal")
			portal1:SetPos(root + right)
			portal1:SetAngles(ang)
			portal1:Spawn()
			portal1:SetExitSize(Vector(1, 0.5, 0.5))

			local portal2 = ents.Create("seamless_portal")
			portal2:SetPos(root - right)
			portal2:SetAngles(ang)
			portal2:Spawn()
			portal2:SetExitSize(Vector(1, 0.5, 0.5))

			if CPPI then portal2:CPPISetOwner(ply) end

			portal1:LinkPortal(portal2)
			
			return portal1
		end,
		["adminOnly"] = false,
		["icon"] = "entities/seamless_portal/icon2.png"
	},
	{
		["name"] = "2 x 2 x 2 Portals",
		["spawn"] = function(ply, tr)
			local fwd = (ply:GetPos() - tr.HitPos)
			fwd.z = 0

			local ang = fwd:Angle()

			local portal1 = ents.Create("seamless_portal")
			portal1:SetPos(tr.HitPos + tr.HitNormal * 300)
			portal1:SetAngles(ang)
			portal1:Spawn()
			portal1:SetExitSize(Vector(2, 2, 2))

			local portal2 = ents.Create("seamless_portal")
			portal2:SetPos(tr.HitPos + tr.HitNormal * 100)
			portal2:SetAngles(ang)
			portal2:Spawn()
			portal2:SetExitSize(Vector(2, 2, 2))

			if CPPI then portal2:CPPISetOwner(ply) end

			portal1:LinkPortal(portal2)
			
			return portal1
		end,
		["adminOnly"] = false,
		["icon"] = "entities/seamless_portal/icon3.png"
	},
	{
		["name"] = "2 x 0.5 x 0.5 Portals",
		["spawn"] = function(ply, tr)
			local fwd = (ply:GetPos() - tr.HitPos)
			fwd.z = 0

			local ang = fwd:Angle()

			local portal1 = ents.Create("seamless_portal")
			portal1:SetPos(tr.HitPos + tr.HitNormal * 75)
			portal1:SetAngles(ang)
			portal1:Spawn()
			portal1:SetExitSize(Vector(0.5, 0.5, 0.5))

			local portal2 = ents.Create("seamless_portal")
			portal2:SetPos(tr.HitPos + tr.HitNormal * 25)
			portal2:SetAngles(ang)
			portal2:Spawn()
			portal2:SetExitSize(Vector(0.5, 0.5, 0.5))

			if CPPI then portal2:CPPISetOwner(ply) end

			portal1:LinkPortal(portal2)
			
			return portal1
		end,
		["adminOnly"] = false,
		["icon"] = "entities/seamless_portal/icon4.png"
	}
}

-- Gigabrain tiny optimization
-- Won't work if all of the entries aren't loaded before this point
local msgBits = 3
if (#entries > 3) then
	-- Maximum value V for N bits is V = 2^(N - 1) - 1
	-- So the inverse function is N = log(V + 1) / log(2) + 1
	msgBits = math.ceil(math.log10((#entries) + 1) / math.log10(2) + 1)
end

if (SERVER) then

	net.Receive("seamless_portal_spawn", function(len, ply)
		local key = net.ReadInt(msgBits)
		local entry = entries[key]
		if (entry["adminOnly"] and (not ply:IsAdmin())) then return end
		local canSpawn = hook.Run("PlayerSpawnSENT", ply, "seamless_portal")
		if not canSpawn then return end
		local spawnFunc = entry["spawn"]
		if (isfunction(spawnFunc)) then
			local ent = spawnFunc(ply, ply:GetEyeTrace())
			if IsValid(ent) then
				cleanup.Add(ply, "Seamless Portals", ent)
				hook.Run("PlayerSpawnedSENT", ply, ent)
			end
		end
	end )

elseif (CLIENT) then

	-- WasabiThumbs:
	-- This hook is undocumented, and *probably* only ever meant for internal usage.
	-- However, interfacing with it lets us avoid making tons of dummy entities.
	-- This is a chance find of mine, and I'm not sure of other addons do this or not.
	-- See source here: https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/sandbox/gamemode/spawnmenu/creationmenu/content/contenttypes/entities.lua
	hook.Add("PopulateEntities", "sp_populate_spawnmenu", function(pnlContent, tree, _)
		local node = tree:AddNode("Seamless Portals", "icon16/bricks.png") -- Categories are usually forced to have this icon, but technically we can set it to whatever now :O)

		node.DoPopulate = function(self)
			if ( self.PropPanel ) then return end
			
			self.PropPanel = vgui.Create("ContentContainer", pnlContent)
			self.PropPanel:SetVisible(false)
			self.PropPanel:SetTriggerSpawnlistChange(false)

			for k,v in ipairs(entries) do
				local finalK = k + 0 -- I'm not actually sure if this is necessary, but I've been conditioned by Java
				local icon = spawnmenu.CreateContentIcon("entity", self.PropPanel, {
					["nicename"] = v["name"],
					["spawnname"] = "seamless_portal",
					["material"] = v["icon"] or "entities/seamless_portal.png",
					["admin"] = v["adminOnly"]
				})
				-- Override the default click action, otherwise it will
				-- attempt to spawn the entity with the normal spawn function
				-- which will probably silently fail since spawnable is set to false
				icon.DoClick = function(self)
					net.Start("seamless_portal_spawn")
					net.WriteInt(k, msgBits)
					net.SendToServer()
					surface.PlaySound("UI/buttonclick.wav")
				end
			end
		end

		node.DoClick = function(self)
			self:DoPopulate()
			pnlContent:SwitchPanel(self.PropPanel)
		end

	end )

end
