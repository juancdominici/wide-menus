-- Compact OPTIONS list: one outer frame, 12 one-line rows, label left /
-- value right, and heading rows between groups.

return function(ctx)
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local Strings = require("src.core.Strings")
  local OptionRows = require("src.ui.OptionRows")
  local H = ctx.H
  local isWideNow = ctx.isWideNow
  local VISIBLE = 12

  local function textWidth(text)
    if type(Font.width) == "function" then return Font.width(text) end
    return #tostring(text or "") * 8
  end

  local function rowValue(game, row)
    if type(row.value) ~= "function" then return "" end
    local ok, text = pcall(row.value, game)
    return ok and tostring(text or "") or "?"
  end

  local function goldRowValue(self, row)
    local options = self.options or {}
    if row.frame then
      return "TYPE " .. tostring(options.frame or 1)
    end
    if type(row.text) == "function" then
      local ok, text = pcall(row.text, options)
      return ok and tostring(text or "") or "?"
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

  local function isHeading(row)
    return row and (row.heading == true or row.header == true)
  end

  local function groupByIds(rows, spec, leftoverName)
    if type(rows) ~= "table" or (rows[1] and isHeading(rows[1])) then
      return rows
    end
    local idToGroup = {}
    for gi, group in ipairs(spec) do
      for id in pairs(group[2]) do idToGroup[id] = gi end
    end
    local buckets = {}
    for i = 1, #spec + 1 do buckets[i] = {} end
    for _, row in ipairs(rows) do
      local gi = (row.id and idToGroup[row.id]) or (#spec + 1)
      buckets[gi][#buckets[gi] + 1] = row
    end
    local out = {}
    for gi, group in ipairs(spec) do
      if #buckets[gi] > 0 then
        out[#out + 1] = { heading = true, label = group[1] }
        for _, row in ipairs(buckets[gi]) do out[#out + 1] = row end
      end
    end
    if leftoverName and #buckets[#spec + 1] > 0 then
      out[#out + 1] = { heading = true, label = leftoverName }
      for _, row in ipairs(buckets[#spec + 1]) do out[#out + 1] = row end
    end
    return out
  end

  local function firstSelectable(rows, cancelRow)
    for i, row in ipairs(rows or {}) do
      if not isHeading(row) then return i end
    end
    return cancelRow or 1
  end

  local function rememberSelection(self)
    local row = self.rows and self.rows[self.index]
    self._wideSelectedId = row and not isHeading(row) and row.id or nil
  end

  local function clampCompactScroll(self)
    local total = #(self.rows or {})
    local maxScroll = math.max(0, total - VISIBLE)
    local index = self.index or 1
    local scroll = self.scroll or 0
    if index >= total + 1 then
      scroll = maxScroll
    elseif index <= scroll then
      scroll = math.max(0, index - 1)
    elseif index > scroll + VISIBLE then
      scroll = index - VISIBLE
    end
    self.scroll = math.max(0, math.min(scroll, maxScroll))
  end

  local function restoreSelection(self)
    local id = self._wideSelectedId
    if id and type(self.rows) == "table" then
      for i, row in ipairs(self.rows) do
        if row.id == id then
          self.index = i
          clampCompactScroll(self)
          return
        end
      end
      self._wideSelectedId = nil
      self.index = firstSelectable(self.rows, #self.rows + 1)
    end
    clampCompactScroll(self)
  end

  local function nextSelectable(rows, index, dir, cancelRow)
    local n = cancelRow or #rows
    if n <= 0 or dir == 0 then return index end
    local i = index
    for _ = 1, n do
      i = i + dir
      if i < 1 then i = n
      elseif i > n then i = 1
      end
      if i == cancelRow or not isHeading(rows[i]) then return i end
    end
    return index
  end

  function ctx.drawOptionRows(game, rows, index, scroll, bottomLabel, bottomRow, opts)
    opts = opts or {}
    local cols = ctx.colsNow()
    if cols < 20 then cols = 20 end
    local uiw = cols * 8
    local valueOf = opts.valueOf or rowValue
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    Font.drawBox(0, 0, cols, 18)
    love.graphics.setColor(0, 0, 0, 1)
    local title = opts.title
    if title ~= false then
      Font.draw(Strings(title or "OPTIONS"), 16, 8)
    end
    -- CANCEL is a sentinel past #rows. Keep the tail in view so Down from
    -- the last visible line cannot hide the rest of the list behind CANCEL.
    if bottomRow and index >= bottomRow then
      scroll = math.max(0, #rows - VISIBLE)
    end
    for slot = 1, VISIBLE do
      local i = scroll + slot
      local row = rows[i]
      if not row then break end
      local y = 16 + slot * 8
      if isHeading(row) then
        Font.draw(row.label or "", 16, y)
      else
        local label = row.label or ""
        local value = valueOf(game, row)
        Font.draw(label, 24, y)
        if value ~= "" then
          local vx = uiw - 16 - textWidth(value)
          local minX = 24 + textWidth(label) + 8
          if vx < minX then vx = minX end
          Font.draw(value, vx, y)
        end
        if i == index then
          Font.drawCode(Theme.cursor, 16, y)
        end
      end
    end
    if scroll + VISIBLE < #rows then
      Font.drawCode(Theme.moreArrow, uiw - 24, 120)
    end
    if bottomLabel then
      Font.draw(bottomLabel, 24, 128)
      if bottomRow and index == bottomRow then
        Font.drawCode(Theme.cursor, 16, 128)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function drawGoldOptions(self)
    return ctx.drawOptionRows(self.game, self.rows or {}, self.index,
                              self.scroll or 0, nil, nil, {
      valueOf = function(_, row) return goldRowValue(self, row) end,
    })
  end

  local function compactActive(self)
    if self and (self.keepClassicUi or self.isClassicCenteredOnWide) then
      return false
    end
    if self and not ctx.layoutEnabled(self) then return false end
    if isWideNow(self) then return true end
    -- Gold update runs without forceWide; still clamp as 12 compact rows.
    return ctx.isGen2 and self ~= nil
  end

  local function withWideVisible(fn)
    return function(self, ...)
      if not compactActive(self) then return fn(self, ...) end
      local saved = OptionRows.VISIBLE
      OptionRows.VISIBLE = VISIBLE
      local ok, a, b, c = pcall(fn, self, ...)
      OptionRows.VISIBLE = saved
      if not ok then error(a) end
      return a, b, c
    end
  end

  -- Wide mode sets VISIBLE=12 and replaces OptionRows.draw. Native
  -- OptionsMenu.update then scrolls the 12-row window. DIY up/down skipped
  -- that and jumped from the last visible line to CANCEL.
  local origClamp = OptionRows.clampScroll
  function OptionRows.clampScroll(index, scroll, total, bottomRow)
    local saved = OptionRows.VISIBLE
    if isWideNow() then OptionRows.VISIBLE = VISIBLE end
    local result = origClamp(index, scroll, total, bottomRow)
    OptionRows.VISIBLE = saved
    return result
  end

  local origOptDraw = OptionRows.draw
  function OptionRows.draw(game, rows, index, scroll, bottomLabel, bottomRow)
    if not isWideNow() then
      return origOptDraw(game, rows, index, scroll, bottomLabel, bottomRow)
    end
    return ctx.drawOptionRows(game, rows, index, scroll, bottomLabel, bottomRow)
  end

  local OPTION_GROUPS = {
    { "TEXT", { textSpeed = true } },
    { "BATTLE", {
      animations = true, battleStyle = true, battleLayout = true,
      battleFit = true, battleBg = true, ruleset = true,
    } },
    { "AUDIO", {
      musicVol = true, sfxVol = true, pikaVol = true, musicFilter = true,
    } },
    { "DISPLAY", {
      performance = true, colors = true, tilt = true, gbcfx = true,
      zoom = true, voidFill = true, videoMode = true, orientation = true,
      faithfulRes = true, fpsCap = true,
    } },
    { "GAME", { speed = true, uiLayout = true } },
  }

  local WIDE_MENU_GROUPS = {
    { "RED/BLUE/YELLOW", {
      rby_options = true, rby_bag = true, rby_shop = true,
      rby_pokedex = true, rby_party = true, rby_controls = true,
    } },
    { "GOLD/SILVER/CRYSTAL", {
      gs_options = true, gs_mart = true, gs_party = true,
    } },
  }

  local function patchDraw(M, wideDraw, beforeDraw)
    if type(M) ~= "table" or type(M.draw) ~= "function" then return end
    local origDraw = M.draw
    function M:draw()
      if not isWideNow(self) then
        return origDraw(self)
      end
      if beforeDraw then beforeDraw(self) end
      return wideDraw(self)
    end
  end

  local okRby, OptionsMenu = pcall(require, "src.ui.OptionsMenu")
  if okRby then
    local origNew = OptionsMenu.new
    function OptionsMenu.new(game, opts)
      local self = origNew(game, opts)
      self.rows = groupByIds(self.rows or {}, OPTION_GROUPS, "SYSTEM")
      self.index = firstSelectable(self.rows, #(self.rows or {}) + 1)
      return self
    end

    local origUpdate = OptionsMenu.update
    OptionsMenu.update = withWideVisible(function(self, dt)
      if not compactActive(self) then return origUpdate(self, dt) end
      restoreSelection(self)
      local rows = self.rows or {}
      local cancelRow = #rows + 1
      local input = self.game.input
      if input:wasPressed("up") then
        self.index = nextSelectable(rows, self.index, -1, cancelRow)
      elseif input:wasPressed("down") then
        self.index = nextSelectable(rows, self.index, 1, cancelRow)
      elseif input:wasPressed("left") or input:wasPressed("right")
          or input:wasPressed("a") then
        local row = rows[self.index]
        if row and not isHeading(row) and row.activate then
          if input:wasPressed("a") then row.activate(self.game) end
        elseif row and not isHeading(row) and row.step then
          local dir = input:wasPressed("left") and -1 or 1
          if row.step(self.game, dir) and self.game.writeOptions then
            self.game:writeOptions()
          end
        elseif input:wasPressed("a") then
          if self.game.data then
            require("src.core.Sound").play(self.game.data, "Press_AB")
          end
          self.game.stack:pop()
          if self.onCancel then self.onCancel() end
        end
      elseif input:wasPressed("b") or input:wasPressed("start") then
        if self.game.data then
          require("src.core.Sound").play(self.game.data, "Press_AB")
        end
        self.game.stack:pop()
        if self.onCancel then self.onCancel() end
      end
      rememberSelection(self)
      self.scroll = OptionRows.clampScroll(self.index, self.scroll or 0,
                                           #rows, cancelRow)
    end)

    patchDraw(OptionsMenu, function(self)
      return ctx.drawOptionRows(self.game, self.rows or {}, self.index,
                                self.scroll or 0, Strings("CANCEL"),
                                #(self.rows or {}) + 1)
    end, restoreSelection)
  end

  local okGold, GoldOptions = pcall(require, "src.ui.gen2.OptionsMenu")
  if okGold then
    patchDraw(GoldOptions, drawGoldOptions)
    if type(GoldOptions.update) == "function" then
      local origGoldUpdate = GoldOptions.update
      GoldOptions.update = withWideVisible(function(self, dt)
        origGoldUpdate(self, dt)
      end)
    end
  end

  local okMgr, ManagerState = pcall(require, "src.mods.ManagerState")
  if okMgr then
    local origBuild = ManagerState.buildOptionRows
    function ManagerState:buildOptionRows(m, schema)
      local rows = origBuild(self, m, schema)
      if m and m.id == "wide-menus" then
        rows = groupByIds(rows, WIDE_MENU_GROUPS, "OTHER")
      end
      return rows
    end

    local origOpen = ManagerState.openOptions
    function ManagerState:openOptions(m)
      origOpen(self, m)
      self.cursor = firstSelectable(self.optionRows or {}, 1)
    end

    local origUpdateOpts = ManagerState.updateOptions
    ManagerState.updateOptions = withWideVisible(function(self, input)
      if not compactActive(self) then return origUpdateOpts(self, input) end
      local rows = self.optionRows or {}
      local n = #rows
      if n == 0 then return end
      if input:wasPressed("up") then
        self.cursor = nextSelectable(rows, self.cursor, -1, n)
      elseif input:wasPressed("down") then
        self.cursor = nextSelectable(rows, self.cursor, 1, n)
      else
        local row = rows[self.cursor]
        if row and isHeading(row) then
          return
        end
        return origUpdateOpts(self, input)
      end
      self.scroll = OptionRows.clampScroll(self.cursor, self.scroll or 0, n, nil)
    end)
  end
end
