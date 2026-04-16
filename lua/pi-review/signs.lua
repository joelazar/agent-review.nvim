local comments = require("pi-review.comments")
local config = require("pi-review.config")
local util = require("pi-review.util")

local M = {}

M.group = "pi-review"
M.defined = false

function M.define()
  if M.defined then
    return
  end

  local sign = config.get().sign
  vim.fn.sign_define(sign.name, {
    text = sign.text,
    texthl = sign.texthl,
    linehl = sign.linehl,
    numhl = sign.numhl,
  })

  M.defined = true
end

function M.clear_buffer(bufnr)
  vim.fn.sign_unplace(M.group, { buffer = bufnr })
end

function M.refresh_buffer(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" or vim.bo[bufnr].buftype ~= "" then
    M.clear_buffer(bufnr)
    return
  end

  local ctx = util.current_context(bufnr)
  if not ctx then
    M.clear_buffer(bufnr)
    return
  end

  M.define()
  M.clear_buffer(bufnr)

  local sign = config.get().sign
  local items = comments.for_file(ctx.root, ctx.file_rel)
  for idx, comment in ipairs(items) do
    local lnum = comment.kind == "file" and 1 or math.max(comment.line_start, 1)
    vim.fn.sign_place(idx, M.group, sign.name, bufnr, {
      lnum = lnum,
      priority = sign.priority,
    })
  end
end

function M.refresh_open_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.refresh_buffer(bufnr)
    end
  end
end

return M
