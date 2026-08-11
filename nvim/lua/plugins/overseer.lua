return {
  "stevearc/overseer.nvim",
  cmd = { "OverseerRun", "OverseerToggle", "OverseerInfo" },
  keys = {
    { "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task" },
    { "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Task panel" },
  },
  opts = {},
}
