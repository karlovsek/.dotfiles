-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- vim.api.nvim_set_keymap("i", "jk", "<Esc>", { noremap = true })

vim.keymap.set("n", "<leader>o", require("osc52").copy_operator, { expr = true })
vim.keymap.set("n", "<leader>oo", "<leader>c_", { remap = true })
vim.keymap.set("v", "<leader>o", require("osc52").copy_visual)

