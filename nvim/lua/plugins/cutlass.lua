-- Lua
return {
  "gbprod/cutlass.nvim",
  lazy = false,
  opts = {
    cut_key = "m",
    override_del = nil,
    exclude = {},
    registers = {
      select = "s",
      delete = "d",
      change = "c",
    },
  },
}
