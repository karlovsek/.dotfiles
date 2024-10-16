return {
  "stevearc/conform.nvim",
  opts = {
    formatters = {
      shfmt = {
        prepend_args = { "-i", "2", "-ci", "-bn" },
      },
    },
    formatters_by_ft = {
      xml = { "xmllint" },
      sh = { "shfmt" },
    },
  },
}
