-- Mark which opaque screens own the 304 surface, and which stay classic 160.
-- Other mods opt in/out with state.uiModLayout or exports.register(id, layout).

return function(ctx)
  local claimWide, wrapDraw = ctx.claimWide, ctx.wrapDraw
  local Screens = require("src.ui.Screens")
  local StateStack = require("src.core.StateStack")

  local FULLSCREEN_MODULES = {
    "src.ui.ListMenu",
    "src.ui.OptionsMenu",
    "src.ui.BagMenu",
    "src.ui.ShopMenu",
    "src.ui.PokedexMenu",
    "src.ui.BindingsMenu",
    "src.mods.ManagerState",
    -- Gold pack/dex gfx is 160; mart buy is laid out in screens/mart.lua.
    "src.ui.gen2.MartMenu",
    "src.ui.gen2.OptionsMenu",
    "src.ui.gen2.PartyMenu",
  }

  local DENY_MOD_WIDE = {
    NamingScreen = true, OakSpeech = true, TrainerCard = true,
    SummaryMenu = true, DexEntryMenu = true, TownMap = true, Diploma = true,
    Gen2NamingScreen = true, Gen2OakSpeech = true, Gen2TrainerCard = true,
    Gen2SummaryMenu = true, Gen2Diploma = true,
  }

  -- Pair Gen 1 ids with the Gen2-prefixed ids Gold actually pushes.
  local ALLOW_WIDE = {
    OptionsMenu = true, Gen2OptionsMenu = true,
    ManagerState = true,
    BagMenu = true,
    ShopMenu = true, Gen2MartMenu = true,
    PokedexMenu = true,
    BindingsMenu = true,
    PartyMenu = true, Gen2PartyMenu = true,
  }

  for _, name in ipairs(FULLSCREEN_MODULES) do
    local ok, M = pcall(require, name)
    if ok then
      claimWide(M)
      wrapDraw(M)
    end
  end

  local function autoLayout(id, inst, factory)
    local layout = ctx.resolveLayout(id, inst)
    if layout then return layout end
    if not inst or not inst.isOpaque then return nil end
    if DENY_MOD_WIDE[id] then return nil end
    if (factory and factory.__modOwned) or ALLOW_WIDE[id] then return "wide" end
    return nil
  end

  local origScreensPush = Screens.push
  function Screens.push(game, id, ...)
    local factory = Screens.get(game, id)
    local inst = origScreensPush(game, id, ...)
    if not inst then return inst end
    local layout = autoLayout(id, inst, factory)
    if layout then ctx.applyLayout(inst, layout) end
    return inst
  end

  local KEEP_CLASSIC = {
    TitleState = true, OverworldController = true, BattleState = true,
    TextBox = true, ChoiceBox = true, NamingScreen = true,
    OakSpeech = true, TrainerCard = true, SummaryMenu = true,
    DexEntryMenu = true, TownMap = true, Diploma = true, Credits = true,
    IntroMovie = true, YellowIntro = true, HallOfFame = true,
    EvolutionState = true, TradeAnim = true, SlotMachine = true,
    QuarantineReport = true, BoxMenu = true, MoveLearnMenu = true,
    PlayerPC = true, FlyMenu = true, QuantityBox = true, PicBox = true,
    StartMenu = true,
    Gen2TitleState = true, Gen2BattleState = true, Gen2StartMenu = true,
    Gen2BoxMenu = true, Gen2PcMenu = true, Gen2Credits = true,
    Gen2HallOfFame = true, Gen2SlotMachine = true, Gen2TradeAnim = true,
    Gen2MainMenu = true, Gen2SaveMenu = true, Gen2Pokegear = true,
    Gen2CopyrightSplash = true, Gen2GameFreakPresents = true,
    Gen2GoldSilverIntro = true, Gen2InitClock = true, Gen2NamePick = true,
    Gen2PackMenu = true, Gen2PokedexMenu = true,
  }
  for k, v in pairs(DENY_MOD_WIDE) do KEEP_CLASSIC[k] = v end

  local inheritWideUiSize = ctx.inheritWideUiSize
  local opaqueWideParent = ctx.opaqueWideParent

  local origStackPush = StateStack.push
  function StateStack:push(state, ...)
    origStackPush(self, state, ...)
    if type(state) ~= "table" then return end
    -- Transparent overlays (MoveRelearn, TextBox, forget list) must keep
    -- the 304 surface when a wide menu is underneath; otherwise Game:draw
    -- snaps to 160 and the party letterboxes again.
    if not state.isOpaque then
      if state.keepClassicUi then return end
      if not state.uiSize then
        state.uiSize = inheritWideUiSize
      end
      local parent = opaqueWideParent(state.game, state)
      if parent and not parent.isClassicCenteredOnWide then
        -- wrapDraw shifts Gold overlay boxes (GIVE/TAKE) without the labels.
        ctx.installWidescreen(state)
      end
      return
    end
    local id = state.screenId
    local layout = ctx.resolveLayout(id, state)
    if not layout then
      if state.isWideMenuLayout then return end
      if not id or KEEP_CLASSIC[id] then return end
      -- Gold cinema/clock/pack are opaque and must stay 160. Unknown Gen 2
      -- screens default classic; Gen 1 still widens other mods' menus.
      if ctx.isGen2 and not ALLOW_WIDE[id] then return end
      layout = "wide"
    end
    ctx.applyLayout(state, layout)
  end
end
