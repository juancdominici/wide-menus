return function(ctx)
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local Strings = require("src.core.Strings")
  local ManagerState = require("src.mods.ManagerState")
  local W, H, COLS = ctx.W, ctx.H, ctx.COLS
  local drawTruncated = ctx.drawTruncated
  local isWideNow = ctx.isWideNow
  local LIST_TOP, LIST_ROWS = 3, 11

  local origDraw = ManagerState.draw
  local origDrawRows = ManagerState.drawRows
  local origFooter = ManagerState.drawFooter

  function ManagerState:drawRows(rows)
    if not isWideNow(self) then
      return origDrawRows(self, rows)
    end
    local last = math.min(#rows, self.scroll + LIST_ROWS - 1)
    local y = LIST_TOP
    local headerCols = COLS - 3
    local labelCols = COLS - 5
    for i = self.scroll, last do
      local row = rows[i]
      if row.header then
        drawTruncated(row.label, 16, y * 8, headerCols)
      else
        if row.glyph and row.glyph ~= " " then
          Font.draw(row.glyph, 16, y * 8)
        end
        drawTruncated(row.label, 32, y * 8, labelCols)
        if i == self.cursor then
          Font.drawCode(Theme.cursor, 8, y * 8)
        end
      end
      y = y + 1
    end
    if #rows > last then
      Font.drawCode(Theme.moreArrow, (COLS - 2) * 8, (LIST_TOP + LIST_ROWS) * 8)
    end
  end

  -- Classic footer sits on rows 15-16. A one-line prompt only needs 16, so
  -- detail actions can use 15 without painting over A:CHOOSE / B:BACK.
  function ManagerState:drawFooter(line1, line2)
    if not isWideNow(self) then
      return origFooter(self, line1, line2)
    end
    local inner = COLS - 3
    if self.notice then
      drawTruncated(self.notice, 16, 16 * 8, inner)
      return
    end
    if line1 and line2 then
      drawTruncated(line1, 16, 15 * 8, inner)
      drawTruncated(line2, 16, 16 * 8, inner)
    elseif line1 then
      drawTruncated(line1, 16, 16 * 8, inner)
    end
  end

  function ManagerState:draw()
    if not isWideNow(self) then
      return origDraw(self)
    end
    if self.screen == "options" then
      ctx.drawOptionRows(self.game, self.optionRows or {}, self.cursor,
                         self.scroll or 0,
                         self.notice or Strings("B:DONE (NO RESTART)"))
      if self.overlay then self:drawOverlay() end
      return
    end
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(1, 1, 1, 1)
    Font.drawBox(0, 0, COLS, 18)
    Font.draw(self.banner or Strings("MOD MANAGER"), 16, 8)
    if self.screen == "list" then
      self:drawList()
    elseif self.screen == "detail" then
      self:drawDetail()
    elseif self.screen == "permissions" then
      self:drawPermissions()
    elseif self.screen == "errors" then
      self:drawErrors()
    elseif self.screen == "apply" then
      self:drawApply()
    end
    if self.overlay then self:drawOverlay() end
  end
end
