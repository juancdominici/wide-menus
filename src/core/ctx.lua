local Renderer = require("src.render.Renderer")
local Font = require("src.render.Font")
local WideBattle = require("src.battle.WideBattle")
local GameVersion = require("src.core.GameVersion")
local Game = require("src.core.Game")

local W, H = WideBattle.WIDTH, WideBattle.HEIGHT -- 304, 144
local COLS = math.floor(W / 8) -- 38
local CLASSIC_W = Renderer.WIDTH
-- Gold's Game require is an empty proxy (pairs/next see nothing). That is
-- also how the headless SDK marks a Gen 2 load without setting GameVersion.
local isGen2 = (GameVersion.generation and GameVersion.generation() == 2)
            or (GameVersion.isGold and GameVersion.isGold())
            or next(Game) == nil
            or false

-- Set while a Gold drawWidescreen is painting the 304 panel, so draw()
-- uses the wide layout even though Renderer stays at 160.
local forceWide = false

local function colsNow()
  if forceWide then return COLS end
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

-- Screen id -> options.lua key. Unlisted claimed screens use "others".
local SCREEN_KEYS = {
  OptionsMenu = "rby_options",
  BagMenu = "rby_bag",
  ShopMenu = "rby_shop",
  PokedexMenu = "rby_pokedex",
  PartyMenu = "rby_party",
  BindingsMenu = "rby_controls",
  Gen2OptionsMenu = "gs_options",
  Gen2MartMenu = "gs_mart",
  Gen2PartyMenu = "gs_party",
  ManagerState = "manager",
}

local ctx

local function optionOn(key)
  if type(ctx.getOption) ~= "function" then return true end
  local v = ctx.getOption(key)
  if v == nil then return true end
  return v and true or false
end

local function optionKey(state)
  local id = type(state) == "string" and state
          or (type(state) == "table" and state.screenId)
  return SCREEN_KEYS[id] or "others"
end

local function layoutEnabled(state)
  if type(state) ~= "table" then return true end
  if state.keepClassicUi then return false end
  return optionOn(optionKey(state))
end

local function opaqueWideParent(game, self)
  local stack = game and game.stack
  if not stack then return nil end
  for i = #stack.states, 1, -1 do
    local s = stack.states[i]
    if s and s ~= self and s.isOpaque and s.isWideMenuLayout
        and layoutEnabled(s) then
      return s
    end
  end
  return nil
end

local function menuUiSize(self)
  if self and classicBattleUnder(self.game) then
    return CLASSIC_W, Renderer.HEIGHT
  end
  if self and not layoutEnabled(self) then
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

local function isWideNow(self)
  if forceWide then return true end
  if self and classicBattleUnder(self.game) then return false end
  if self and self.isOpaque and not layoutEnabled(self) then return false end
  -- Gold's stack:draw blit is still the 160 panel; only drawWidescreen
  -- (forceWide) paints 304.
  if isGen2 then return false end
  return select(1, Renderer:uiSize()) > CLASSIC_W
end

local function claimWide(target)
  if type(target) ~= "table" then return end
  target.isWideMenuLayout = true
  target.uiSize = menuUiSize
end

ctx = {
  W = W, H = H, COLS = COLS, CLASSIC_W = CLASSIC_W,
  Renderer = Renderer, Font = Font, isGen2 = isGen2,
  colsNow = colsNow, wordWrap = wordWrap, drawTruncated = drawTruncated,
  classicBattleUnder = classicBattleUnder,
  opaqueWideParent = opaqueWideParent,
  menuUiSize = menuUiSize, inheritWideUiSize = inheritWideUiSize,
  isWideNow = isWideNow, claimWide = claimWide,
  optionOn = optionOn, optionKey = optionKey, layoutEnabled = layoutEnabled,
  setForceWide = function(on) forceWide = on and true or false end,
}
return ctx
