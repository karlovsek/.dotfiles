return {
  {
    "carbon-steel/detour.nvim",
    config = function()
      vim.keymap.set("n", "<c-w><enter>", ":Detour<cr>")
    end,
  },
  -- -- A keymap for selecting a terminal buffer to open in a popup
  -- vim.keymap.set("n", "<leader>t", function()
  --   require("detour").Detour() -- Open a detour popup
  --
  --   -- Switch to a blank buffer to prevent any accidental changes.
  --   vim.cmd.enew()
  --   vim.bo.bufhidden = "delete"
  --
  --   require("telescope.builtin").buffers({}) -- Open telescope prompt
  --   vim.api.nvim_feedkeys("term", "n", true) -- popuplate prompt with "term"
  -- end),
}
