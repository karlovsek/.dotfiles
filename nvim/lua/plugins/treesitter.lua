-- Neovim 0.12+ has tree-sitter built in. The archived nvim-treesitter plugin
-- is no longer needed for highlighting, folding, or indentation — only for
-- parser installation. We use tree-sitter-manager.nvim as a lightweight
-- replacement.
--
-- Note: parser downloads may require the curl and tar wrappers in ~/.local/bin/
-- which are installed by install-minimal.sh (for FUSE/container environments).

return {
  -- Disable the archived nvim-treesitter (pulled in by LazyVim defaults)
  { "nvim-treesitter/nvim-treesitter", enabled = false },
  { "nvim-treesitter/nvim-treesitter-textobjects", enabled = false },

  -- Lightweight parser manager for Neovim 0.12+
  {
    "romus204/tree-sitter-manager.nvim",
    config = function()
      require("tree-sitter-manager").setup({
        ensure_installed = {
          "bash",
          "c",
          "diff",
          "html",
          "javascript",
          "jsdoc",
          "json",
          "jsonc",
          "lua",
          "luadoc",
          "luap",
          "markdown",
          "markdown_inline",
          "printf",
          "python",
          "query",
          "regex",
          "toml",
          "tsx",
          "typescript",
          "vim",
          "vimdoc",
          "xml",
          "yaml",
        },
      })
    end,
  },
}
