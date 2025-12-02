if vim.g.loaded_claude_review then
  return
end
vim.g.loaded_claude_review = true

require("claude-review").setup()
