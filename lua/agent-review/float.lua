local config = require("agent-review.config")
local util = require("agent-review.util")

local M = {}

M.win = nil
M.buf = nil
M.signature = nil

local function render_lines(items)
  local lines = { "agent-review", "" }
  for index, comment in ipairs(items) do
    local label
    if comment.kind == "file" then
      label = string.format("%d. %s [file]", index, comment.file)
    elseif comment.line_start == comment.line_end then
      label = string.format("%d. %s:%d", index, comment.file, comment.line_start)
    else
      label = string.format("%d. %s:%d-%d", index, comment.file, comment.line_start, comment.line_end)
    end
    lines[#lines + 1] = label
    for _, line in ipairs(vim.split(comment.text, "\n", { plain = true })) do
      lines[#lines + 1] = "   " .. line
    end
    if index < #items then
      lines[#lines + 1] = ""
    end
  end
  return lines
end

function M.is_open(signature)
  local open = M.win and vim.api.nvim_win_is_valid(M.win)
  if not open then
    return false
  end
  if signature == nil then
    return true
  end
  return M.signature == signature
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
  M.signature = nil
end

function M.open(items, opts)
  opts = opts or {}
  if #items == 0 then
    if opts.notify_empty ~= false then
      util.notify("No comments at cursor", vim.log.levels.INFO)
    end
    return
  end

  M.close()

  local lines = render_lines(items)
  local cfg = config.get().float
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(math.max(width + 2, 30), cfg.max_width)
  local height = math.min(#lines, cfg.max_height)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1,
    col = 1,
    width = width,
    height = height,
    style = "minimal",
    border = cfg.border,
  })

  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, { buffer = buf, silent = true, nowait = true })

  M.win = win
  M.buf = buf
  M.signature = opts.signature
end

return M
