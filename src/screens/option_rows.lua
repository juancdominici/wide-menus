return function(ctx)
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local OptionsMenu = require("src.ui.OptionsMenu")
  local Strings = require("src.core.Strings")
  local H, COLS = ctx.H, ctx.COLS
  local isWideNow = ctx.isWideNow
  local VISIBLE = 4
  local GOLD_VISIBLE = 7

  local function rowValue(game, row)
    if type(row.value) == "function" then
      return tostring(row.value(game) or "")
    end
    return ""
  end

  local function goldRowValue(self, row)
    local options = self.options or {}
    if row.frame then
      return "TYPE " .. tostring(options.frame or 1)
    end
    if type(row.text) == "function" then
      return tostring(row.text(options) or "")
    end
    if row.values then
      local value = options[row.key]
      if row.display then return tostring(row.display[value] or value or "") end
      return tostring(value or "")
    end
    if type(row.value) == "function" then
      local ok, text = pcall(row.value, self.game)
      return ok and tostring(text) or "?"
    end
    if row.cancel then return "" end
    return ""
  end

  function ctx.drawOptionRows(game, rows, index, scroll, bottomLabel, bottomRow)
    local uiw = ctx.W
    local cols = COLS
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    for slot = 1, VISIBLE do
      local i = scroll + slot
      local row = rows[i]
      if not row then break end
      local ty = (slot - 1) * 4
      Font.drawBox(0, ty, cols, 4)
      love.graphics.setColor(0, 0, 0, 1)
      local label = row.label or ""
      local value = rowValue(game, row)
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
    if scroll + VISIBLE < #rows then
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

  local function drawGoldOptions(self)
    local uiw = ctx.W
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    Font.drawBox(0, 0, COLS, 18)
    local rows = self.rows or {}
    local scroll = self.scroll or 0
    for slot = 1, GOLD_VISIBLE do
      local i = scroll + slot
      local row = rows[i]
      if not row then break end
      local y = (1 + (slot - 1) * 2) * 8
      love.graphics.setColor(0, 0, 0, 1)
      local label = row.label or ""
      Font.draw(label, 16, y)
      local value = goldRowValue(self, row)
      if value ~= "" then
        local vx = uiw - 16 - Font.width(value)
        local minX = 16 + Font.width(label) + 16
        if vx < minX then vx = minX end
        Font.draw(value, vx, y)
      end
      if i == self.index then
        Font.drawCode(Theme.cursor, 8, y)
      end
    end
    if scroll + GOLD_VISIBLE < #rows then
      Font.drawCode(Theme.moreArrow, uiw - 16, 128)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local origDraw = OptionsMenu.draw
  function OptionsMenu:draw()
    if not isWideNow(self) then
      return origDraw(self)
    end
    if ctx.isGen2 then
      return drawGoldOptions(self)
    end
    return ctx.drawOptionRows(self.game, self.rows or {}, self.index,
                              self.scroll or 0, Strings("CANCEL"),
                              #(self.rows or {}) + 1)
  end
end
