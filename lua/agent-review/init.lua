local comments = require("agent-review.comments")
local commands = require("agent-review.commands")
local config = require("agent-review.config")
local editor = require("agent-review.editor")
local exporter = require("agent-review.export")
local float = require("agent-review.float")
local picker = require("agent-review.picker")
local signs = require("agent-review.signs")
local util = require("agent-review.util")

local M = {}

local state = {
  initialized = false,
  augroup = nil,
  hover_timer = nil,
}

local function comment_label(comment)
  if comment.kind == "file" then
    return string.format("%s [file]", comment.file)
  end
  if comment.line_start == comment.line_end then
    return string.format("%s:%d", comment.file, comment.line_start)
  end
  return string.format("%s:%d-%d", comment.file, comment.line_start, comment.line_end)
end

local function ensure_initialized()
  if state.initialized then
    return
  end

  signs.define()
  commands.register()

  state.augroup = vim.api.nvim_create_augroup("AgentReview", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = state.augroup,
    callback = function(args)
      signs.refresh_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
    group = state.augroup,
    callback = function()
      require("agent-review")._handle_cursor_activity()
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave", "WinLeave" }, {
    group = state.augroup,
    callback = function()
      require("agent-review")._cancel_hover()
      float.close()
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = state.augroup,
    callback = function()
      exporter.flush_session(util.current_root())
    end,
  })

  state.initialized = true
end

local function current_root()
  return util.current_root()
end

local function current_position_comments()
  local ctx, err = util.current_context(0)
  if not ctx then
    return nil, err
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local items = comments.at_position(ctx.root, ctx.file_rel, line)
  local ids = {}
  for _, comment in ipairs(items) do
    ids[#ids + 1] = comment.id
  end

  local signature = nil
  if #ids > 0 then
    signature = table.concat({ ctx.root, ctx.file_rel, table.concat(ids, ",") }, "|")
  end

  return {
    ctx = ctx,
    line = line,
    items = items,
    signature = signature,
  }
end

local function input_comment(title, default, callback)
  editor.open({
    title = title,
    text = default or "",
  }, function(value)
    if value == nil then
      return
    end
    callback(vim.trim(value))
  end)
end

local function update_anchor(kind, line1, line2)
  local ctx, err = util.current_context(0)
  if not ctx then
    util.notify(err, vim.log.levels.ERROR)
    return
  end

  line1, line2 = math.min(line1, line2), math.max(line1, line2)
  local existing = comments.find_anchor(ctx.root, ctx.file_rel, kind, line1, line2)
  local label
  if kind == "file" then
    label = ctx.file_rel
  elseif line1 == line2 then
    label = string.format("%s:%d", ctx.file_rel, line1)
  else
    label = string.format("%s:%d-%d", ctx.file_rel, line1, line2)
  end

  input_comment("Review comment for " .. label, existing and existing.text or "", function(text)
    if text == "" then
      if existing then
        comments.delete(ctx.root, existing.id)
        signs.refresh_open_buffers()
        util.notify("Deleted comment")
      end
      return
    end

    local _, action = comments.upsert(ctx.root, {
      file = ctx.file_rel,
      kind = kind,
      line_start = line1,
      line_end = line2,
      text = text,
    })

    signs.refresh_open_buffers()
    util.notify((action == "created" and "Added" or "Updated") .. " comment")
  end)
end

local function edit_existing_comment(root, comment)
  if not comment then
    return
  end

  local label = comment_label(comment)
  input_comment("Review comment for " .. label, comment.text or "", function(text)
    if text == "" then
      if comments.delete(root, comment.id) then
        signs.refresh_open_buffers()
        float.close()
        util.notify("Deleted comment: " .. label)
      end
      return
    end

    local _, action = comments.upsert(root, {
      file = comment.file,
      kind = comment.kind,
      line_start = comment.line_start,
      line_end = comment.line_end,
      text = text,
    })

    signs.refresh_open_buffers()
    util.notify((action == "created" and "Added" or "Updated") .. " comment: " .. label)
  end)
end

local function ensure_hover_timer()
  if state.hover_timer then
    return state.hover_timer
  end
  state.hover_timer = (vim.uv or vim.loop).new_timer()
  return state.hover_timer
end

function M._cancel_hover()
  if state.hover_timer then
    state.hover_timer:stop()
  end
end

function M._handle_cursor_activity()
  M._cancel_hover()

  local current = current_position_comments()
  if not current then
    float.close()
    return
  end

  if not current.signature or not float.is_open(current.signature) then
    float.close()
  end

  local hover_cfg = config.get().hover
  if not hover_cfg.enabled or not current.signature then
    return
  end

  local signature = current.signature
  local timer = ensure_hover_timer()
  timer:start(hover_cfg.delay, 0, vim.schedule_wrap(function()
    local latest = current_position_comments()
    if not latest or latest.signature ~= signature or float.is_open(signature) then
      return
    end
    float.open(latest.items, { signature = latest.signature, notify_empty = false })
  end))
end

function M.setup(opts)
  config.setup(opts)
  ensure_initialized()
  signs.refresh_open_buffers()
end

function M.comment(opts)
  M.setup()
  opts = opts or {}
  local line1 = opts.line1 or vim.api.nvim_win_get_cursor(0)[1]
  local line2 = opts.line2 or line1
  local kind = line1 == line2 and "line" or "range"
  update_anchor(kind, line1, line2)
end

function M.file_comment()
  M.setup()
  update_anchor("file", 1, 1)
end

function M.show()
  M.setup()
  local current, err = current_position_comments()
  if not current then
    util.notify(err, vim.log.levels.ERROR)
    return
  end

  if current.signature and float.is_open(current.signature) then
    float.close()
    return
  end

  float.open(current.items, { signature = current.signature })
end

M.toggle = M.show

function M.delete()
  M.setup()
  local ctx, err = util.current_context(0)
  if not ctx then
    util.notify(err, vim.log.levels.ERROR)
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local matches = comments.at_position(ctx.root, ctx.file_rel, line)
  if line ~= 1 then
    local specific = vim.tbl_filter(function(comment)
      return comment.kind ~= "file"
    end, matches)
    if #specific > 0 then
      matches = specific
    end
  end
  if #matches == 0 then
    util.notify("No comments at cursor", vim.log.levels.INFO)
    return
  end

  local function remove(comment)
    if not comment then
      return
    end
    if comments.delete(ctx.root, comment.id) then
      signs.refresh_open_buffers()
      float.close()
      util.notify("Deleted comment: " .. comment_label(comment))
    else
      util.notify("Failed to delete comment", vim.log.levels.ERROR)
    end
  end

  if #matches == 1 then
    remove(matches[1])
    return
  end

  vim.ui.select(matches, {
    prompt = "Delete agent-review comment",
    format_item = function(comment)
      return string.format("%s — %s", comment_label(comment), util.truncate(comment.text:gsub("%s+", " "), 80))
    end,
  }, remove)
end

function M.delete_comment(root, comment)
  M.setup()
  if not comment then
    return false
  end
  if comments.delete(root, comment.id) then
    signs.refresh_open_buffers()
    float.close()
    util.notify("Deleted comment: " .. comment_label(comment))
    return true
  end
  util.notify("Failed to delete comment", vim.log.levels.ERROR)
  return false
end

function M.edit_comment(root, comment)
  M.setup()
  edit_existing_comment(root, comment)
end

function M.list()
  M.setup()
  picker.open(current_root())
end

function M.export()
  M.setup()
  exporter.open(current_root())
end

return M
