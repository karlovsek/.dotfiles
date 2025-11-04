return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- 'opts' is the configuration table passed to require('render-markdown').setup()
    opts = {
      heading = {
        enabled = true,
        sign = true, -- Ensure sign is true to display the virtual text icon
        icons = { -- Default icons for H1 to H6
          "󰲡 ",
          "󰲣 ",
          "󰲥 ",
          "󰲧 ",
          "󰲩 ",
          "󰲫 ",
        },
      },
      -- ... other options you might have
    },
  },
}
