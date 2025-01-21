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

keymap.set("n", "<leader>o", require("osc52").copy_operator, { expr = true })
keymap.set("n", "<leader>oo", "<leader>o_", { remap = true })
keymap.set("v", "<leader>o", require("osc52").copy_visual)

keymap.set("n", "<leader>j", "m`o<ESC>``")
keymap.set("n", "<leader>k", "m`O<ESC>``")

-- reselect pasted text
keymap.set("n", "<leader>gp", "`[v`]", { desc = "Reselect pasted text" })
