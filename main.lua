-- Wide Menus: stretch text-heavy list / options surfaces to the same
-- 304x144 canvas as BATTLE LAYOUT WIDE.
--
-- Full-bleed wide: OPTIONS, Mod Manager, bag/shop/dex, Bindings, mod screens.
-- Classic-centered on wide: party (and overlays above it).
-- Classic 160: overworld dialogue, naming, trainer card, Oak intro, START.
--
-- Requires engine_internals. Extra .lua files load via mod:read, not require.

return function(mod)
  local loadLua = loadstring or load
  local function loadRel(rel)
    local source = mod:read(rel)
    if not source then
      error(rel .. " missing from " .. tostring(mod.path) .. " -- reinstall")
    end
    local chunk, err = loadLua(source, "@" .. mod.path .. "/" .. rel)
    if not chunk then
      error(rel .. " did not compile: " .. tostring(err))
    end
    return chunk
  end

  local files = {
    "src/core/ctx.lua",
    "src/core/canvas.lua",
    "src/core/api.lua",
    "src/core/claim.lua",
    "src/screens/party.lua",
    "src/screens/overlays.lua",
    "src/screens/option_rows.lua",
    "src/screens/list_menu.lua",
    "src/manager/manager.lua",
    "src/manager/manager_pages.lua",
    "src/manager/manager_overlay.lua",
  }
  local compiled = {}
  for i, rel in ipairs(files) do
    compiled[i] = loadRel(rel)
  end

  local ctx = compiled[1]()
  for i = 2, #compiled do
    compiled[i]()(ctx)
  end

  for k, v in pairs(ctx.api) do
    mod.exports[k] = v
  end

  mod.log:info("wide menus 0.1.0 (%dx%d, party centered)", ctx.W, ctx.H)
end

