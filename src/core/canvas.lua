-- Stretch Font.drawBox / fullscreen fills from the classic 160 grid to 304.

return function(ctx)
  local Renderer, Font = ctx.Renderer, ctx.Font
  local PaletteFX = require("src.render.PaletteFX")
  local W, H = ctx.W, ctx.H
  local colsNow = ctx.colsNow
  local unpack = table.unpack or unpack
  -- Love NX (the shipped Windows/Switch runtime) has no debug library.
  local function traceback(err)
    local dbg = debug
    if type(dbg) == "table" and type(dbg.traceback) == "function" then
      return dbg.traceback(err)
    end
    return tostring(err)
  end

  local origWhole = PaletteFX.whole
  function PaletteFX.whole(colors)
    if ctx.isWideNow() then
      local c = colsNow()
      if c < 20 then c = 20 end
      return PaletteFX.zone(colors, 0, 0, c - 1,
                            math.floor(H / 8) - 1)
    end
    return origWhole(colors)
  end

  local function expandDrawBox(tx, ty, tw, th)
    local c = colsNow()
    if tw == 20 then
      if tx == 0 then
        tw = c
      elseif tx + tw == 20 then
        tx = c - tw
      end
    elseif tx + tw == 20 and tw < 20 then
      -- Near-full panels (relearn list, forget list) grow with the
      -- canvas. Small right-anchored widgets (YES/NO, money) stay pinned.
      if tx < 10 and tw >= 14 then
        tw = c - tx
      else
        tx = c - tw
      end
    end
    return tx, ty, tw, th
  end

  local function withWideCanvas(draw)
    return function(self, ...)
      local args = { ... }
      if not ctx.isWideNow(self)
          or (self and (self.keepClassicUi or self.isClassicCenteredOnWide)) then
        return draw(self, unpack(args))
      end
      local realBox = Font.drawBox
      local realRect = love.graphics.rectangle
      Font.drawBox = function(tx, ty, tw, th)
        tx, ty, tw, th = expandDrawBox(tx, ty, tw, th)
        return realBox(tx, ty, tw, th)
      end
      love.graphics.rectangle = function(mode, x, y, w, h, ...)
        if mode == "fill" and x == 0 and y == 0 and w == 160 and h == 144 then
          w, h = W, H
        end
        return realRect(mode, x, y, w, h, ...)
      end
      -- DYNAMIC UI docks whatever setUIAnchor reports. Stretching drawBox
      -- to 304 while the anchor stays 160 rips the box in half (Celadon
      -- vending / prize confirm overlays).
      local realAnchor = Renderer.setUIAnchor
      function Renderer:setUIAnchor(x, y, w, h, anchor)
        local tx, ty, tw, th = expandDrawBox(x / 8, y / 8, w / 8, h / 8)
        return realAnchor(self, tx * 8, ty * 8, tw * 8, th * 8, anchor)
      end
      local ok, err = xpcall(function()
        return draw(self, unpack(args))
      end, traceback)
      Font.drawBox = realBox
      love.graphics.rectangle = realRect
      Renderer.setUIAnchor = realAnchor
      if not ok then error(err) end
    end
  end

  -- Functions are not tables in Lua; keep wrap identity in a weak set.
  local wrappedDraws = setmetatable({}, { __mode = "k" })

  ctx.withWideCanvas = withWideCanvas

  -- Gold overlays print on the 20-col grid. Stretch full-width boxes and
  -- pin right-anchored widgets (GIVE/TAKE, YES/NO) so labels move with them.
  local function withChromeWide(draw)
    local okChrome, Chrome = pcall(require, "src.ui.gen2.Chrome")
    if not okChrome or type(Chrome) ~= "table" then
      return draw()
    end
    local cols = ctx.COLS
    local shift = cols - 20
    local origBox, origPrint, origCursor = Chrome.box, Chrome.print, Chrome.cursor
    function Chrome.box(tx, ty, tw, th)
      tx, ty, tw, th = tx or 0, ty or 0, tw or 0, th or 0
      if tw == 20 and tx == 0 then
        tw = cols
      elseif tx + tw == 20 then
        tx = cols - tw
      end
      return origBox(tx, ty, tw, th)
    end
    function Chrome.print(text, tx, ty)
      if (tx or 0) >= 10 then tx = tx + shift end
      return origPrint(text, tx, ty)
    end
    function Chrome.cursor(tx, ty, hollow)
      if (tx or 0) >= 10 then tx = tx + shift end
      return origCursor(tx, ty, hollow)
    end
    local ok, err = xpcall(draw, traceback)
    Chrome.box, Chrome.print, Chrome.cursor = origBox, origPrint, origCursor
    if not ok then error(err) end
  end

  function ctx.installWidescreen(target)
    if not ctx.isGen2 or type(target) ~= "table" then return target end
    if target._uiModWideScreen then return target end
    target._uiModWideScreen = true
    -- Gold's own 160-centered surround. Used when the per-screen toggle is
    -- off so BUY prices / Chrome boxes keep the cart grid.
    local nativeDrawWide = target.drawWidescreen
    function target:drawsWidescreen()
      -- Always stay on Gold's widescreen branch. Returning false while
      -- drawWidescreen is still on the module hits Game2's opaque safety
      -- net, which calls drawWidescreen AND blits the 160 canvas -- that
      -- is the live-toggle ghosting.
      if self.isOpaque == false then
        return ctx.opaqueWideParent(self.game, self) ~= nil
      end
      return true
    end
    function target:drawWidescreen(winW, winH)
      local useWide = not self.keepClassicUi and not self.isClassicCenteredOnWide
        and ctx.layoutEnabled(self)
      if not useWide then
        if type(nativeDrawWide) == "function" then
          return nativeDrawWide(self, winW, winH)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, winW, winH)
        local scale = math.max(1, math.floor(math.min(winW / ctx.CLASSIC_W, winH / H)))
        love.graphics.push()
        love.graphics.translate(
          math.floor((winW - ctx.CLASSIC_W * scale) / 2),
          math.floor((winH - H * scale) / 2))
        love.graphics.scale(scale, scale)
        if self.draw then self:draw() end
        love.graphics.pop()
        return
      end
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, winW, winH)
      local scale = math.max(1, math.floor(math.min(winW / W, winH / H)))
      love.graphics.push()
      love.graphics.translate(
        math.floor((winW - W * scale) / 2),
        math.floor((winH - H * scale) / 2))
      love.graphics.scale(scale, scale)
      ctx.setForceWide(true)
      local ok, err = xpcall(function()
        -- Gold only calls the top screen's drawWidescreen. Transparent
        -- overlays (GIVE/TAKE, mail) must paint the party underneath or
        -- the list disappears. Wide opaque menus (mart) must not take
        -- this path: a leftover translate clipped their 304 layout.
        if self.isOpaque == false and not self.isWideMenuLayout then
          local stack = self.game and self.game.stack
          local states = stack and stack.states
          if states then
            local base = stack.visibleBase and stack:visibleBase() or 1
            for i = base, #states do
              local s = states[i]
              if s == self then break end
              if s and s.draw then s:draw() end
            end
          end
          if self.draw then withChromeWide(function() self:draw() end) end
        elseif self.draw then
          self:draw()
        end
      end, traceback)
      ctx.setForceWide(false)
      love.graphics.pop()
      if not ok then error(err) end
    end
    return target
  end

  local origClaim = ctx.claimWide
  function ctx.claimWide(target)
    origClaim(target)
    ctx.installWidescreen(target)
    return target
  end

  function ctx.wrapDraw(M)
    if type(M) ~= "table" or type(M.draw) ~= "function" then return M end
    if M._uiModSkipWrap then return M end
    if M._uiModWideDraw or wrappedDraws[M.draw] then
      M._uiModWideDraw = true
      return M
    end
    local wrapped = withWideCanvas(M.draw)
    wrappedDraws[wrapped] = true
    M._uiModWideDraw = true
    M.draw = wrapped
    return M
  end

  -- TrimUI Brick (and other GLES handhelds) can hard-crash when LOVE
  -- releases the 160 UI FBO and allocates 304 while Yellow's overworld
  -- textures are still resident. Mods load before Renderer:init, so pool
  -- both sizes at init and swap pointers instead of newCanvas in-game.
  if not Renderer._uiModCanvasPool then
    Renderer._uiModCanvasPool = true
    local pool = {}
    local origSetUISize = Renderer.setUISize
    local origInit = Renderer.init

    local function poolKey(w, h)
      if type(w) ~= "number" or type(h) ~= "number" then return nil end
      return math.floor(w) .. "x" .. math.floor(h)
    end

    local function unbind(canvas)
      local g = love and love.graphics
      if not (canvas and g and g.getCanvas and g.setCanvas) then return end
      local ok, current = pcall(g.getCanvas)
      if ok and current == canvas then pcall(g.setCanvas) end
    end

    function Renderer:setUISize(w, h)
      if type(w) ~= "number" or type(h) ~= "number"
          or w < self.WIDTH or h < self.HEIGHT
          or w > self.MAX_UI_WIDTH or h > self.MAX_UI_HEIGHT then
        w, h = self.WIDTH, self.HEIGHT
      end
      w, h = math.floor(w), math.floor(h)
      if w == self.uiWidth and h == self.uiHeight and self.canvas then return end

      unbind(self.canvas)
      local oldKey = poolKey(self.uiWidth, self.uiHeight)
      if self.canvas and oldKey then pool[oldKey] = self.canvas end

      local newKey = poolKey(w, h)
      local reused = newKey and pool[newKey]
      if reused then
        self.uiWidth, self.uiHeight = w, h
        self.canvas = reused
        return
      end

      local saved = self.canvas
      local savedW, savedH = self.uiWidth, self.uiHeight
      self.canvas = nil
      local ok = pcall(origSetUISize, self, w, h)
      if ok and self.canvas then
        pool[poolKey(self.uiWidth, self.uiHeight)] = self.canvas
        return
      end
      self.uiWidth, self.uiHeight = savedW, savedH
      self.canvas = saved
    end

    function Renderer:init(...)
      origInit(self, ...)
      local key = poolKey(self.uiWidth, self.uiHeight)
      if self.canvas and key then pool[key] = self.canvas end
      pcall(function()
        self:setUISize(W, H)
        self:setUISize(self.WIDTH, self.HEIGHT)
      end)
    end
  end
end

