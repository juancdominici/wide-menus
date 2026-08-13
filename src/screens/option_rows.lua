return function(ctx)
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local OptionRows = require("src.ui.OptionRows")
  local Renderer, H, CLASSIC_W = ctx.Renderer, ctx.H, ctx.CLASSIC_W

  local origOptionRowsDraw = OptionRows.draw
  function OptionRows.draw(game, rows, index, scroll, bottomLabel, bottomRow)
    local uiw = select(1, Renderer:uiSize())
    if uiw <= CLASSIC_W then
      return origOptionRowsDraw(game, rows, index, scroll, bottomLabel, bottomRow)
    end
    local cols = math.floor(uiw / 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    for slot = 1, OptionRows.VISIBLE do
      local i = scroll + slot
      local row = rows[i]
      if not row then break end
      local ty = (slot - 1) * 4
      Font.drawBox(0, ty, cols, 4)
      love.graphics.setColor(0, 0, 0, 1)
      local label = row.label or ""
      local value = row.value and row.value(game) or ""
      Font.draw(label, 16, (ty + 1) * 8)
      if value ~= "" then
        local vx = uiw - 16 - Font.width(value)
        local minX = 16 + Font.width(label) + 16
        if vx < minX then vx = minX end
        Font.draw(value, vx, (ty + 1) * 8)
      end
      if i == index then
        Font.drawCode(Theme.cursor, 8, (ty + 1) * 8)
      end
    end
    if scroll + OptionRows.VISIBLE < #rows then
      Font.drawCode(Theme.moreArrow, uiw - 16, 128)
    end
    if bottomLabel then
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(bottomLabel, 16, 136)
      if bottomRow and index == bottomRow then
        Font.drawCode(Theme.cursor, 8, 136)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end
end
