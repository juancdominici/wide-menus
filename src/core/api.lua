-- Other mods: mod.find("ui-mod").exports
-- Native ListMenu screens widen on their own. Custom screens set
-- state.uiModLayout to "wide", "centered", or "classic", or call register.
-- Declare optional_dependencies: ["ui-mod"] so find() works at load time.

return function(ctx)
  local LAYOUTS = { wide = true, centered = true, classic = true }
  ctx.layouts = ctx.layouts or {}

  local function normalize(spec)
    local layout = spec
    if type(spec) == "table" then layout = spec.layout end
    if layout == nil then layout = "wide" end
    if not LAYOUTS[layout] then
      error("ui-mod: layout must be 'wide', 'centered', or 'classic'")
    end
    return layout
  end

  function ctx.claimCentered(target)
    if type(target) ~= "table" then return target end
    target.isWideMenuLayout = true
    target.isClassicCenteredOnWide = true
    target.keepClassicUi = nil
    target.uiModLayout = "centered"
    return target
  end

  function ctx.refuseWide(target)
    if type(target) ~= "table" then return target end
    target.isWideMenuLayout = false
    target.isClassicCenteredOnWide = false
    target.keepClassicUi = true
    target.uiModLayout = "classic"
    target.uiSize = function()
      return ctx.CLASSIC_W, ctx.Renderer.HEIGHT
    end
    return target
  end

  function ctx.resolveLayout(id, inst)
    if type(inst) == "table" then
      if inst.keepClassicUi then return "classic" end
      local declared = inst.uiModLayout or (id and ctx.layouts[id])
      if LAYOUTS[declared] then return declared end
      return nil
    end
    return id and ctx.layouts[id] or nil
  end

  function ctx.applyLayout(target, layout)
    if type(target) ~= "table" or not LAYOUTS[layout] then return target end
    if layout == "classic" then
      ctx.refuseWide(target)
    elseif layout == "centered" then
      ctx.claimCentered(target)
    else
      target.keepClassicUi = nil
      ctx.claimWide(target)
      ctx.wrapDraw(target)
    end
    return target
  end

  ctx.api = {
    WIDTH = ctx.W, HEIGHT = ctx.H, COLS = ctx.COLS,
    CLASSIC_WIDTH = ctx.CLASSIC_W,
    size = function() return ctx.W, ctx.H end,
    cols = ctx.colsNow,
    wordWrap = ctx.wordWrap,
    drawTruncated = ctx.drawTruncated,
    wrapDraw = ctx.wrapDraw,
    register = function(id, spec)
      assert(type(id) == "string" and id ~= "", "ui-mod.register needs a screen id")
      ctx.layouts[id] = normalize(spec)
    end,
    claim = function(target) return ctx.applyLayout(target, "wide") end,
    claimCentered = function(target) return ctx.applyLayout(target, "centered") end,
    refuse = function(target) return ctx.applyLayout(target, "classic") end,
    layoutOf = function(id, inst)
      if type(id) == "table" then return ctx.resolveLayout(id.screenId, id) end
      return ctx.resolveLayout(id, inst)
    end,
  }
end
