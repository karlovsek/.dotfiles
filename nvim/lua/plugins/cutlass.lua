-- Lua
return {
  "gbprod/cutlass.nvim",
  opts = {
    cut_key = "m",
    exclude = {},
    override_del = nil,
    registers = {
      select = "s",
      -- delete = "d", setting this causes delete to be saved to register
      change = "c",
    },
  },
}
