local M = {}

local ns = vim.api.nvim_create_namespace("claude-review")
local diagnostic_fixes = {}
local code_action_provider_registered = false

function M.store_fixes(diagnostics)
  diagnostic_fixes = {}

  for _, diag in ipairs(diagnostics) do
    if diag.suggested_fix then
      local key = string.format("%s:%d:%d", diag.file, diag.line, diag.col)
      diagnostic_fixes[key] = diag.suggested_fix
    end
  end
end

function M.apply_fix_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  local diagnostics = vim.diagnostic.get(bufnr, { namespace = ns, lnum = line })

  if #diagnostics == 0 then
    vim.notify("No diagnostic at cursor", vim.log.levels.WARN)
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local diag = diagnostics[1]
  local key = string.format("%s:%d:%d", file_path, diag.lnum + 1, diag.col + 1)

  local fix = diagnostic_fixes[key]
  if not fix then
    vim.notify("No suggested fix available for this diagnostic", vim.log.levels.INFO)
    return
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if diag.lnum >= line_count then
    vim.notify("Diagnostic line is out of range", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_line = lines[diag.lnum + 1]

  if not current_line then
    vim.notify("Could not read line content", vim.log.levels.ERROR)
    return
  end

  local new_line
  if fix.old_text and fix.new_text then
    new_line = current_line:gsub(vim.pesc(fix.old_text), fix.new_text)

    if new_line == current_line then
      vim.notify("Could not find text to replace: " .. fix.old_text, vim.log.levels.WARN)
      return
    end
  else
    vim.notify("Invalid fix format", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, diag.lnum, diag.lnum + 1, false, { new_line })

  vim.diagnostic.reset(ns, bufnr)
  local updated_diags = {}
  for _, d in ipairs(vim.diagnostic.get(bufnr, { namespace = ns })) do
    if d.lnum ~= diag.lnum or d.col ~= diag.col then
      table.insert(updated_diags, d)
    end
  end
  vim.diagnostic.set(ns, bufnr, updated_diags, {})

  vim.notify("Applied fix: " .. fix.description, vim.log.levels.INFO)
end

function M.show_fix_preview()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  local diagnostics = vim.diagnostic.get(bufnr, { namespace = ns, lnum = line })

  if #diagnostics == 0 then
    return
  end

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local diag = diagnostics[1]
  local key = string.format("%s:%d:%d", file_path, diag.lnum + 1, diag.col + 1)

  local fix = diagnostic_fixes[key]
  if fix then
    vim.notify(
      string.format(
        "Fix: %s\nOld: %s\nNew: %s",
        fix.description,
        fix.old_text,
        fix.new_text
      ),
      vim.log.levels.INFO
    )
  end
end

function M.get_code_actions(bufnr, range)
  local actions = {}
  local file_path = vim.api.nvim_buf_get_name(bufnr)

  local start_line = range.start.line
  local end_line = range["end"].line

  for line = start_line, end_line do
    local diagnostics = vim.diagnostic.get(bufnr, { namespace = ns, lnum = line })

    for _, diag in ipairs(diagnostics) do
      local key = string.format("%s:%d:%d", file_path, diag.lnum + 1, diag.col + 1)
      local fix = diagnostic_fixes[key]

      if fix then
        table.insert(actions, {
          title = "Claude: " .. fix.description,
          kind = "quickfix",
          diagnostics = { diag },
          action = function()
            M.apply_specific_fix(bufnr, diag, fix)
          end,
        })
      end
    end
  end

  return actions
end

local function normalize_whitespace(text)
  return text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
end

local function find_text_in_buffer(bufnr, start_line, search_text)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local search_lines = vim.split(search_text, "\n")

  for i = start_line, #lines - #search_lines + 1 do
    local match = true
    for j = 1, #search_lines do
      local buf_line = lines[i + j - 1] or ""
      local search_line = search_lines[j]

      if normalize_whitespace(buf_line) ~= normalize_whitespace(search_line) then
        match = false
        break
      end
    end

    if match then
      return i - 1, i - 1 + #search_lines - 1
    end
  end

  return nil, nil
end

function M.apply_specific_fix(bufnr, diag, fix)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if diag.lnum >= line_count then
    vim.notify("Diagnostic line is out of range", vim.log.levels.ERROR)
    return
  end

  local start_line, end_line = find_text_in_buffer(bufnr, diag.lnum + 1, fix.old_text)

  if not start_line then
    local current_line = vim.api.nvim_buf_get_lines(bufnr, diag.lnum, diag.lnum + 1, false)[1]

    if current_line then
      local new_line = current_line:gsub(vim.pesc(fix.old_text), fix.new_text)

      if new_line ~= current_line then
        vim.api.nvim_buf_set_lines(bufnr, diag.lnum, diag.lnum + 1, false, { new_line })

        vim.diagnostic.reset(ns, bufnr)
        local updated_diags = {}
        for _, d in ipairs(vim.diagnostic.get(bufnr, { namespace = ns })) do
          if d.lnum ~= diag.lnum or d.col ~= diag.col then
            table.insert(updated_diags, d)
          end
        end
        vim.diagnostic.set(ns, bufnr, updated_diags, {})

        vim.notify("Applied fix: " .. fix.description, vim.log.levels.INFO)
        return
      end
    end

    vim.notify("Could not find text to replace. Use :ClaudeReviewPreviewFix to see what was expected.", vim.log.levels.WARN)
    return
  end

  local new_lines = vim.split(fix.new_text, "\n")
  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line + 1, false, new_lines)

  vim.diagnostic.reset(ns, bufnr)
  local updated_diags = {}
  for _, d in ipairs(vim.diagnostic.get(bufnr, { namespace = ns })) do
    if d.lnum < start_line or d.lnum > end_line then
      table.insert(updated_diags, d)
    end
  end
  vim.diagnostic.set(ns, bufnr, updated_diags, {})

  vim.notify("Applied fix: " .. fix.description, vim.log.levels.INFO)
end

local function show_diff_preview(bufnr, start_line, end_line, new_lines, callback)
  local old_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

  local diff_lines = {"Before:", ""}
  for i, line in ipairs(old_lines) do
    table.insert(diff_lines, string.format("- %s", line))
  end

  table.insert(diff_lines, "")
  table.insert(diff_lines, "After:")
  table.insert(diff_lines, "")

  for i, line in ipairs(new_lines) do
    table.insert(diff_lines, string.format("+ %s", line))
  end

  table.insert(diff_lines, "")
  table.insert(diff_lines, "Press <CR> to apply, <Esc> to cancel")

  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, diff_lines)
  vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(preview_buf, "filetype", "diff")

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#diff_lines + 2, vim.o.lines - 4)

  local win = vim.api.nvim_open_win(preview_buf, true, {
    relative = "cursor",
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
    title = " Code Action Preview ",
    title_pos = "center",
  })

  vim.api.nvim_buf_set_keymap(preview_buf, "n", "<CR>", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
      callback(true)
    end
  })

  vim.api.nvim_buf_set_keymap(preview_buf, "n", "<Esc>", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
      callback(false)
    end
  })

  vim.api.nvim_buf_set_keymap(preview_buf, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
      callback(false)
    end
  })
end

function M.apply_fix_with_preview(bufnr, diag, fix)
  local start_line, end_line = find_text_in_buffer(bufnr, diag.lnum + 1, fix.old_text)

  if not start_line then
    start_line = diag.lnum
    end_line = diag.lnum
  end

  local new_lines = vim.split(fix.new_text, "\n")

  show_diff_preview(bufnr, start_line, end_line, new_lines, function(apply)
    if apply then
      M.apply_specific_fix(bufnr, diag, fix)
    end
  end)
end

return M
