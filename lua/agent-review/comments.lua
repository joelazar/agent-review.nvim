local store = require("agent-review.store")
local util = require("agent-review.util")

local M = {}

local function sort_comments(items)
  table.sort(items, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    if a.line_start ~= b.line_start then
      return a.line_start < b.line_start
    end
    if a.line_end ~= b.line_end then
      return a.line_end < b.line_end
    end
    return a.id < b.id
  end)
end

function M.list(root)
  local items = vim.deepcopy(store.load(root))
  sort_comments(items)
  return items
end

function M.for_file(root, file)
  local ret = {}
  for _, comment in ipairs(store.load(root)) do
    if comment.file == file then
      ret[#ret + 1] = comment
    end
  end
  sort_comments(ret)
  return ret
end

function M.find_anchor(root, file, kind, line_start, line_end)
  for _, comment in ipairs(store.load(root)) do
    if comment.file == file and comment.kind == kind and comment.line_start == line_start and comment.line_end == line_end then
      return comment
    end
  end
end

function M.at_position(root, file, line)
  local ret = {}
  for _, comment in ipairs(store.load(root)) do
    if comment.file == file then
      if comment.kind == "file" then
        if line == 1 then
          ret[#ret + 1] = comment
        end
      elseif line >= comment.line_start and line <= comment.line_end then
        ret[#ret + 1] = comment
      end
    end
  end
  sort_comments(ret)
  return ret
end

function M.upsert(root, input)
  local items = store.load(root)
  local existing = M.find_anchor(root, input.file, input.kind, input.line_start, input.line_end)
  local now = util.now()

  if existing then
    existing.text = input.text
    existing.updated_at = now
    store.save(root, items)
    return existing, "updated"
  end

  local comment = {
    id = util.make_id(),
    file = input.file,
    kind = input.kind,
    line_start = input.line_start,
    line_end = input.line_end,
    text = input.text,
    created_at = now,
    updated_at = now,
  }

  items[#items + 1] = comment
  sort_comments(items)
  store.save(root, items)
  return comment, "created"
end

function M.delete(root, id)
  local items = store.load(root)
  for idx, comment in ipairs(items) do
    if comment.id == id then
      table.remove(items, idx)
      store.save(root, items)
      return true
    end
  end
  return false
end

return M
