-- Standalone: luajit mods/ui-mod/tests/ui_mod_api_test.lua
-- The export surface other native-menu mods consume.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Screens = require("src.ui.Screens")
local StateStack = require("src.core.StateStack")
local ListMenu = require("src.ui.ListMenu")

local run = T.sdk.loadMod("mods/ui-mod")
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local api = run.loader.exports["ui-mod"]
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
T.check(overlay._uiModWideDraw, "overlay on a wide parent is wrapDraw'd")
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
Renderer.uiSize = origUiSize

T.raises(function() api.register("Bad", "huge") end,
  "layout must be", "register rejects an unknown layout")

run.release()
Screens.invalidate()
T.finish("ui_mod_api")
