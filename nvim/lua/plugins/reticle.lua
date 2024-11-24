return {
  {
    "tummetott/reticle.nvim",
    event = "VeryLazy", -- optionally lazy load the plugin
    opts = {
      -- add options here if you wish to override the default settings
      -- Define filetypes which are ignored by the plugin
      ignore = {
        cursorline = {
          "DressingInput",
          "FTerm",
          "NvimSeparator",
          "NvimTree",
          "TelescopePrompt",
          "Trouble",
          "snacks_dashboard",
        },
        cursorcolumn = {},
      },
    },
  },
}
