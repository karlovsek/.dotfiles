return {

  "jvgrootveld/telescope-zoxide",
  dependencies = {
    { "nvim-lua/popup.nvim", "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
  },
  keys = {
    {
      "<leader>cd",
      function()
        require("telescope").extensions.zoxide.list()
        -- require("telescope").extensions.zoxide.list({picker_opts})
      end,
      desc = "Zoxide list",
    },
  },
}
