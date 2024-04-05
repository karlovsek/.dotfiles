return {
  "stevearc/conform.nvim",
  opts = {
    formatters = {
      shfmt = {
        extra_args = { "-i", "2", "-ci", "-bn" },
      },
    },
  },
}
