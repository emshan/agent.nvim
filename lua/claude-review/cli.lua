local M = {}
local debug = require("claude-review.debug")

local json_schema = vim.json.encode({
  type = "object",
  properties = {
    diagnostics = {
      type = "array",
      items = {
        type = "object",
        properties = {
          file = { type = "string" },
          line = { type = "number" },
          col = { type = "number" },
          severity = { type = "string", enum = { "error", "warning", "info", "hint" } },
          message = { type = "string" },
          suggested_fix = {
            type = "object",
            properties = {
              description = { type = "string" },
              old_text = { type = "string" },
              new_text = { type = "string" }
            }
          }
        },
        required = { "file", "line", "col", "severity", "message" }
      }
    }
  },
  required = { "diagnostics" }
})

local function build_review_prompt(file_path)
  return string.format(
    [[Please review the code in file: %s

Focus on:
- Potential bugs and logic errors
- Code quality and readability issues
- Performance concerns
- Security vulnerabilities

For each issue found, if you can provide a suggested fix, include it in the suggested_fix field with:
- description: Brief description of the fix
- old_text: The exact text to replace
- new_text: The replacement text

Be specific about line and column numbers. Only include actual issues found.]],
    file_path
  )
end

local function build_diff_review_prompt(file_path, ref)
  return string.format(
    [[Please review the git diff for file: %s (changes from %s to current)

First, run: git diff %s -- %s

Focus on the changes only. Line numbers should refer to the current file state.
Be specific about line and column numbers. Only include actual issues found in the changes.]],
    file_path,
    ref,
    ref,
    file_path
  )
end

function M.review_file(file_path, callback)
  local prompt = build_review_prompt(file_path)

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
