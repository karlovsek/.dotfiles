-- Return a configuration table for the 'saghen/blink.cmp' plugin.
return {
  "saghen/blink.cmp", -- Plugin name
  dependencies = { -- List of required plugins
    "rafamadriz/friendly-snippets", -- Provides additional code snippets
    "onsails/lspkind.nvim", -- Adds icons to completion items
  },
  version = "*", -- Use the latest version

  -- Type annotations for documentation and better tooling support
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    appearance = { -- Appearance-related settings
      use_nvim_cmp_as_default = false, -- Disable using nvim-cmp as the default completion
      nerd_font_variant = "mono", -- Set the Nerd Font variant to "mono"
    },

    completion = { -- Configuration for the completion behavior
      accept = {
        auto_brackets = { enabled = true }, -- Automatically add closing brackets
      },
      documentation = { -- Documentation popup behavior
        auto_show = true, -- Automatically show documentation
        auto_show_delay_ms = 250, -- Delay before showing documentation (in ms)
        treesitter_highlighting = true, -- Use Tree-sitter for syntax highlighting in documentation
        window = { border = "rounded" }, -- Set rounded borders for the documentation window
      },
      list = {
        selection = { preselect = false, auto_insert = true },
      },
      menu = { -- Configuration for the completion menu
        border = "rounded", -- Set rounded borders
        cmdline_position = function() -- Customize cmdline menu position
          if vim.g.ui_cmdline_pos ~= nil then
            -- Use global variable if set (1-based indexing, converted to 0-based)
            local pos = vim.g.ui_cmdline_pos
            return { pos[1] - 1, pos[2] }
          end
          -- Default to bottom of the window with appropriate height
          local height = (vim.o.cmdheight == 0) and 1 or vim.o.cmdheight
          return { vim.o.lines - height, 0 }
        end,
        draw = { -- Define how the menu is drawn
          columns = { -- Specify menu columns
            { "kind_icon", "label", gap = 1 }, -- Icon and label with a gap
            { "kind" }, -- Kind column
          },
          components = { -- Define menu components
            kind_icon = { -- Icon component
              text = function(item)
                local kind = require("lspkind").symbol_map[item.kind] or ""
                return kind .. " " -- Add a space after the icon
              end,
              highlight = "CmpItemKind", -- Highlight group
            },
            label = { -- Label component
              text = function(item)
                return item.label -- Display the item's label
              end,
              highlight = "CmpItemAbbr", -- Highlight group
            },
            kind = { -- Kind component
              text = function(item)
                return item.kind -- Display the item's kind
              end,
              highlight = "CmpItemKind", -- Highlight group
            },
          },
        },
      },
    },

    -- Key mappings for completion and snippet navigation
    keymap = {
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" }, -- Show/hide completion/documentation
      ["<C-e>"] = { "hide", "fallback" }, -- Hide menu or fallback action
      ["<CR>"] = { "accept", "fallback" }, -- Accept the selected item or fallback
      ["<Tab>"] = { -- Handle Tab key behavior
        function(cmp)
          return cmp.select_next()
        end, -- Select next item
        "snippet_forward", -- Navigate forward in a snippet
        "fallback", -- Fallback action
      },
      ["<S-Tab>"] = { -- Handle Shift+Tab behavior
        function(cmp)
          return cmp.select_prev()
        end, -- Select previous item
        "snippet_backward", -- Navigate backward in a snippet
        "fallback", -- Fallback action
      },
      ["<Up>"] = { "select_prev", "fallback" }, -- Navigate up or fallback
      ["<Down>"] = { "select_next", "fallback" }, -- Navigate down or fallback
      ["<C-p>"] = { "select_prev", "fallback" }, -- Select previous or fallback
      ["<C-n>"] = { "select_next", "fallback" }, -- Select next or fallback
      ["<C-up>"] = { "scroll_documentation_up", "fallback" }, -- Scroll up in documentation
      ["<C-down>"] = { "scroll_documentation_down", "fallback" }, -- Scroll down in documentation
    },

    -- Signature help settings
    signature = {
      enabled = true, -- Enable signature help
      window = { border = "rounded" }, -- Set rounded borders for the signature help window
    },

    sources = { -- Define completion sources
      default = { "lsp", "path", "snippets", "buffer" }, -- Default sources for completion

      min_keyword_length = function(ctx)
        return ctx.trigger.kind == "manual" and 0 or 2
      end,

      cmdline = function()
        local type = vim.fn.getcmdtype()
        -- Search forward and backward
        if type == "/" or type == "?" then
          return { "buffer" }
        end
        -- Commands
        if type == ":" then
          return { "cmdline" }
        end
        return {}
      end,

      providers = { -- Configure individual source behavior
        lsp = {
          min_keyword_length = 3, -- Minimum characters to trigger completion
          score_offset = 0, -- Adjust score for LSP items
        },
        path = {
          min_keyword_length = 0, -- No minimum length for path completion
          max_items = 100,
        },
        snippets = {
          min_keyword_length = 3, -- Minimum characters to trigger snippets
        },
        buffer = {
          -- min_keyword_length = 3, -- Minimum characters for buffer suggestions
          max_items = 7, -- Limit the number of buffer suggestions
        },
      },
    },
  },
}
