return {
  {
    {
      "m00qek/baleia.nvim",
      config = function()
        vim.g.conjure_baleia = require("baleia").setup({ line_starts_at = 3 })

        vim.api.nvim_create_user_command("BaleiaColorize", function()
          vim.g.conjure_baleia.once(vim.api.nvim_get_current_buf())
        end, { bang = true })
      end,
    },
  },
}
