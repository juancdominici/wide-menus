return function(ctx)
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local Strings = require("src.core.Strings")
  local ManagerState = require("src.mods.ManagerState")
  local COLS = ctx.COLS
  local drawTruncated, wordWrap = ctx.drawTruncated, ctx.wordWrap
  local isWideNow = ctx.isWideNow

  local origOverlay = ManagerState.drawOverlay
  function ManagerState:drawOverlay()
    if not isWideNow(self) then
      return origOverlay(self)
    end
    local overlay = self.overlay
    local lines = {}
    for _, raw in ipairs(overlay.lines) do
      for _, line in ipairs(wordWrap(raw, COLS - 8)) do
        lines[#lines + 1] = line
      end
    end
    local th = math.max(6, #lines + (overlay.kind == "confirm" and 5 or 3))
    local ty = math.max(1, math.floor((18 - th) / 2))
    local tw, tx = COLS - 4, 2
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", tx * 8, ty * 8, tw * 8, th * 8)
    love.graphics.setColor(1, 1, 1, 1)
    Font.drawBox(tx, ty, tw, th)
    for i, line in ipairs(lines) do
      drawTruncated(line, (tx + 2) * 8, (ty + i) * 8, tw - 4)
    end
    if overlay.kind == "confirm" then
      local yesY = ty + #lines + 1
      Font.draw(Strings("YES"), (tx + 3) * 8, yesY * 8)
      Font.draw(Strings("NO"), (tx + 3) * 8, (yesY + 1) * 8)
      Font.drawCode(Theme.cursor, (tx + 2) * 8,
                    (overlay.index == 1 and yesY or yesY + 1) * 8)
    else
      Font.draw(Strings("A:OK"), (tx + 3) * 8, (ty + #lines + 1) * 8)
    end
  end
end
