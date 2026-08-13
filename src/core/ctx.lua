local Renderer = require("src.render.Renderer")
local Font = require("src.render.Font")
local WideBattle = require("src.battle.WideBattle")

local W, H = WideBattle.WIDTH, WideBattle.HEIGHT -- 304, 144
local COLS = math.floor(W / 8) -- 38
local CLASSIC_W = Renderer.WIDTH

local function colsNow()
  return math.floor(select(1, Renderer:uiSize()) / 8)
end

local function wordWrap(text, width)
  text = tostring(text or "")
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    if #line == 0 then
      line = word
    elseif #line + 1 + #word <= width then
      line = line .. " " .. word
    else
      lines[#lines + 1] = line
      line = word
    end
  end
  if #line > 0 then lines[#lines + 1] = line end
  if #lines == 0 then lines[1] = "" end
  return lines
end

local function drawTruncated(text, x, y, cols)
  text = tostring(text or "")
  if #text > cols then text = text:sub(1, cols) end
  Font.draw(text, x, y)
end

local function classicBattleUnder(game)
  local stack = game and game.stack
  if not stack then return false end
  for i = #stack.states, 1, -1 do
    local s = stack.states[i]
    if s and type(s.wideLayout) == "function" then
      return not s:wideLayout()
    end
  end
  return false
end

local function opaqueWideParent(game, self)
  local stack = game and game.stack
  if not stack then return nil end
  for i = #stack.states, 1, -1 do
    local s = stack.states[i]
    if s and s ~= self and s.isOpaque and s.isWideMenuLayout then
      return s
    end
  end
  return nil
end

local function menuUiSize(self)
  if self and classicBattleUnder(self.game) then
    return CLASSIC_W, Renderer.HEIGHT
  end
  return W, H
end

-- Overlays must not snap the canvas back to 160 while a wide list is underneath.
local function inheritWideUiSize(self)
  if self and classicBattleUnder(self.game) then
    return CLASSIC_W, Renderer.HEIGHT
  end
  local parent = opaqueWideParent(self and self.game, self)
  if parent and not parent.isClassicCenteredOnWide then
    return W, H
  end
  return CLASSIC_W, Renderer.HEIGHT
end

local function claimWide(target)
  if type(target) ~= "table" then return end
  target.isWideMenuLayout = true
  target.uiSize = menuUiSize
end

return {
  W = W, H = H, COLS = COLS, CLASSIC_W = CLASSIC_W,
  Renderer = Renderer, Font = Font,
  colsNow = colsNow, wordWrap = wordWrap, drawTruncated = drawTruncated,
  classicBattleUnder = classicBattleUnder,
  opaqueWideParent = opaqueWideParent,
  menuUiSize = menuUiSize, inheritWideUiSize = inheritWideUiSize,
  claimWide = claimWide,
}
