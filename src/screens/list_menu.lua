return function(ctx)
  local Font = ctx.Font
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")
  local ListMenu = require("src.ui.ListMenu")
  local H = ctx.H

  local origListDraw = ListMenu.draw
  function ListMenu:draw()
    if not ctx.isWideNow(self) then
      return origListDraw(self)
    end
    local cols = math.floor(ctx.W / 8)
    local uiw = ctx.W
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    love.graphics.setColor(0, 0, 0, 1)
    -- Mart buy/sell lists pass a nil title (ShopMenu); bag/dex pass one.
    if self.title then
      Font.draw(Strings(self.title), 8, 4)
    end
    if #self.items == 0 then
      Font.draw(Strings("Nothing here."), 16, 64)
    end
    for row = 1, self.rows do
      local i = self.scroll + row
      local item = self.items[i]
      if not item then break end
      local y = 8 + row * 16
      Font.draw(item.label, 16, y)
      if item.ball then
        local bx = 16 + Font.width(item.label) + 8 + 3
        local by = y + 3
        love.graphics.circle("fill", bx, by, 3.5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", bx - 3.5, by - 0.5, 7, 1)
        love.graphics.circle("fill", bx, by, 1.2)
        love.graphics.setColor(0, 0, 0, 1)
      end
      -- Shop buy uses price; bag/sell use count; PC/other use right.
      if item.price then
        Font.draw(item.price, uiw - 8 - Font.width(item.price), y)
      elseif item.count then
        local count = tostring(item.count)
        Font.draw("\xc3\x97", uiw - 8 - Font.width(count) - 8, y)
        Font.draw(count, uiw - 8 - Font.width(count), y)
      elseif item.right then
        Font.draw(item.right, uiw - 8 - Font.width(item.right), y)
      end
      if i == self.index then
        Font.drawCode(self.hollowIndex == i
          and Theme.cursorHollow or Theme.cursor, 8, y)
      end
      if self.swapIndex == i and i ~= self.index then
        Font.drawCode(Theme.cursorHollow, 8, y)
      end
    end
    if self.dialogue then
      local moneyTw = 9
      local moneyTx = cols - moneyTw
      Font.drawBox(moneyTx, 0, moneyTw, 3)
      love.graphics.setColor(0, 0, 0, 1)
      local money = ("¥%d"):format(self.money and self.money() or 0)
      -- Match classic 152px right-align inside MONEY_BOX (tile moneyTx+tw-1).
      local right = (moneyTx + moneyTw - 1) * 8
      Font.draw(money, right - Font.width(money), 8)
    end
    if self.dialogue or (self.messageBox and self.footer) then
      Font.drawBox(0, 12, cols, 6)
      love.graphics.setColor(0, 0, 0, 1)
      if self.footer then
        local flat = {}
        for _, page in ipairs(require("src.render.TextBox").paginate(
            self.footer, cols - 2)) do
          for _, line in ipairs(page) do flat[#flat + 1] = line end
        end
        local y = 112
        for i = math.max(1, #flat - 1), #flat do
          Font.draw(flat[i], 8, y)
          y = y + 16
        end
      end
    elseif self.footer then
      local flat = {}
      for _, page in ipairs(require("src.render.TextBox").paginate(
          self.footer, cols - 2)) do
        for _, line in ipairs(page) do flat[#flat + 1] = line end
      end
      local y = (#flat >= 2) and 120 or 136
      for i = math.max(1, #flat - 1), #flat do
        Font.draw(flat[i], 8, y)
        y = y + 16
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end
end
