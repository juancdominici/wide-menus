-- Dialogue / YES-NO / quantity stay on the classic grid unless a wide
-- parent list is underneath. Menu.new grows to this menu's canvas, not
-- Renderer leftover from the previous frame (START reopen after party).

return function(ctx)
  local Font, Theme = ctx.Font, require("src.ui.Theme")
  local Menu = require("src.ui.Menu")
  local QuantityBox = require("src.ui.QuantityBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local TextBox = require("src.render.TextBox")
  local CLASSIC_W = ctx.CLASSIC_W
  local colsNow, opaqueWideParent = ctx.colsNow, ctx.opaqueWideParent
  local inheritWideUiSize = ctx.inheritWideUiSize

  Theme.cols = CLASSIC_W / 8
  if Theme.textBox then
    Theme.textBox.tw = 20
    Theme.textBox.maxCols = 18
    Theme.textBox.tx = Theme.textBox.tx or 0
  end
  if Theme.choiceBox then
    Theme.choiceBox.tx = 14
    Theme.choiceBox.tw = Theme.choiceBox.tw or 6
  end

  Menu.uiSize = inheritWideUiSize
  QuantityBox.uiSize = inheritWideUiSize
  ChoiceBox.uiSize = inheritWideUiSize
  TextBox.uiSize = inheritWideUiSize

  function QuantityBox:draw()
    local tw = self.unitPrice and 13 or 5
    local tx = colsNow() - tw
    local ty = 9
    Font.drawBox(tx, ty, tw, 3)
    love.graphics.setColor(0, 0, 0, 1)
    local s = ("×%02d"):format(self.qty)
    if self.unitPrice then
      s = s .. (" ¥%d"):format(self.qty * self.unitPrice)
    end
    Font.draw(s, (tx + 1) * 8, (ty + 1) * 8)
    love.graphics.setColor(1, 1, 1, 1)
  end

  local origChoiceDraw = ChoiceBox.draw
  function ChoiceBox:draw()
    local parent = opaqueWideParent(self.game, self)
    if select(1, ctx.Renderer:uiSize()) > CLASSIC_W and parent
        and not parent.isClassicCenteredOnWide then
      self.tx = colsNow() - self.tw
    end
    return origChoiceDraw(self)
  end

  local origMenuNew = Menu.new
  function Menu.new(game, items, opts)
    opts = opts or {}
    local self = origMenuNew(game, items, opts)
    -- inheritWideUiSize, not colsNow(): after party/dex pop, Renderer is
    -- still 304 until the next draw, and topright would land at column 27.
    local limit = math.floor(select(1, inheritWideUiSize(self)) / 8)
    if limit < 20 then limit = 20 end
    local widest = 0
    for _, it in ipairs(items or {}) do
      if it.label then
        local n = #Font.split(it.label)
        if n > widest then widest = n end
      end
    end
    local needed = widest + 3
    if needed > self.tw then self.tw = math.min(needed, limit) end
    if self.tx + self.tw > limit then
      self.tx = math.max(0, limit - self.tw)
    end
    if opts.anchor == "topright" or (opts.tx or 0) >= 9 then
      self.tx = math.max(0, limit - self.tw)
    end
    return self
  end
end
