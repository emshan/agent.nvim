local cli = require("claude-review.cli")
local parser = require("claude-review.parser")
local diagnostics = require("claude-review.diagnostics")
local debug = require("claude-review.debug")
local actions = require("claude-review.actions")

local M = {}

local function show_spinner(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

local function handle_response(raw_output, err)
  vim.schedule(function()
    if err then
      vim.notify("Claude review failed: " .. err, vim.log.levels.ERROR)
      return
    end

    local parsed, parse_err = parser.parse_claude_response(raw_output)
    if parse_err then
      vim.notify("Failed to parse response: " .. parse_err, vim.log.levels.ERROR)
      return
    end

    diagnostics.set(parsed)
  end)
end

function M.review_current_buffer(focus)
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)

  if file_path == "" then
    vim.notify("Cannot review: buffer has no file", vim.log.levels.ERROR)
    return
  end

  local msg = "Claude reviewing: " .. vim.fn.fnamemodify(file_path, ":.")
  if focus and focus ~= "" then
    msg = msg .. " (" .. focus .. ")"
  end
  show_spinner(msg)

  cli.review_file(file_path, focus, handle_response)
end

function M.review_diff(ref)
  ref = ref or "HEAD"

  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)

  if file_path == "" then
    vim.notify("Cannot review diff: buffer has no file", vim.log.levels.ERROR)
    return
  end

  show_spinner(
    string.format(
      "Claude reviewing diff: %s (%s..current)",
      vim.fn.fnamemodify(file_path, ":."),
      ref
    )
  )

  cli.review_diff(file_path, ref, handle_response)
end

function M.dismiss_at_cursor()
  diagnostics.dismiss_at_cursor()
end

function M.dismiss_buffer()
  diagnostics.dismiss_buffer()
end

function M.dismiss_all()
  diagnostics.dismiss_all()
end

function M.toggle_debug()
  debug.toggle()
end

function M.apply_fix()
  actions.apply_fix_at_cursor()
end

function M.preview_fix()
  actions.show_fix_preview()
end

function M.setup(opts)
  opts = opts or {}

  vim.api.nvim_create_user_command("ClaudeReview", function(cmd_opts)
    local focus = cmd_opts.args ~= "" and cmd_opts.args or nil
    M.review_current_buffer(focus)
  end, { nargs = "*" })

  vim.api.nvim_create_user_command("ClaudeReviewDiff", function(cmd_opts)
    local ref = cmd_opts.args ~= "" and cmd_opts.args or "HEAD"
    M.review_diff(ref)
  end, {
    nargs = "?",
    complete = "custom,v:lua.require'claude-review'.git_ref_complete",
  })

  vim.api.nvim_create_user_command("ClaudeReviewDismiss", function()
    M.dismiss_at_cursor()
  end, {})

  vim.api.nvim_create_user_command("ClaudeReviewDismissBuffer", function()
    M.dismiss_buffer()
  end, {})

  vim.api.nvim_create_user_command("ClaudeReviewDismissAll", function()
    M.dismiss_all()
  end, {})

  vim.api.nvim_create_user_command("ClaudeReviewDebug", function()
    M.toggle_debug()
  end, {})

  vim.api.nvim_create_user_command("ClaudeReviewApplyFix", function()
    M.apply_fix()
  end, {})

  vim.api.nvim_create_user_command("ClaudeReviewPreviewFix", function()
    M.preview_fix()
  end, {})
end

function M.git_ref_complete()
  local handle = io.popen("git for-each-ref --format='%(refname:short)' refs/heads refs/tags 2>/dev/null")
  if not handle then
    return ""
  end

  local result = handle:read("*a")
  handle:close()

  return result
end

return M
