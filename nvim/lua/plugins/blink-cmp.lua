return {
  {
    "saghen/blink.cmp",

    opts = {
      sources = {
        -- adding any nvim-cmp sources here will enable them
        -- with blink.compat
        compat = {},

        default = { "lsp", "path", "snippets", "buffer" },

        cmdline = function()
          local type = vim.fn.getcmdtype()
          -- Search forward and backward
          if type == "/" or type == "?" then
            return { "buffer" }
          end
          -- Commands
          if type == ":" then
            return { "cmdline" }
          end
          return {}
        end,
      },
    },
  },
}
