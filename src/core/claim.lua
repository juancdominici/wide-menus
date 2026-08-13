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
  }

  local DENY_MOD_WIDE = {
    NamingScreen = true, OakSpeech = true, TrainerCard = true,
    SummaryMenu = true, DexEntryMenu = true, TownMap = true, Diploma = true,
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
    local allowed = id == "OptionsMenu" or id == "ManagerState"
      or id == "BagMenu" or id == "ShopMenu" or id == "PokedexMenu"
      or id == "BindingsMenu" or id == "PartyMenu"
    if (factory and factory.__modOwned) or allowed then return "wide" end
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
        wrapDraw(state)
      end
      return
    end
    local id = state.screenId
    local layout = ctx.resolveLayout(id, state)
    if not layout then
      if state.isWideMenuLayout then return end
      if not id or KEEP_CLASSIC[id] then return end
      layout = "wide"
    end
    ctx.applyLayout(state, layout)
  end
end
