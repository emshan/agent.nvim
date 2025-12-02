local M = {}

local function find_json_in_text(text)
  local json_start = text:find('{"diagnostics"')
  if not json_start then
    return nil
  end

  local depth = 0
  local in_string = false
  local escape_next = false
  local json_end = nil

  for i = json_start, #text do
    local char = text:sub(i, i)

    if escape_next then
      escape_next = false
    elseif char == '\\' then
      escape_next = true
    elseif char == '"' and not escape_next then
      in_string = not in_string
    elseif not in_string then
      if char == '{' then
        depth = depth + 1
      elseif char == '}' then
        depth = depth - 1
        if depth == 0 then
          json_end = i
          break
        end
      end
    end
  end

  if json_end then
    return text:sub(json_start, json_end)
  end

  return nil
end

function M.parse_claude_response(raw_output)
  local ok, outer = pcall(vim.json.decode, raw_output)
  if not ok then
    return nil, "Failed to parse outer JSON: " .. tostring(outer)
  end

  if outer.structured_output and outer.structured_output.diagnostics then
    return outer.structured_output.diagnostics, nil
  end

  if outer.type == "result" and outer.result then
    if type(outer.result) == "table" and outer.result.diagnostics then
      return outer.result.diagnostics, nil
    end

    local content_text = outer.result
    local json_str = find_json_in_text(content_text)
    if json_str then
      local ok_inner, diagnostics_obj = pcall(vim.json.decode, json_str)
      if ok_inner and diagnostics_obj.diagnostics then
        return diagnostics_obj.diagnostics, nil
      end
    end
    return nil, "Could not find diagnostics in result"
  end

  if outer.messages and #outer.messages > 0 then
    local last_message = outer.messages[#outer.messages]
    if not last_message.content then
      return nil, "No content in last message"
    end

    local content_text = ""
    for _, block in ipairs(last_message.content) do
      if block.type == "text" then
        content_text = content_text .. block.text
      end
    end

    local json_str = find_json_in_text(content_text)
    if not json_str then
      return nil, "Could not find diagnostics JSON in response"
    end

    local ok_inner, diagnostics_obj = pcall(vim.json.decode, json_str)
    if not ok_inner then
      return nil, "Failed to parse diagnostics JSON: " .. tostring(diagnostics_obj)
    end

    if not diagnostics_obj.diagnostics then
      return nil, "No diagnostics array in parsed JSON"
    end

    return diagnostics_obj.diagnostics, nil
  end

  return nil, "Unrecognized response format"
end

return M
