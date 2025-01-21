-- This plugin provides a convenient solution for configuring the cursorline and cursorcolumn
-- settings to meet your specific needs, granting you complete control over when they are displayed and when they are not.

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
          "snacks_terminal",
          "snacks_picker_input",
        },
        cursorcolumn = {},
      },
    },
  },
}
