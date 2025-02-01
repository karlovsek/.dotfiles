-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.cmd([[autocmd TermOpen,TermEnter,BufWinEnter,WinEnter term://* startinsert]])

vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function()
    local ft = vim.bo.filetype
    if ft == "cpp" or ft == "c" or ft == "hpp" then -- Check for multiple filetypes
      vim.bo.commentstring = "// %s"
    end
  end,
})
