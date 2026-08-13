return function(ctx)
  local Font, Renderer = ctx.Font, ctx.Renderer
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")
  local ListMenu = require("src.ui.ListMenu")
  local H, CLASSIC_W = ctx.H, ctx.CLASSIC_W

  local origListDraw = ListMenu.draw
  function ListMenu:draw()
    local uiw = select(1, Renderer:uiSize())
    if uiw <= CLASSIC_W then
      return origListDraw(self)
    end
    local cols = math.floor(uiw / 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, uiw, H)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(Strings(self.title), 8, 4)
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
      if item.right then
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
      Font.drawBox(cols - moneyTw, 0, moneyTw, 3)
      love.graphics.setColor(0, 0, 0, 1)
      local money = ("¥%d"):format(self.money and self.money() or 0)
      Font.draw(money, uiw - 8 - Font.width(money), 8)
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
