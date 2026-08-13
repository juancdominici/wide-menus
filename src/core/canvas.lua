-- Stretch Font.drawBox / fullscreen fills from the classic 160 grid to 304.

return function(ctx)
  local Renderer, Font = ctx.Renderer, ctx.Font
  local PaletteFX = require("src.render.PaletteFX")
  local W, H, CLASSIC_W = ctx.W, ctx.H, ctx.CLASSIC_W
  local colsNow = ctx.colsNow

  local origWhole = PaletteFX.whole
  function PaletteFX.whole(colors)
    local uiw, uih = Renderer:uiSize()
    if uiw > CLASSIC_W then
      return PaletteFX.zone(colors, 0, 0,
                            math.floor(uiw / 8) - 1,
                            math.floor(uih / 8) - 1)
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
      if select(1, Renderer:uiSize()) <= CLASSIC_W then
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
      local ok, err = xpcall(function()
        return draw(self, unpack(args))
      end, debug.traceback)
      Font.drawBox = realBox
      love.graphics.rectangle = realRect
      if not ok then error(err) end
    end
  end

  -- Functions are not tables in Lua; keep wrap identity in a weak set.
  local wrappedDraws = setmetatable({}, { __mode = "k" })

  ctx.withWideCanvas = withWideCanvas
  function ctx.wrapDraw(M)
    if type(M) ~= "table" or type(M.draw) ~= "function" then return M end
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
end

