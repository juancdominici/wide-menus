-- RBY Pokédex CONTENTS: claim gives a 304 canvas, but vanilla still draws
-- at the 160 grid (divider at col 14, SEEN/OWN at x=128). Pin the right
-- chrome to cols and keep the species list on the left.

return function(ctx)
  if ctx.isGen2 then return end
  local PokedexMenu = require("src.ui.PokedexMenu")
  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local Strings = require("src.core.Strings")
  local H = ctx.H
  local isWideNow = ctx.isWideNow

  local ROWS = 7
  local FIRST_ROW_Y = 24
  local NUM_X, BALL_X, NAME_X, CURSOR_X = 8, 24, 32, 0

  -- Same pattern as engine/menus/pokedex.asm DrawPokedexVerticalLine.
  local function dividerCodes()
    local codes = { [0] = 0x71 }
    for _, top in ipairs({ 1, 9 }) do
      local code = 0x71
      for i = 0, 8 do
        codes[top + i] = code
        code = code == 0x71 and 0x70 or 0x71
      end
    end
    return codes
  end
  local DIVIDER = dividerCodes()

  local function drawBall(game, x, y)
    local DexEntryMenu = require("src.ui.DexEntryMenu")
    love.graphics.setColor(1, 1, 1, 1)
    DexEntryMenu.tile(game, 0x72, x / 8, y / 8)
    love.graphics.setColor(0, 0, 0, 1)
  end

  local origDraw = PokedexMenu.draw
  function PokedexMenu:draw()
    if not isWideNow(self) then
      return origDraw(self)
    end
    -- Prefer COLS over colsNow(): Game:draw sizes Renderer from uiSize(), but
    -- headless draws (and some overlays) can still report 160 mid-frame.
    -- Inset one tile from the right so SEEN/OWN/DATA are not flush to the edge.
    local cols = ctx.COLS
    local shift = cols - 21
    local uiw = ctx.W
    local rightX = 128 + shift * 8
    local countRight = 152 + shift * 8
    local divTx = 14 + shift

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    local at = self.rowsAt
    local DexEntryMenu = require("src.ui.DexEntryMenu")
    for ty = 0, 17 do
      DexEntryMenu.tile(self.game, DIVIDER[ty], divTx, ty)
    end
    love.graphics.setColor(0, 0, 0, 1)
    -- Classic is 5 tiles; grow with the canvas so the rule reaches the right edge.
    local ruleTx = divTx + 1
    local ruleLen = cols - ruleTx
    Font.draw(("─"):rep(ruleLen), ruleTx * 8, at.rule * 8)
    Font.draw(Strings("CONTENTS"), 8, 8)
    Font.draw(Strings("SEEN"), rightX, at.seen * 8)
    Font.draw(Strings("OWN"), rightX, at.own * 8)
    local function count(n, ty)
      local text = tostring(n)
      Font.draw(text, countRight - Font.width(text), ty * 8)
    end
    count(self.seenCount, at.seen + 1)
    count(self.ownedCount, at.own + 1)
    local labels = self:sideItems()
    for i, label in ipairs(labels) do
      Font.draw(label, rightX, (at.items + (i - 1) * 2) * 8)
    end
    for row = 1, math.min(ROWS, #self.items) do
      local i = self.scroll + row
      local item = self.items[i]
      if not item then break end
      local y = FIRST_ROW_Y + (row - 1) * 16
      Font.draw(item.num, NUM_X, y - 8)
      if item.ball then drawBall(self.game, BALL_X, y) end
      Font.draw(item.name, NAME_X, y)
      if i == self.index then
        Font.drawCode(self.hollowIndex == i
                      and Theme.cursorHollow or Theme.cursor, CURSOR_X, y)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- chooseEntry forces side.tx = 14 after Menu.new pins it wide.
  -- Match the one-tile right inset used by the CONTENTS redraw.
  local origOnChoose = PokedexMenu.onChoose
  PokedexMenu.onChoose = function(item, dexList)
    origOnChoose(item, dexList)
    if not isWideNow(dexList) then return end
    local top = dexList.game.stack:top()
    if top and top ~= dexList and top.tw then
      top.tx = ctx.COLS - top.tw - 1
    end
  end
end
