local M = {}
local actions = require("claude-review.actions")

local ns = vim.api.nvim_create_namespace("claude-review")

local severity_map = {
  error = vim.diagnostic.severity.ERROR,
  warning = vim.diagnostic.severity.WARN,
  info = vim.diagnostic.severity.INFO,
  hint = vim.diagnostic.severity.HINT,
}

local buffer_diagnostics = {}

local function to_vim_diagnostic(code_action, index)
  local diag = code_action.diagnostic
  return {
    lnum = (diag.line or 1) - 1,
    col = (diag.col or 0) - 1,
    severity = severity_map[diag.severity] or vim.diagnostic.severity.INFO,
    message = diag.message or "",
    source = "claude-review",
    user_data = {
      claude_index = index,
    },
  }
end

function M.set(code_actions)
  local by_file = {}

  actions.store_code_actions(code_actions)

  for idx, code_action in ipairs(code_actions) do
    local file = code_action.diagnostic.file
    if not by_file[file] then
      by_file[file] = {}
    end
    table.insert(by_file[file], to_vim_diagnostic(code_action, idx))
  end

  for file, diags in pairs(by_file) do
    local full_path = vim.fn.fnamemodify(file, ":p")
    local bufnr = vim.fn.bufnr(full_path)

    if bufnr == -1 then
      bufnr = vim.fn.bufadd(full_path)
    end

    buffer_diagnostics[bufnr] = diags
    vim.diagnostic.set(ns, bufnr, diags, {})
  end

  vim.schedule(function()
    vim.notify(
      string.format("Claude review complete: %d code action(s) found", #code_actions),
      vim.log.levels.INFO
    )
  end)
end

function M.dismiss_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  local current_diags = buffer_diagnostics[bufnr] or {}
  local filtered = {}

  for _, diag in ipairs(current_diags) do
    if diag.lnum ~= line then
      table.insert(filtered, diag)
    end
  end

  buffer_diagnostics[bufnr] = filtered
  vim.diagnostic.set(ns, bufnr, filtered, {})

  vim.notify("Dismissed diagnostic at cursor", vim.log.levels.INFO)
end

function M.dismiss_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  buffer_diagnostics[bufnr] = nil
  vim.diagnostic.reset(ns, bufnr)
  vim.notify("Cleared all diagnostics in buffer", vim.log.levels.INFO)
end

function M.dismiss_all()
  for bufnr, _ in pairs(buffer_diagnostics) do
    vim.diagnostic.reset(ns, bufnr)
  end
  buffer_diagnostics = {}
  vim.notify("Cleared all Claude review diagnostics", vim.log.levels.INFO)
end

return M
