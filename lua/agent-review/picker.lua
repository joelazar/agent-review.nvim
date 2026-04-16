local comments = require("agent-review.comments")
local config = require("agent-review.config")
local util = require("agent-review.util")

local M = {}

local function get_snacks()
  if rawget(_G, "Snacks") then
    return _G.Snacks
  end

  local ok, snacks = pcall(require, "snacks")
  if ok then
    return snacks
  end
end

local function anchor_line(comment)
  return comment.kind == "file" and 1 or comment.line_start
end

local function item_label(comment)
  if comment.kind == "file" then
    return "[file]"
  end
  if comment.line_start == comment.line_end then
    return tostring(comment.line_start)
  end
  return string.format("%d-%d", comment.line_start, comment.line_end)
end

local function to_items(root)
  local items = {}
  for _, comment in ipairs(comments.list(root)) do
    items[#items + 1] = {
      text = table.concat({ comment.file, item_label(comment), comment.text }, " "),
      file = util.join(root, comment.file),
      root = root,
      pos = { anchor_line(comment), 0 },
      preview = "file",
      title = comment.file,
      comment = comment,
      label = item_label(comment),
      summary = util.truncate(comment.text:gsub("%s+", " "), 80),
    }
  end
  return items
end

local function jump_to(item)
  if not item then
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(item.file))
  vim.api.nvim_win_set_cursor(0, { anchor_line(item.comment), 0 })
end

local function fallback_select(items)
  vim.ui.select(items, {
    prompt = config.get().picker.title,
    format_item = function(item)
      return string.format("%s:%s %s", item.comment.file, item.label, item.summary)
    end,
  }, function(choice)
    jump_to(choice)
  end)
end

function M.open(root)
  local items = to_items(root)
  if #items == 0 then
    util.notify("No comments for this repo", vim.log.levels.INFO)
    return
  end

  local snacks = get_snacks()
  if not (snacks and snacks.picker and snacks.picker.pick) then
    fallback_select(items)
    return
  end

  snacks.picker.pick({
    title = config.get().picker.title,
    finder = function()
      return to_items(root)
    end,
    preview = "file",
    actions = {
      comment_edit = function(picker, item)
        item = item or picker:current()
        if not item then
          return
        end
        picker:close()
        vim.schedule(function()
          require("agent-review").edit_comment(item.root, item.comment)
        end)
      end,
      comment_delete = function(picker)
        local selected = picker:selected({ fallback = true })
        if #selected == 0 then
          return
        end
        local deleted = 0
        for _, item in ipairs(selected) do
          if require("agent-review").delete_comment(item.root, item.comment) then
            deleted = deleted + 1
          end
        end
        if deleted > 0 then
          picker:refresh()
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-e>"] = { "comment_edit", mode = { "n", "i" }, desc = "Edit Comment" },
          ["<c-d>"] = { "comment_delete", mode = { "n", "i" }, desc = "Delete Comment" },
        },
      },
      list = {
        keys = {
          ["e"] = "comment_edit",
          ["dd"] = "comment_delete",
        },
      },
    },
    format = function(item)
      return {
        { string.format("%s:%s", item.comment.file, item.label), "Directory" },
        { "  " },
        { item.summary },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      vim.schedule(function()
        jump_to(item)
      end)
    end,
  })
end

return M
