vim.opt.runtimepath:append(vim.fn.getcwd())

local repo_root = vim.fn.getcwd()
local tmp_root = vim.fn.tempname()
local repo_dir = tmp_root .. "/repo"
local state_dir = tmp_root .. "/state"

vim.fn.mkdir(repo_dir, "p")
vim.fn.mkdir(state_dir, "p")
vim.fn.system({ "git", "init", "-q", repo_dir })
assert(vim.v.shell_error == 0, "failed to init temp git repo")

local sample = table.concat({
  "local M = {}",
  "function M.one()",
  "  local value = 1",
  "  return value",
  "end",
  "",
  "function M.two()",
  "  return 2",
  "end",
  "",
  "return M",
  "",
}, "\n")

local sample_path = repo_dir .. "/sample.lua"
vim.fn.writefile(vim.split(sample, "\n", { plain = true }), sample_path)
local session_export_path = tmp_root .. "/session-export.json"
local session_export_token = "test-token-123"

local pr = require("pi-review")
local comments = require("pi-review.comments")
local editor = require("pi-review.editor")
local exporter = require("pi-review.export")
local float = require("pi-review.float")
local picker = require("pi-review.picker")
local signs = require("pi-review.signs")
local util = require("pi-review.util")

pr.setup({
  export = { copy_to_clipboard = false },
  hover = { enabled = true, delay = 20 },
  storage = { persist = false, root_dir = state_dir },
})

vim.cmd("edit " .. vim.fn.fnameescape(sample_path))

local inputs = {
  "Line comment: consider renaming this function\nSecond line with more detail",
  "Range comment: extract this block\nMaybe move it to a helper",
  "File comment: this file could be split up later",
}

editor.open = function(_, on_confirm)
  on_confirm(table.remove(inputs, 1))
end

vim.cmd("2,2PiReviewComment")
vim.cmd("3,4PiReviewComment")
vim.cmd("PiReviewFileComment")

local ctx = assert(util.current_context(0))
local export_path = util.normalize(util.join(ctx.root, ctx.file_rel))
local items = comments.list(ctx.root)
assert(#items == 3, "expected 3 comments, got " .. #items)
assert(items[1].kind == "file", "expected file comment first")
assert(items[2].kind == "line", "expected line comment second")
assert(items[3].kind == "range", "expected range comment third")
assert(items[2].text:find("Second line with more detail", 1, true), "expected multiline line comment")
assert(items[3].text:find("Maybe move it to a helper", 1, true), "expected multiline range comment")

signs.refresh_buffer(0)
local placed = vim.fn.sign_getplaced(vim.api.nvim_get_current_buf(), { group = signs.group })
assert(#(placed[1].signs or {}) == 3, "expected 3 placed signs")
assert(placed[1].signs[1].lnum == 1, "file comment sign should be on line 1")
assert(placed[1].signs[2].lnum == 2, "line comment sign should be on line 2")
assert(placed[1].signs[3].lnum == 3, "range comment sign should be on range start")

local export_text = exporter.build_text(ctx.root)
assert(export_text:find("Please address these review comments:", 1, true), "missing export header")
assert(export_text:find("- " .. export_path, 1, true), "missing absolute file comment location")
assert(export_text:find("- " .. export_path .. ":2", 1, true), "missing absolute line comment location")
assert(export_text:find("- " .. export_path .. ":3-4", 1, true), "missing absolute range comment location")
assert(export_text:find("Line comment: consider renaming this function", 1, true), "missing line comment text")
assert(export_text:find("Second line with more detail", 1, true), "missing second line of line comment")
assert(export_text:find("Range comment: extract this block", 1, true), "missing range comment text")
assert(export_text:find("Maybe move it to a helper", 1, true), "missing second line of range comment")
assert(export_text:find("File comment: this file could be split up later", 1, true), "missing file comment text")
assert(export_text:find("```lua", 1, true), "missing code fence")
assert(export_text:find("function M.one%(%)") or export_text:find("function M.one()", 1, true), "missing line snippet")
assert(export_text:find("local value = 1", 1, true), "missing range snippet")
assert(export_text:find("return value", 1, true), "missing range snippet tail")

vim.g.pi_review_export_path = session_export_path
vim.g.pi_review_export_token = session_export_token
vim.g.pi_review_export_root = repo_dir
assert(exporter.flush_session(ctx.root) == true, "expected session export to be written")
local export_payload = vim.json.decode(table.concat(vim.fn.readfile(session_export_path), "\n"))
assert(export_payload.token == session_export_token, "session export token mismatch")
assert(export_payload.root == ctx.root, "session export root mismatch")
assert(export_payload.text == export_text, "session export text mismatch")

local comments_file = util.comments_file(ctx.root)
assert(not util.exists(comments_file), "comments should be ephemeral by default")

local range_comment = items[3]
editor.open = function(_, on_confirm)
  on_confirm("Edited from picker\nSecond edited line")
end
pr.edit_comment(ctx.root, range_comment)

items = comments.list(ctx.root)
assert(items[3].text:find("Edited from picker", 1, true), "expected edited comment text")
assert(items[3].text:find("Second edited line", 1, true), "expected edited multiline text")

assert(pr.delete_comment(ctx.root, items[3]) == true, "expected delete_comment helper to succeed")
items = comments.list(ctx.root)
assert(#items == 2, "expected 2 comments after helper delete")

comments.upsert(ctx.root, {
  file = ctx.file_rel,
  kind = "range",
  line_start = 3,
  line_end = 4,
  text = "Range comment: extract this block\nMaybe move it to a helper",
})
items = comments.list(ctx.root)
assert(#items == 3, "expected range comment restored")

local picker_opts
_G.Snacks = {
  picker = {
    pick = function(opts)
      picker_opts = opts
      return opts
    end,
  },
}
picker.open(ctx.root)
assert(type(picker_opts) == "table", "picker should pass opts to Snacks")
assert(type(picker_opts.actions.comment_edit) == "function", "picker should expose edit action")
assert(type(picker_opts.actions.comment_delete) == "function", "picker should expose delete action")

vim.cmd("enew")
vim.cmd("lcd " .. vim.fn.fnameescape(repo_dir))
assert(util.current_root() == ctx.root, "current_root should resolve repo from cwd when buffer has no file")
vim.cmd("edit " .. vim.fn.fnameescape(sample_path))
_G.Snacks = nil

pr.toggle()
assert(float.is_open(), "toggle should open float")
pr.toggle()
assert(not float.is_open(), "toggle should close float")

vim.api.nvim_win_set_cursor(0, { 3, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
assert(vim.wait(200, function()
  return float.is_open()
end), "hover should open float after delay")

vim.api.nvim_win_set_cursor(0, { 5, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
assert(vim.wait(200, function()
  return not float.is_open()
end), "moving away should close float")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd("PiReviewDelete")

items = comments.list(ctx.root)
assert(#items == 2, "expected 2 comments after delete, got " .. #items)
assert(items[1].kind == "file", "file comment should remain")
assert(items[2].kind == "range", "range comment should remain")

signs.refresh_buffer(0)
placed = vim.fn.sign_getplaced(vim.api.nvim_get_current_buf(), { group = signs.group })
assert(#(placed[1].signs or {}) == 2, "expected 2 placed signs after delete")

local export_after_delete = exporter.build_text(ctx.root)
assert(not export_after_delete:find("Line comment: consider renaming this function", 1, true), "line comment should be deleted")

assert(pr.delete_comment(ctx.root, items[1]) == true, "expected file comment delete")
assert(pr.delete_comment(ctx.root, items[2]) == true, "expected range comment delete")
assert(exporter.flush_session(ctx.root) == false, "session export should clear when no comments remain")
assert(not util.exists(session_export_path), "session export file should be removed when empty")

print("pi-review smoke ok")
print(export_text)

vim.fn.delete(tmp_root, "rf")
vim.cmd("qa!")
