-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

if vim.g.neovide then
  -- Put anything you want to happen only in Neovide here
  vim.o.guifont = "DejaVuSansM Nerd Font:h11" -- text below applies for VimScript
end

-- Disable relative numbers
vim.opt.relativenumber = false

local toggle_rnu_insert = vim.api.nvim_create_augroup("toggle_rnu_insert", { clear = true })

vim.api.nvim_create_autocmd("InsertEnter", {
  group = toggle_rnu_insert,
  pattern = "*.*",
  command = "setlocal relativenumber",
})

vim.api.nvim_create_autocmd("InsertLeave", {
  group = toggle_rnu_insert,
  pattern = "*.*",
  command = "setlocal norelativenumber",
})

vim.o.clipboard = "unnamedplus"

local function paste()
  return {
    vim.fn.split(vim.fn.getreg(""), "\n"),
    vim.fn.getregtype(""),
  }
end

local function is_windows()
    return vim.loop.os_uname().sysname:find("Windows") ~= nil
end

if is_windows() then
    -- On Windows, we typically want the native clipboard integration
    -- This allows Neovim to use win32yank or the system provider automatically
    vim.opt.clipboard = "unnamedplus"
else
    -- On Linux/Remote, use your OSC 52 configuration
    vim.g.clipboard = {
        name = "OSC 52",
        copy = {
            ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
            ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
            [""] = require("vim.ui.clipboard.osc52").copy(""),
        },
        paste = {
            ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
            ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
        },
    }
end
