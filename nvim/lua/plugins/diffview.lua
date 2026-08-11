return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view (working tree)" },
    { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (current file)" },
  },
}
