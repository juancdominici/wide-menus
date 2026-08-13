return function(ctx)
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local Strings = require("src.core.Strings")
  local OptionRows = require("src.ui.OptionRows")
  local ManagerState = require("src.mods.ManagerState")
  local Renderer, W, H, COLS = ctx.Renderer, ctx.W, ctx.H, ctx.COLS
  local CLASSIC_W, drawTruncated = ctx.CLASSIC_W, ctx.drawTruncated
  local LIST_TOP, LIST_ROWS = 3, 11

  local origDraw = ManagerState.draw
  local origDrawRows = ManagerState.drawRows

  function ManagerState:drawRows(rows)
    if select(1, Renderer:uiSize()) <= CLASSIC_W then
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

  function ManagerState:draw()
    if select(1, Renderer:uiSize()) <= CLASSIC_W then
      return origDraw(self)
    end
    if self.screen == "options" then
      OptionRows.draw(self.game, self.optionRows or {}, self.cursor,
                      self.scroll or 0)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(self.notice or Strings("B:DONE (NO RESTART)"), 8, 136)
      love.graphics.setColor(1, 1, 1, 1)
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
