local M = {}
local debug = require("claude-review.debug")

local json_schema = vim.json.encode({
  type = "object",
  properties = {
    code_actions = {
      type = "array",
      items = {
        type = "object",
        properties = {
          title = { type = "string" },
          kind = { type = "string", enum = { "quickfix", "refactor", "source" } },
          diagnostic = {
            type = "object",
            properties = {
              file = { type = "string" },
              line = { type = "number" },
              col = { type = "number" },
              severity = { type = "string", enum = { "error", "warning", "info", "hint" } },
              message = { type = "string" },
            },
            required = { "file", "line", "col", "severity", "message" }
          },
          edit = {
            type = "object",
            properties = {
              old_text = { type = "string" },
              new_text = { type = "string" }
            },
            required = { "old_text", "new_text" }
          }
        },
        required = { "title", "kind", "diagnostic" }
      }
    }
  },
  required = { "code_actions" }
})

local function build_review_prompt(file_path, focus)
  local focus_section
  if focus and focus ~= "" then
    focus_section = string.format("Focus on: %s", focus)
  else
    focus_section = [[Focus on:
- Potential bugs and logic errors
- Code quality and readability issues
- Performance concerns
- Security vulnerabilities]]
  end

  return string.format(
    [[Please review the code in file: %s

%s

For each issue found, create a code_action with:
- title: Brief description of the action (e.g., "Fix null check", "Rename variable")
- kind: One of "quickfix", "refactor", or "source"
- diagnostic: The issue details (file, line, col, severity, message)
- edit: If fixable, include old_text and new_text for the replacement

Be specific about line and column numbers. Only include actual issues found.]],
    file_path,
    focus_section
  )
end

local function build_diff_review_prompt(file_path, ref)
  return string.format(
    [[Please review the git diff for file: %s (changes from %s to current)

First, run: git diff %s -- %s

Focus on the changes only. Line numbers should refer to the current file state.
For each issue, create a code_action with title, kind, diagnostic, and optional edit.
Be specific about line and column numbers. Only include actual issues found in the changes.]],
    file_path,
    ref,
    ref,
    file_path
  )
end

function M.review_file(file_path, focus, callback)
  local prompt = build_review_prompt(file_path, focus)

  debug.store_request(prompt)

  local obj = vim.system(
    {
      "claude",
      "--print",
      "--output-format", "json",
      "--json-schema", json_schema,
      "--allowedTools", "Bash(git log:*)",
      "--allowedTools", "Bash(git diff:*)",
      "--allowedTools", "Read",
    },
    {
      cwd = vim.fn.getcwd(),
      text = true,
      stdin = prompt,
    },
    function(result)
      if result.code == 0 then
        debug.store_response(result.stdout, result.stderr ~= "" and ("stderr: " .. result.stderr) or nil)
        callback(result.stdout, nil)
      else
        local err = "claude command failed with exit code: " .. result.code
        if result.stderr and result.stderr ~= "" then
          err = err .. "\nstderr: " .. result.stderr
        end
        debug.store_response(nil, err)
        callback(nil, err)
      end
    end
  )
end

function M.review_diff(file_path, ref, callback)
  local prompt = build_diff_review_prompt(file_path, ref)

  debug.store_request(prompt)

  local obj = vim.system(
    {
      "claude",
      "--print",
      "--output-format", "json",
      "--json-schema", json_schema,
      "--allowedTools", "Bash(git log:*)",
      "--allowedTools", "Bash(git diff:*)",
      "--allowedTools", "Read",
    },
    {
      cwd = vim.fn.getcwd(),
      text = true,
      stdin = prompt,
    },
    function(result)
      if result.code == 0 then
        debug.store_response(result.stdout, result.stderr ~= "" and ("stderr: " .. result.stderr) or nil)
        callback(result.stdout, nil)
      else
        local err = "claude command failed with exit code: " .. result.code
        if result.stderr and result.stderr ~= "" then
          err = err .. "\nstderr: " .. result.stderr
        end
        debug.store_response(nil, err)
        callback(nil, err)
      end
    end
  )
end

return M
