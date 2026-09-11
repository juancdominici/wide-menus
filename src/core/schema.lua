-- Per-screen wide toggles. Defaults match the previous always-on behavior.
-- Loaded from main.lua via mod:read so an RBY or GSC boot can see it.
return {
  { key = "rby_options",  label = "RBY OPTIONS",  type = "toggle", default = true },
  { key = "rby_bag",      label = "RBY BAG",      type = "toggle", default = true },
  { key = "rby_shop",     label = "RBY SHOP",     type = "toggle", default = true },
  { key = "rby_pokedex",  label = "RBY POKéDEX",  type = "toggle", default = true },
  { key = "rby_party",    label = "RBY PARTY",    type = "toggle", default = true },
  { key = "rby_controls", label = "RBY CONTROLS", type = "toggle", default = true },
  { key = "gs_options",  label = "GSC OPTIONS", type = "toggle", default = true },
  { key = "gs_mart",     label = "GSC MART",    type = "toggle", default = true },
  { key = "gs_party",    label = "GSC PARTY",    type = "toggle", default = true },
  { key = "manager",     label = "MOD MANAGER", type = "toggle", default = true },
  { key = "others",      label = "OTHER MODS",  type = "toggle", default = true },
}
