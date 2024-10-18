local lazy = require("lazy")
return {
  "akinsho/toggleterm.nvim",
  config = function()
    require("toggleterm").setup({
      -- open_mapping = [[<leader>t]],
      insert_mappings = false,
      shade_terminals = false,
      -- add --login so ~/.zprofile is loaded
      -- https://vi.stackexchange.com/questions/16019/neovim-terminal-not-reading-bash-profile/16021#16021
      shell = "zsh --login",
      -- function to run on opening the terminal
      on_open = function(term)
        vim.cmd("startinsert!")
        vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
      end,
    })
  end,
  lazy = false,
  keys = {
    { "<leader>t", "<Cmd>ToggleTerm<CR>", "ToggleTerm" },
    { "<leader><leader>t", "<Cmd>1ToggleTerm<Cr>", desc = "Terminal mini" },
    {
      "<leader>T",
      "<cmd>2ToggleTerm dir=~ direction=float<cr>",
      desc = "Open a horizontal terminal at the Desktop directory",
    },
  },
}
