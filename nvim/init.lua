-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.cmd("set runtimepath^=~/.vim runtimepath+=~/.vim/after")
vim.o.packpath = vim.o.runtimepath
vim.cmd("source ~/.vimcommon")

require("telescope").setup({
  defaults = {
    vimgrep_arguments = {
      "rg",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
      "--follow",
    },
  },
  pickers = {
    find_files = {
      follow = true,
    },
  },
})

