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

keymap.set("t", ",,", "<C-\\><C-n>", opts)
keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", opts)
keymap.set("t", "<Esc>h", "<C-\\><C-n>C-w>h<CR>", opts)
keymap.set("t", "<Esc>j", "<C-\\><C-n><C-w>j<CR>", opts)
keymap.set("t", "<Esc>k", "<C-\\><C-n><C-w>k<CR>", opts)
keymap.set("t", "<Esc>l", "<C-\\><C-n><C-w>l<CR>", opts)

vim.keymap.set("n", "<leader>o", require("osc52").copy_operator, { expr = true })
vim.keymap.set("n", "<leader>oo", "<leader>c_", { remap = true })
vim.keymap.set("v", "<leader>o", require("osc52").copy_visual)
