SeamlessPortals = SeamlessPortals or {}

if CLIENT then timer.Simple(0, function()
  local all = effects.GetList() or {}
  local eff = all["ToolTracer"]
  local bck = Color( 255, 255, 255, 255)

  local function DrawBeam(vStr, vEnd, nLife)
    local aim = (vStr - vEnd)
    local alen = aim:Length()
    local norm = (aim * nLife)
    local nlen = (alen * nLife)
    local ncor = math.Rand( 0, 1 )
          bck.a = 128 * (1 - nLife)

    for i = 1, 3 do
      render.DrawBeam(vStr - norm,
            vEnd,
            8,
            ncor,
            ncor + (nlen / 128),
            color_white )
    end

    render.DrawBeam(vStr,
            vEnd,
            8,
            ncor,
            ncor + (alen / 128),
            bck)
  end

  local seamless = {["seamless_portal"] = true}
  local function GetPair(ent)
    if(not IsValid(ent)) then return end
    if(not seamless[ent:GetClass()]) then return end
    local out = ent:GetExitPortal()
    if(not IsValid(out)) then return end
    if(not seamless[out:GetClass()]) then return end
    return ent, out
  end

  -- General effect rendering function
  local function DoEffectRender(self)
    if ( self.Alpha < 1 ) then return end
    render.SetMaterial( self.Mat )
    local user = LocalPlayer()
    local vs = self.StartPos
    local ve = self.EndPos
    local lf, to = self.Life, {}
    -- Do a regular trace to hit the portal
    local tr = SeamlessPortals.TraceLine({
      start = vs,
      endpos = vs + user:GetAimVector() * 10000,
      filter = user,
      output = to
    })
    -- Check the linked pair
    local ent, out = GetPair(tr.Entity)
    if(ent and out) then
      local cnt = 0 -- Infinite loop prevension
      local as, ae = user:EyeAngles(), user:EyeAngles()
      local ps, pe = Vector(vs), Vector(tr.HitPos)
      while(ent and out) do --Trace hits a linked pair
        DrawBeam(ps, pe, lf) -- Draw a section of the beam
        -- Transform end coords of the section to find the next pair
        ps, as = SeamlessPortals.TransformPortal(ent, out, pe, ae)
        -- Trace out from the exit portal (out)
        local tr = SeamlessPortals.TraceLine({
          start = ps,
          endpos = ps + as:Forward() * 10000,
          filter = {ent, out, user},
          output = to
        })
        -- Update the end location after the trace
        pe:Set(tr.HitPos)
        ae:Set(as)
        -- If we hit a portal pair continue
        ent, out = GetPair(tr.Entity)
        cnt = cnt + 1
        if(cnt > 100) then return end
      end
      -- Make sure to draw the last pair
      DrawBeam(ps, ve, lf)
    else
      DrawBeam(vs, ve, lf)
    end
  end

  if eff then
    -- Keep the old Render if you want to call it
    SeamlessPortals.ToolTraceEffRender = eff.Render

    -- Override the tool trace render with the new routine
    eff.Render = DoEffectRender

    -- Optionally call SeamlessPortals.ToolTraceEffRender(self) here if needed

    -- Print the initialized effect status
    print("Tool trace override [eff]:", DoEffectRender)
  else
    -- Fallback: register a full effect if ToolTracer does not exist yet
    local EFFECT = {}
          EFFECT.Mat = Material( "effects/tool_tracer" )

    -- Copy or Implement GetTracerShootPos/Init/Think here
    -- See base effect in gamemodes/base/entities/effects/tooltracer.lua
    function EFFECT:Init(data)
      self.Position   = data:GetStart()
      self.WeaponEnt  = data:GetEntity()
      self.Attachment = data:GetAttachment()
      self.StartPos   = self:GetTracerShootPos(self.Position, self.WeaponEnt, self.Attachment)
      self.EndPos     = data:GetOrigin()
      self.Alpha      = 255
      self.Life       = 0
      self:SetRenderBoundsWS(self.StartPos, self.EndPos)
    end

    function EFFECT:Think()
      self.Life = self.Life + FrameTime() * 4
      self.Alpha = 255 * (1 - self.Life)
      return self.Life < 1
    end

    -- Override the tool trace render with the new routine
    EFFECT.Render = DoEffectRender

    effects.Register(EFFECT, "ToolTracer")

    -- Print the initialized effect status
    print("Tool trace override [new]:", DoEffectRender)
  end


end) end
