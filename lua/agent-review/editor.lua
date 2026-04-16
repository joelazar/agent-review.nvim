local config = require("agent-review.config")

local M = {}

local state = {
  win = nil,
  buf = nil,
  prev_win = nil,
}

local function truncate_title(text, max_width)
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end

  local target = math.max(10, max_width - 1)
  local out = text
  while #out > 0 and vim.fn.strdisplaywidth(out .. "…") > target do
    out = out:sub(1, #out - 1)
  end
  return out .. "…"
end

local function close()
  if state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_get_current_win() == state.win then
    vim.cmd.stopinsert()
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
    vim.api.nvim_set_current_win(state.prev_win)
  end
  state.win = nil
  state.buf = nil
  state.prev_win = nil
end

local function collect_text(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  return table.concat(lines, "\n")
end

function M.open(opts, on_done)
  opts = opts or {}
  local editor_cfg = config.get().editor
  local initial = opts.text or ""
  local lines = vim.split(initial, "\n", { plain = true })
  if #lines == 0 then
    lines = { "" }
  end

  close()

  state.prev_win = vim.api.nvim_get_current_win()

  local width = math.min(editor_cfg.width, math.max(40, vim.o.columns - 8))
  local desired_height = math.max(editor_cfg.min_height, #lines + 2)
  local height = math.min(desired_height, math.max(editor_cfg.min_height, vim.o.lines - 8))
  local title = truncate_title(opts.title or "agent-review comment", math.max(20, width - 6))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = true

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = editor_cfg.border,
    title = title,
    title_pos = "center",
  })

  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local finished = false
  local function done(value)
    if finished then
      return
    end
    finished = true
    close()
    if on_done then
      on_done(value)
    end
  end

  local function submit()
    done(collect_text(buf))
  end

  local function cancel()
    done(nil)
  end

  local key_opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set({ "n", "i" }, "<C-s>", submit, key_opts)
  vim.keymap.set({ "n", "i" }, "<D-s>", submit, key_opts)
  vim.keymap.set("n", "<leader>w", submit, key_opts)
  vim.keymap.set("n", "q", cancel, key_opts)
  vim.keymap.set("n", "<Esc>", cancel, key_opts)

  state.win = win
  state.buf = buf

  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() == win then
      vim.cmd.startinsert()
    end
  end)
end

return M
