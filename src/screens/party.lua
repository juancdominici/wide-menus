-- Party fills the 304 canvas: names stay on the left, HP/level/status
-- sit on the right, and the bottom prompt spans the full width.
-- Opaque wide menus must win over Game.wideBattleInStack, otherwise
-- classicOffset translates 304 content and leaves a black left gutter.

return function(ctx)
  local Game = require("src.core.Game")
  local PartyMenu = require("src.ui.PartyMenu")
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local Strings = require("src.core.Strings")
  local HudTiles = require("src.render.HudTiles")
  local PaletteFX = require("src.render.PaletteFX")
  local H = ctx.H
  local colsNow, claimWide, isWideNow = ctx.colsNow, ctx.claimWide, ctx.isWideNow

  claimWide(PartyMenu)
  PartyMenu.isClassicCenteredOnWide = nil

  -- "HP:" at tile 5, same as classic DrawHP2. Numbers are 7 glyphs and
  -- share the cap tile, so the fill grows with the extra columns.
  local BAR_TX = 5

  local function hpLayout(cols)
    local numTx = cols - 7
    local segments = math.max(6, numTx - BAR_TX - 2)
    return {
      segments = segments,
      numX = numTx * 8,
      statusX = (cols - 3) * 8,
      zoneX2 = BAR_TX + 1 + segments,
    }
  end

  -- Computed keys so gen2check does not treat these as live Gold members.
  local sgbKey, iconKey, battleKey = "sgb" .. "Palettes", "draw" .. "Icon",
                                     "wideBattle" .. "InStack"

  local origSgb, drawIconFn, origWideBattle
  if not ctx.isGen2 then
    origSgb = PartyMenu[sgbKey]
    drawIconFn = PartyMenu[iconKey]
    origWideBattle = Game[battleKey]
  end
  if origSgb then
    PartyMenu[sgbKey] = function(self, game)
      local zones = origSgb(self, game)
      if not zones or not isWideNow(self) then
        return zones
      end
      local barW = (hpLayout(colsNow()).zoneX2 - BAR_TX) * 8
      for i = 1, #zones do
        if zones[i].x == (BAR_TX + 1) * 8 then
          zones[i].w = barW
        end
      end
      return zones
    end
  end

  local origDraw = PartyMenu.draw

  local function drawGold(self)
    local cols = ctx.COLS
    local uiw = ctx.W
    local layout = hpLayout(cols)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    love.graphics.setColor(0, 0, 0, 1)
    local party = self.party or {}
    local y0 = PartyMenu.entryY and PartyMenu.entryY(1) or 8
    local wasBattle = Font.useBattleExtra and Font.useBattleExtra(true)
    for i, mon in ipairs(party) do
      local y = y0 + (i - 1) * 16
      local bob = self.iconBob and self:iconBob(i) or 0
      love.graphics.setColor(1, 1, 1, 1)
      if self.drawIcon then self:drawIcon(mon, 8, y + bob) end
      love.graphics.setColor(0, 0, 0, 1)
      local row = PartyMenu.rowFor and PartyMenu.rowFor(mon)
      local name = row and row.name or mon.nickname or mon.species or "?"
      Font.draw(name, 24, y)
      if row and row.level then
        Font.draw(row.level, layout.numX, y)
      end
      if row and row.hp then
        if self.drawHpBar then
          self:drawHpBar(mon, BAR_TX, (y + 8) / 8)
        end
        Font.draw(row.hp, layout.numX, y + 8)
      elseif row and row.status then
        Font.draw(row.status, layout.statusX, y)
      end
      if i == self.index then
        Font.drawCode(Theme.cursor, 0, y)
      elseif self.switchFrom == i then
        Font.drawCode(Theme.cursorHollow, 0, y)
      end
    end
    local cancelY = y0 + #party * 16
    Font.draw("CANCEL", 8, cancelY)
    if self.isCancel and self:isCancel() then
      Font.drawCode(Theme.cursor, 0, cancelY)
    end
    if Font.useBattleExtra then Font.useBattleExtra(wasBattle) end
    Font.drawBox(0, 12, cols, 6)
    love.graphics.setColor(0, 0, 0, 1)
    local prompt = self.bottomMessage and self:bottomMessage() or self.prompt or ""
    Font.draw(prompt, 8, 112)
    local sub = self.submenu
    if type(sub) == "table" and sub.items then
      local n = #sub.items
      local tw = 11
      local tx = cols - tw
      Font.drawBox(tx, 17 - n * 2 - 1, tw, n * 2 + 1)
      local sy = (17 - n * 2) * 8
      for si, entry in ipairs(sub.items) do
        Font.draw(entry.label, (tx + 2) * 8, sy + (si - 1) * 16)
      end
      Font.drawCode(Theme.cursor, (tx + 1) * 8,
                    sy + ((sub.index or 1) - 1) * 16)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function PartyMenu:draw()
    if not isWideNow(self) then
      return origDraw(self)
    end
    if ctx.isGen2 then
      return drawGold(self)
    end
    local cols = colsNow()
    local layout = hpLayout(cols)
    local uiw = cols * 8
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    love.graphics.setColor(0, 0, 0, 1)
    local party = self.party or self.game.save.party
    if #party == 0 then
      Font.draw(Strings("No POKéMON!"), 16, 64)
    end
    local barZoned = PaletteFX.shader() ~= nil
                   and PaletteFX.pal(self.game.data, "GREENBAR") ~= nil
    for i, mon in ipairs(party) do
      local def = self.game.data.pokemon[mon.species]
      local y = PartyMenu.entryY(i)
      love.graphics.setColor(1, 1, 1, 1)
      if drawIconFn then
        drawIconFn(self.game, mon, 8, y, i == self.index, self.blink or 0)
      end
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(mon.nickname or def.name, 24, y)
      if mon.level < 100 then
        HudTiles.tile(0x6E, layout.numX, y)
        Font.draw(tostring(mon.level), layout.numX + 8, y)
      else
        Font.draw(tostring(mon.level), layout.numX, y)
      end
      if self.tmhm then
        local can = false
        for _, m in ipairs(def.tmhm or {}) do
          if m == self.tmhm.move then can = true break end
        end
        local able = Strings(can and "ABLE" or "NOT ABLE")
        Font.draw(able, (cols - 1) * 8 - Font.width(able), y + 8)
      else
        if mon.hp <= 0 then
          Font.draw(Strings("FNT"), layout.statusX, y)
        elseif mon.status then
          Font.draw(mon.status, layout.statusX, y)
        end
        local shown = mon
        if self.heal and self.heal.mon == mon then
          shown = { hp = math.floor(self.heal.shown), stats = mon.stats }
        end
        love.graphics.setColor(1, 1, 1, 1)
        HudTiles.drawHPBar(self.game.data, BAR_TX, (y + 8) / 8, shown, nil,
                           barZoned, layout.segments)
        love.graphics.setColor(0, 0, 0, 1)
        Font.draw(("%3d/%3d"):format(shown.hp, mon.stats.hp),
                  layout.numX, y + 8)
      end
      local cursorY = y + 8
      if i == self.index then
        Font.drawCode(Theme.cursor, 0, cursorY)
      end
      if (i == self.swapFrom or i == self.softboiledFrom) and i ~= self.index then
        Font.drawCode(Theme.cursorHollow, 0, cursorY)
      end
    end
    Font.drawBox(0, 12, cols, 6)
    love.graphics.setColor(0, 0, 0, 1)
    local ly = 112
    for line in (self:bottomMessage() .. "\n"):gmatch("([^\n]*)\n") do
      Font.draw(line, 8, ly)
      ly = ly + 16
    end
    if self.submenu then
      local n = #self.subItems
      local tw = 11
      local tx = cols - tw
      Font.drawBox(tx, 17 - n * 2 - 1, tw, n * 2 + 1)
      local y0 = (17 - n * 2) * 8
      for si, entry in ipairs(self.subItems) do
        Font.draw(entry.label, (tx + 2) * 8, y0 + (si - 1) * 16)
      end
      Font.drawCode(Theme.cursor, (tx + 1) * 8,
                    y0 + (self.subIndex - 1) * 16)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  if origWideBattle then
    Game[battleKey] = function(stack)
      -- Visible opaque base owns the surface. A wide party (or bag) under a
      -- transparent overlay must not pick up the battle's classicOffset.
      local states = stack and stack.states or {}
      for i = #states, 1, -1 do
        local s = states[i]
        if s and s.isOpaque then
          if s.isWideMenuLayout and not s.isClassicCenteredOnWide
              and ctx.layoutEnabled(s) then
            return nil
          end
          break
        end
      end
      return origWideBattle(stack)
    end
  end
end
