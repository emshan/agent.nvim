local M = {}

M.last_request = nil
M.last_response = nil
M.last_error = nil

local debug_bufnr = nil
local debug_winid = nil

local function create_debug_buffer()
  if debug_bufnr and vim.api.nvim_buf_is_valid(debug_bufnr) then
    return debug_bufnr
  end

  debug_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(debug_bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(debug_bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(debug_bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(debug_bufnr, "filetype", "markdown")
  vim.api.nvim_buf_set_name(debug_bufnr, "claude-review-debug")

  return debug_bufnr
end

local function format_debug_content()
  local lines = {
    "# Claude Review Debug Info",
    "",
    "## Last Request",
    "```",
  }

  if M.last_request then
    vim.list_extend(lines, vim.split(M.last_request, "\n"))
  else
    table.insert(lines, "(no request yet)")
  end

  table.insert(lines, "```")
  table.insert(lines, "")
  table.insert(lines, "## Last Response")
  table.insert(lines, "```json")

  if M.last_response then
    vim.list_extend(lines, vim.split(M.last_response, "\n"))
  else
    table.insert(lines, "(no response yet)")
  end

  table.insert(lines, "```")
  table.insert(lines, "")

  if M.last_error then
    table.insert(lines, "## Last Error")
    table.insert(lines, "```")
    table.insert(lines, M.last_error)
    table.insert(lines, "```")
  end

  return lines
end

function M.toggle()
  if debug_winid and vim.api.nvim_win_is_valid(debug_winid) then
    vim.api.nvim_win_close(debug_winid, true)
    debug_winid = nil
    return
  end

  local bufnr = create_debug_buffer()
  local lines = format_debug_content()

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local width = math.floor(vim.o.columns * 0.4)
  local height = vim.o.lines - 2

  debug_winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    col = vim.o.columns - width,
    row = 0,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_win_set_option(debug_winid, "wrap", false)
  vim.api.nvim_win_set_option(debug_winid, "number", false)
  vim.api.nvim_win_set_option(debug_winid, "relativenumber", false)

  vim.api.nvim_buf_set_keymap(
    bufnr,
    "n",
    "q",
    "<cmd>close<cr>",
    { noremap = true, silent = true }
  )
end

function M.refresh()
  vim.schedule(function()
    if not debug_winid or not vim.api.nvim_win_is_valid(debug_winid) then
      return
    end

    local bufnr = vim.api.nvim_win_get_buf(debug_winid)
    local lines = format_debug_content()

    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  end)
end

function M.store_request(prompt)
  M.last_request = prompt
  M.last_response = nil
  M.last_error = nil
  M.refresh()
end

function M.store_response(response, err)
  if err then
    M.last_error = err
  else
    M.last_response = response
  end
  M.refresh()
end

return M
