-- Gold mart buy is a cluster of 160-grid boxes. wrapDraw stretches the
-- frames and leaves names/YES-NO/qty on the original tiles. Sell paints
-- the PACK's 160 gfx, so that phase stays classic-centered on 304.

return function(ctx)
  if not ctx.isGen2 then return end
  local ok, MartMenu = pcall(require, "src.ui.gen2.MartMenu")
  if not ok or type(MartMenu) ~= "table" or type(MartMenu.draw) ~= "function" then
    return
  end

  local Font = ctx.Font
  local Theme = require("src.ui.Theme")
  local W, H, COLS, CLASSIC_W = ctx.W, ctx.H, ctx.COLS, ctx.CLASSIC_W
  local origDraw = MartMenu.draw
  MartMenu._uiModSkipWrap = true

  local TOP_ITEMS = { "BUY", "SELL", "QUIT" }
  local VISIBLE_ROWS = 4
  local YEN = "\xc2\xa5"
  local TIMES = "\xc3\x97"
  local UP_ARROW = "\xe2\x96\xb2"
  local DOWN_ARROW = "\xe2\x96\xbc"

  local function moneyText(amount)
    if MartMenu.moneyText then return MartMenu.moneyText(amount) end
    local digits = ("%06d"):format(math.max(0, math.floor(amount or 0)))
    local first = digits:find("[1-9]") or #digits
    return (" "):rep(first - 1) .. YEN .. digits:sub(first)
  end

  local function ink()
    love.graphics.setColor(0, 0, 0, 1)
  end

  local function box(tx, ty, tw, th)
    Font.drawBox(tx, ty, tw, th)
    ink()
  end

  local function at(text, tx, ty)
    ink()
    Font.draw(text, tx * 8, ty * 8)
  end

  local function cursor(tx, ty)
    ink()
    Font.drawCode(Theme.cursor, tx * 8, ty * 8)
  end

  local function textBox(lines, cols)
    box(0, 12, cols, 6)
    for i, line in ipairs(lines or {}) do
      at(line, 1, 14 + (i - 1) * 2)
    end
  end

  local function moneyBox(self, cols)
    local tw = 9
    local tx = cols - tw
    box(tx, 0, tw, 3)
    at(moneyText(self:money()), tx + 1, 1)
  end

  local function topMenu(self)
    box(0, 0, 12, 9)
    for i, label in ipairs(TOP_ITEMS) do
      local ty = 2 + (i - 1) * 2
      if i == self.topIndex then cursor(1, ty) end
      at(label, 2, ty)
    end
  end

  local function buyList(self, cols)
    -- Same right edge as the money box (tile cols-1). Price is a 7-tile
    -- field with two tiles of padding before the border, as in Gold.
    local bx, by, bw, bh = 1, 3, cols - 1, 9
    box(bx, by, bw, bh)
    local priceTx = bx + bw - 10
    for row = 1, VISIBLE_ROWS do
      local i = row + self.scroll
      local ty = 4 + (row - 1) * 2
      if i <= #self.entries then
        local entry = self.entries[i]
        if i == self.index then cursor(bx, ty) end
        at(entry.name, bx + 1, ty)
        -- Gold prints the price on the next tile row; that row is the
        -- box's bottom border for the last entry. Same line as the name.
        at(moneyText(entry.price), priceTx, ty)
      elseif i == self:total() then
        if i == self.index then cursor(bx, ty) end
        at("CANCEL", bx + 1, ty)
      end
    end
    local arrowX = bx + bw - 1
    if self.scroll > 0 then at(UP_ARROW, arrowX, by) end
    at(DOWN_ARROW, arrowX, by + bh - 1)
  end

  local function description(self, cols)
    box(0, 12, cols, 6)
    if self:isCancel() then return end
    local text = self:description()
    if not text then return end
    local first, second = text:match("^(.-) (.*)$")
    if not first then first, second = text:match("^(.-)\n(.*)$") end
    at(first or text, 1, 14)
    if second then at(second, 1, 16) end
  end

  local function quantityBox(self, total, cols)
    local tw = 13
    local tx = cols - tw
    box(tx, 15, tw, 3)
    at(TIMES, tx + 1, 16)
    at(("%02d"):format(self.qty), tx + 2, 16)
    at(moneyText(total), tx + 5, 16)
  end

  local function yesNo(self, cols)
    local tw = 6
    local tx = cols - tw
    box(tx, 7, tw, 5)
    at("YES", tx + 2, 8)
    at("NO", tx + 2, 10)
    local choice = self.confirm and self.confirm.choice or 1
    cursor(tx + 1, choice == 1 and 8 or 10)
  end

  local function overlays(self, cols)
    local phase = self.phase
    if phase == "buyQuantity" and not (self.message or self.confirm) then
      textBox(self.text and self.text.howMany, cols)
      quantityBox(self, MartMenu.buyPrice(self.qtyItem.price, self.qty), cols)
    end
    if self.message then
      textBox(self.message.pages[self.message.page], cols)
      if self.message.page < #self.message.pages then
        at(DOWN_ARROW, cols - 2, 17)
      end
    elseif self.confirm then
      textBox(self.confirm.pages[self.confirm.page], cols)
      if self.confirm.page >= #self.confirm.pages then
        yesNo(self, cols)
      end
    end
  end

  local function drawWide(self)
    local cols = COLS
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local phase = self.phase
    if phase == "top" then
      topMenu(self)
      textBox(self.topLines, cols)
    elseif phase == "buy" or phase == "buyQuantity" then
      moneyBox(self, cols)
      buyList(self, cols)
      description(self, cols)
    else
      love.graphics.setColor(1, 1, 1, 1)
    end
    overlays(self, cols)
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function drawClassicCentered(self)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.push()
    love.graphics.translate(math.floor((W - CLASSIC_W) / 2), 0)
    ctx.setForceWide(false)
    origDraw(self)
    ctx.setForceWide(true)
    love.graphics.pop()
  end

  function MartMenu:draw()
    if not ctx.isWideNow(self) then
      return origDraw(self)
    end
    local phase = self.phase
    if phase == "sell" or phase == "sellQuantity" then
      return drawClassicCentered(self)
    end
    return drawWide(self)
  end
end
