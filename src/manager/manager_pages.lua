return function(ctx)
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local Strings = require("src.core.Strings")
  local ManagerState = require("src.mods.ManagerState")
  local COLS = ctx.COLS
  local drawTruncated, wordWrap = ctx.drawTruncated, ctx.wordWrap
  local isWideNow = ctx.isWideNow
  local LIST_TOP = 3

  local origApply = ManagerState.drawApply
  local origDetail = ManagerState.drawDetail

  function ManagerState:drawApply()
    if not isWideNow(self) then
      return origApply(self)
    end
    drawTruncated("PENDING CHANGES", 16, 2 * 8, COLS - 3)
    local staged = self:stagedList()
    local y = LIST_TOP
    local shown = math.min(#staged, 7)
    for i = 1, shown do
      local m = staged[i]
      local verb = m.enabled and "ON " or "OFF "
      drawTruncated(verb .. (m.name or m.id), 16, y * 8, COLS - 3)
      y = y + 1
    end
    if #staged == 0 then
      local Runtime = require("src.mods.Runtime")
      Font.draw(Runtime.safeMode and "SAFE MODE" or Strings("NO CHANGES"), 16, y * 8)
    end
    local rows = self:rowsForScreen()
    local base = 12
    for i, row in ipairs(rows) do
      drawTruncated(row.label, 32, (base + i - 1) * 8, COLS - 5)
      if i == self.cursor then
        Font.drawCode(Theme.cursor, 24, (base + i - 1) * 8)
      end
    end
    self:drawFooter("A:CHOOSE B:BACK")
  end

  function ManagerState:drawDetail()
    if not isWideNow(self) then
      return origDetail(self)
    end
    local m = self.currentMod
    if not m then return end
    local title = wordWrap(m.name or m.id, COLS - 6)
    drawTruncated(title[1] .. " " .. (m.version or ""), 16, 2 * 8, COLS - 3)
    local statusLine = m.enabled and "ENABLED" or "DISABLED"
    if m.state == "blocked_dependency" then
      statusLine = statusLine .. " ?"
    elseif m.error then
      statusLine = statusLine .. " !"
    end
    if self:isStaged(m) then statusLine = statusLine .. " (STAGED)" end
    drawTruncated(statusLine, 16, 3 * 8, COLS - 3)
    drawTruncated((m.category or "OTHER") .. " / " .. (m.profile or "content"),
                  16, 4 * 8, COLS - 3)
    local lines = wordWrap(m.error and ("FAILED: " .. m.error) or m.description,
                           COLS - 4)
    local visible = 5
    for i = 1, visible do
      local line = lines[self.descScroll + i - 1]
      if not line then break end
      Font.draw(line, 16, (5 + i) * 8)
    end
    if self.descScroll + visible <= #lines then
      Font.drawCode(Theme.moreArrow, (COLS - 3) * 8, 10 * 8)
    end
    local rows = self:rowsForScreen()
    local top, last = 11, 15
    local slots = last - top + 1
    local first = 1
    if #rows > slots then
      first = math.max(1, math.min(self.cursor - slots + 1, #rows - slots + 1))
    end
    local y = top
    local shown = math.min(#rows, first + slots - 1)
    local more = shown < #rows
    local labelCols = more and (COLS - 6) or (COLS - 5)
    for i = first, shown do
      drawTruncated(rows[i].label, 32, y * 8, labelCols)
      if i == self.cursor then Font.drawCode(Theme.cursor, 24, y * 8) end
      y = y + 1
    end
    if more then
      Font.drawCode(Theme.moreArrow, (COLS - 2) * 8, last * 8)
    end
    self:drawFooter("A:CHOOSE B:BACK")
  end
end
