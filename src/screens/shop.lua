-- RBY mart root (BUY/SELL/QUIT): classic drawClerk pins MONEY/¥ to the
-- 160 grid while wrapDraw slides only the box, so the label floats left
-- of an empty frame. Wide: fill 304 and keep money text inside the box.

return function(ctx)
  if ctx.isGen2 then return end
  local ShopMenu = require("src.ui.ShopMenu")
  local Menu = require("src.ui.Menu")
  local Font = ctx.Font
  local Strings = require("src.core.Strings")
  local TextBox = require("src.render.TextBox")
  local H = ctx.H

  local origNew = ShopMenu.new
  function ShopMenu.new(game, stock, onQuit)
    local menu = origNew(game, stock, onQuit)
    local origDraw = menu.draw
    function menu:draw()
      if not ctx.isWideNow(self) then
        return origDraw(self)
      end
      local cols = ctx.colsNow()
      local uiw = cols * 8
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, uiw, H)

      local moneyTw = 9
      local moneyTx = cols - moneyTw
      Font.drawBox(moneyTx, 0, moneyTw, 3)
      love.graphics.rectangle("fill", (moneyTx + 2) * 8, 0, 5 * 8, 8)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(Strings("MONEY"), (moneyTx + 2) * 8, 0)
      local money = ("¥%d"):format((self.game.save and self.game.save.money) or 0)
      -- Classic right-aligns to tile 19 (152px) inside MONEY_BOX 11,0 tw=9.
      local right = (moneyTx + moneyTw - 1) * 8
      Font.draw(money, right - Font.width(money), 8)

      Font.drawBox(0, 12, cols, 6)
      love.graphics.setColor(0, 0, 0, 1)
      if self.footer then
        local flat = {}
        for _, page in ipairs(TextBox.paginate(self.footer, cols - 2)) do
          for _, line in ipairs(page) do flat[#flat + 1] = line end
        end
        local y = 112
        for i = math.max(1, #flat - 1), #flat do
          Font.draw(flat[i], 8, y)
          y = y + 16
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
      Menu.draw(self)
    end
    return menu
  end
end
