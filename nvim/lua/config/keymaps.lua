-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

keymap.set("n", "VA", "ggVG", opts)

keymap.set("n", "n", "nzz", opts)
keymap.set("n", "N", "Nzz", opts)
keymap.set("n", "*", "*zz", opts)
keymap.set("n", "#", "#zz", opts)
keymap.set("n", "g*", "g*zz", opts)
keymap.set("n", "g#", "g#zz", opts)

vim.keymap.set("n", "<leader>o", require("osc52").copy_operator, { expr = true })
vim.keymap.set("n", "<leader>oo", "<leader>o_", { remap = true })
vim.keymap.set("v", "<leader>o", require("osc52").copy_visual)

vim.keymap.set("n", "<leader>j", "m`o<ESC>``")
vim.keymap.set("n", "<leader>k", "m`O<ESC>``")
