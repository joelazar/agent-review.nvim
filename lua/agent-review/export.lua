local comments = require("agent-review.comments")
local config = require("agent-review.config")
local util = require("agent-review.util")

local M = {}

local function session_target()
  local path = vim.g.agent_review_export_path or vim.env.AGENT_REVIEW_EXPORT_PATH
  local token = vim.g.agent_review_export_token or vim.env.AGENT_REVIEW_EXPORT_TOKEN
  local root = vim.g.agent_review_export_root or vim.env.AGENT_REVIEW_EXPORT_ROOT
  if type(path) ~= "string" or path == "" then
    return nil
  end
  if type(token) ~= "string" or token == "" then
    return nil
  end
  return {
    path = util.normalize(path),
    token = token,
    root = type(root) == "string" and root ~= "" and util.git_root(root) or nil,
  }
end

local function clear_file(path)
  if path and path ~= "" and util.exists(path) then
    os.remove(path)
  end
end

local function atomic_write(path, content)
  local tmp = string.format("%s.tmp.%d", path, math.random(100000, 999999))
  local ok, err = util.write_file(tmp, content)
  if not ok then
    clear_file(tmp)
    return nil, err
  end
  local renamed, rename_err = os.rename(tmp, path)
  if not renamed then
    clear_file(tmp)
    return nil, rename_err
  end
  return true
end

local function abs_path(root, comment)
  return util.normalize(util.join(root, comment.file))
end

local function comment_location_with_root(root, comment)
  local path = abs_path(root, comment)
  if comment.kind == "file" then
    return path
  end
  if comment.line_start == comment.line_end then
    return string.format("%s:%d", path, comment.line_start)
  end
  return string.format("%s:%d-%d", path, comment.line_start, comment.line_end)
end

local function code_fence(comment)
  local ft = vim.filetype.match({ filename = comment.file })
  return ft and ("```" .. ft) or "```"
end

local function get_file_lines(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if ok then
    return lines
  end

  return {}
end

local function code_example(root, comment)
  if comment.kind == "file" then
    return nil
  end

  local path = util.join(root, comment.file)
  local lines = get_file_lines(path)
  if #lines == 0 then
    return nil
  end

  local start_line = math.max(comment.line_start, 1)
  local end_line = math.min(comment.line_end, #lines)
  if start_line > end_line then
    return nil
  end

  local snippet = {}
  for line = start_line, end_line do
    snippet[#snippet + 1] = lines[line]
  end
  return snippet
end

function M.build_lines(root)
  local items = comments.list(root)
  local lines = {
    "Please address these review comments:",
    "",
  }

  for index, comment in ipairs(items) do
    lines[#lines + 1] = string.format("- %s", comment_location_with_root(root, comment))
    for _, line in ipairs(vim.split(comment.text, "\n", { plain = true })) do
      lines[#lines + 1] = "  " .. line
    end

    local snippet = code_example(root, comment)
    if snippet and #snippet > 0 then
      lines[#lines + 1] = "  " .. code_fence(comment)
      for _, line in ipairs(snippet) do
        lines[#lines + 1] = "  " .. line
      end
      lines[#lines + 1] = "  ```"
    end

    if index < #items then
      lines[#lines + 1] = ""
    end
  end

  return lines, items
end

function M.build_text(root)
  local lines = M.build_lines(root)
  return table.concat(lines, "\n")
end

function M.write(path, root, token)
  local lines, items = M.build_lines(root)
  if #items == 0 then
    clear_file(path)
    return false
  end

  local payload = {
    version = 1,
    token = token,
    root = util.normalize(root),
    text = table.concat(lines, "\n"),
  }

  local ok, encoded = pcall(vim.json.encode, payload)
  if not ok then
    util.notify("Failed to encode export payload", vim.log.levels.ERROR)
    return nil
  end

  local wrote, err = atomic_write(path, encoded)
  if not wrote then
    util.notify("Failed to write export payload: " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end

  return true
end

function M.flush_session(root)
  local target = session_target()
  if not target then
    return false
  end
  return M.write(target.path, target.root or root or util.current_root(), target.token)
end

function M.open(root)
  local lines, items = M.build_lines(root)
  if #items == 0 then
    util.notify("No comments to export", vim.log.levels.INFO)
    return
  end

  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, "agent-review-export.md")
  vim.api.nvim_set_current_buf(buf)

  local export_cfg = config.get().export
  if export_cfg.copy_to_clipboard and export_cfg.clipboard_register and export_cfg.clipboard_register ~= "" then
    local text = table.concat(lines, "\n")
    pcall(vim.fn.setreg, export_cfg.clipboard_register, text)
    util.notify("Exported comments and copied to clipboard")
  else
    util.notify("Exported comments")
  end
end

return M
