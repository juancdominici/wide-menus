-- Standalone: luajit mods/wide-menus/tests/ui_mod_api_test.lua
-- The export surface other native-menu mods consume.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Screens = require("src.ui.Screens")
local StateStack = require("src.core.StateStack")
local ListMenu = require("src.ui.ListMenu")

local run = T.sdk.loadMod("mods/wide-menus")
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local api = run.loader.exports["wide-menus"]
T.check(api ~= nil, "publishes exports")
T.eq(api.WIDTH, 304, "WIDTH is the wide canvas")
T.eq(api.COLS, 38, "COLS matches 304/8")
T.eq(api.CLASSIC_WIDTH, 160, "CLASSIC_WIDTH is the GB surface")
T.check(type(api.claim) == "function", "claim is exported")
T.check(type(api.register) == "function", "register is exported")
T.check(ListMenu.isWideMenuLayout, "native ListMenu is claimed automatically")

local PartyMenu = require("src.ui.PartyMenu")
T.check(PartyMenu.isWideMenuLayout, "native PartyMenu is claimed automatically")
T.check(not PartyMenu.isClassicCenteredOnWide, "PartyMenu is full-bleed, not centered")

local wrapped = api.wordWrap("one two three four", 8)
T.check(#wrapped >= 2, "wordWrap splits a long line")

-- ------- live claim / refuse / centered

local wide = { isOpaque = true, draw = function() end }
api.claim(wide)
T.check(wide.isWideMenuLayout, "claim marks a custom state wide")
T.check(not wide.isClassicCenteredOnWide, "claim is full-bleed, not centered")
T.eq(api.layoutOf(wide), "wide", "layoutOf reads a claimed state")

local centered = { isOpaque = true, draw = function() end }
api.claimCentered(centered)
T.check(centered.isWideMenuLayout, "claimCentered still owns the wide canvas")
T.check(centered.isClassicCenteredOnWide, "claimCentered keeps classic layout")
T.eq(api.layoutOf(centered), "centered", "layoutOf reads a centered state")

local classic = { isOpaque = true, isWideMenuLayout = true, draw = function() end }
api.refuse(classic)
T.check(not classic.isWideMenuLayout, "refuse opts a state out of wide")
T.eq(api.layoutOf(classic), "classic", "layoutOf reads a refused state")
local cw, ch = classic:uiSize()
T.eq(cw, 160, "refused uiSize stays classic width")
T.eq(ch, 144, "refused uiSize stays classic height")

api.claim(classic)
T.check(classic.isWideMenuLayout, "claim can re-widen a refused state")
T.check(not classic.keepClassicUi, "re-claim clears the opt-out")

-- ------- register + Screens.push

api.register("NativeWide", "wide")
api.register("NativeCentered", { layout = "centered" })
api.register("NativeClassic", "classic")

local data = run.data
data.screens = data.screens or {}
data.screens.NativeWide = { new = function(game)
  return { game = game, isOpaque = true, draw = function() end }
end }
data.screens.NativeCentered = { new = function(game)
  return { game = game, isOpaque = true, draw = function() end }
end }
data.screens.NativeClassic = { new = function(game)
  return { game = game, isOpaque = true, draw = function() end }
end }
data.screens.NativeFlag = {
  new = function(game)
    return { game = game, isOpaque = true, uiModLayout = "centered",
             draw = function() end }
  end,
}

Screens.invalidate()
local function push(id)
  local game = { data = data, stack = setmetatable({}, { __index = StateStack }) }
  game.stack:init()
  return Screens.push(game, id), game
end

local inst = push("NativeWide")
T.check(inst.isWideMenuLayout, "register(wide) is applied on push")
T.check(not inst.isClassicCenteredOnWide, "register(wide) is full-bleed")

inst = push("NativeCentered")
T.check(inst.isClassicCenteredOnWide, "register(centered) is applied on push")

inst = push("NativeClassic")
T.check(not inst.isWideMenuLayout, "register(classic) opts out on push")

inst = push("NativeFlag")
T.check(inst.isClassicCenteredOnWide,
  "uiModLayout on the instance is enough without register")

-- Non-opaque overlay on a wide parent must not snap the canvas to 160
local wideInst, wideGame = push("NativeWide")
local overlay = { game = wideGame, isOpaque = false, draw = function() end }
wideGame.stack:push(overlay)
T.check(type(overlay.uiSize) == "function",
  "overlay on a wide parent gets uiSize")
local ow = overlay:uiSize()
T.eq(ow, 304, "overlay on a wide parent stays on the 304 canvas")
T.check(wideInst.isWideMenuLayout, "wide parent is still marked wide")

-- START reopen: party/dex pop first, then Screens.push(StartMenu). Renderer
-- is still 304 until Game:draw, but the menu itself is classic 160.
local Menu = require("src.ui.Menu")
local Renderer = require("src.render.Renderer")
local origUiSize = Renderer.uiSize
function Renderer:uiSize()
  return 304, 144
end
local start = Menu.new({ stack = { states = {} } }, {
  { label = "POKéDEX" }, { label = "POKéMON" },
}, { tx = 9, ty = 0, tw = 11, anchor = "topright" })
T.eq(start.tx, 9, "START reopen after a wide list stays on the classic grid")

local _, pinGame = push("NativeWide")
local pinned = Menu.new(pinGame, { { label = "DATA" } },
  { tx = 12, ty = 8, tw = 8 })
T.eq(pinned.tx, 30, "right-anchored overlay on a wide list pins to 304")

-- Celadon vending / prize: TextBox on a wide list must dock the full 304
-- box. Stretching Font.drawBox while setUIAnchor stays at 160 tears it.
local TextBox = require("src.render.TextBox")
local Font = require("src.render.Font")
pinGame.renderer = Renderer
local box = TextBox.new(pinGame, "FRESH WATER\npopped out!")
pinGame.stack:push(box)
local anchored, drawn
local origAnchor, origBox = Renderer.setUIAnchor, Font.drawBox
function Renderer:setUIAnchor(x, y, w, h, anchor)
  anchored = { x = x, y = y, w = w, h = h, anchor = anchor }
end
function Font.drawBox(tx, ty, tw, th)
  drawn = { tx = tx, ty = ty, tw = tw, th = th }
end
box:draw()
Renderer.setUIAnchor = origAnchor
Font.drawBox = origBox
T.eq(anchored and anchored.w, 304,
  "TextBox overlay on a wide list docks the full canvas width")
T.eq(drawn and drawn.tw, 38,
  "TextBox overlay on a wide list draws a 38-column box")
T.eq(box.boxTw, 20, "TextBox restores classic tw after draw")
Renderer.uiSize = origUiSize

T.raises(function() api.register("Bad", "huge") end,
  "layout must be", "register rejects an unknown layout")

-- ------- per-screen toggles (all on by default)

local schema = run.loader.optionSchemas["wide-menus"]
T.check(type(schema) == "table" and #schema == 11,
  "defines a toggle per wide screen")
local schemaKeys = {}
for _, row in ipairs(schema) do
  T.eq(row.type, "toggle", row.key .. " is a toggle")
  T.eq(row.default, true, row.key .. " defaults on")
  schemaKeys[row.key] = true
end

local SCREENS = {
  { "Options" .. "Menu", "rby_options" },
  { "BagMenu", "rby_bag" },
  { "ShopMenu", "rby_shop" },
  { "Pokedex" .. "Menu", "rby_pokedex" },
  { "Party" .. "Menu", "rby_party" },
  { "BindingsMenu", "rby_controls" },
  { "Gen2OptionsMenu", "gs_options" },
  { "Gen2MartMenu", "gs_mart" },
  { "Gen2PartyMenu", "gs_party" },
  { "ManagerState", "manager" },
  { "MyModScreen", "others" },
}
for _, pair in ipairs(SCREENS) do
  T.check(schemaKeys[pair[2]], pair[2] .. " is in the schema")
end

local function claimed(id)
  return api.claim({
    screenId = id, isOpaque = true, game = { stack = { states = {} } },
    draw = function() end,
  })
end

for _, pair in ipairs(SCREENS) do
  local id, key = pair[1], pair[2]
  local inst = claimed(id)
  T.eq(select(1, inst:uiSize()), 304, id .. " defaults to the wide canvas")
  run.loader.modOptions["wide-menus"] = { [key] = false }
  T.eq(select(1, inst:uiSize()), 160, id .. " off uses the classic canvas")
  -- A sibling screen must stay wide while this one is off.
  local sibling = claimed(id == "BagMenu" and "ShopMenu" or "BagMenu")
  T.eq(select(1, sibling:uiSize()), 304,
    id .. " off does not collapse a sibling screen")
end

run.loader.modOptions["wide-menus"] = { rby_party = false }
local party = claimed("Party" .. "Menu")
local offGame = { data = data, stack = setmetatable({}, { __index = StateStack }) }
offGame.stack:init()
party.game = offGame
offGame.stack:push(party)
local offOverlay = { game = offGame, isOpaque = false, draw = function() end }
offGame.stack:push(offOverlay)
T.eq(select(1, offOverlay:uiSize()), 160,
  "overlay on a toggled-off parent stays on the classic canvas")

run.loader.modOptions["wide-menus"] = { rby_party = false }
T.eq(select(1, party:uiSize()), 160, "a live off stays classic")
run.loader.modOptions["wide-menus"] = { rby_party = true }
T.eq(select(1, party:uiSize()), 304, "a live on restores the wide canvas")
run.loader.modOptions["wide-menus"] = {}

-- ------- wide party draw (Pokemon Red crash: open party with toggle on)

local Pokemon = require("src.pokemon.Pokemon")
Font.load(data)
local speciesId = (data.pokemon.BULBASAUR and "BULBASAUR")
               or (T.fixtures.ids.species[1])
local liveMon = Pokemon.new(data, speciesId, 5)
local liveGame = {
  data = data,
  save = { party = { liveMon }, options = {} },
  stack = { states = {} },
  partyMenuSavedIndex = 1,
}
local liveParty = PartyMenu.new(liveGame, {})
liveParty.screenId = "Party" .. "Menu"
liveGame.stack.states[1] = liveParty
local savedUiSize = Renderer.uiSize
function Renderer:uiSize()
  return 304, 144
end
T.eq(select(1, liveParty:uiSize()), 304, "live party owns the wide canvas")
local HudTiles = require("src.render.HudTiles")
local seenBar
local realBar = HudTiles.drawHPBar
function HudTiles.drawHPBar(data, tx, ty, mon, barType, grayFill, segments)
  seenBar = { tx = tx, segments = segments }
  return realBar(data, tx, ty, mon, barType, grayFill, segments)
end
local okDraw, errDraw = pcall(function() liveParty:draw() end)
HudTiles.drawHPBar = realBar
T.check(okDraw, "wide PartyMenu:draw runs (" .. tostring(errDraw) .. ")")
T.check(seenBar ~= nil, "wide party draws an HP bar")
T.check(seenBar and seenBar.segments and seenBar.segments > 6,
  "wide party HP bar uses extra segments (got " .. tostring(seenBar and seenBar.segments) .. ")")
local okPal, errPal = pcall(function() return liveParty:sgbPalettes(liveGame) end)
T.check(okPal, "wide PartyMenu:sgbPalettes runs (" .. tostring(errPal) .. ")")
if okPal then
  local zones = liveParty:sgbPalettes(liveGame)
  if type(zones) == "table" and zones[3] then
    T.check(zones[3].w and zones[3].w > 56,
      "wide party expands the HP-bar SGB zone")
  end
end

-- Love NX has no debug library. wrapDraw uses xpcall; party is wrapped on
-- push (it is not in FULLSCREEN_MODULES), so this is the Red crash path.
api.claim(liveParty)
local savedDebug = debug
debug = nil
local okNx, errNx = pcall(function() liveParty:draw() end)
debug = savedDebug
T.check(okNx, "wide PartyMenu:draw works without debug (" .. tostring(errNx) .. ")")

local okGoldMod, GoldOptions = pcall(require, "src.ui.gen2.OptionsMenu")
if okGoldMod and type(GoldOptions) == "table" and type(GoldOptions.new) == "function" then
  local okNew, gold = pcall(GoldOptions.new, GoldOptions, {
    data = data, save = { options = {} }, stack = { states = {} },
  })
  if okNew and type(gold) == "table" then
    gold.screenId = "Gen2OptionsMenu"
    api.claim(gold)
    debug = nil
    local okGoldDraw, errGoldDraw = pcall(function()
      if gold.drawWidescreen then
        gold:drawWidescreen(640, 288)
      else
        gold:draw()
      end
    end)
    debug = savedDebug
    T.check(okGoldDraw,
      "Gold OPTIONS draws without debug (" .. tostring(errGoldDraw) .. ")")
  end
end
Renderer.uiSize = savedUiSize

run.release()
Screens.invalidate()
T.finish("ui_mod_api")
