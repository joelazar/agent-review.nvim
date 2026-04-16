local util = require("agent-review.util")

local M = {}

local cache = {}

local function decode(path, content)
  if not content or content == "" then
    return {}
  end

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    util.notify("Failed to decode comments from " .. path, vim.log.levels.ERROR)
    return {}
  end

  if vim.islist(data) then
    return data
  end

  if type(data) == "table" and vim.islist(data.comments) then
    return data.comments
  end

  return {}
end

function M.load(root)
  root = util.normalize(root)
  if cache[root] then
    return cache[root]
  end

  if not util.should_persist() then
    cache[root] = {}
    return cache[root]
  end

  local path = util.comments_file(root)
  if not util.exists(path) then
    cache[root] = {}
    return cache[root]
  end

  cache[root] = decode(path, util.read_file(path))
  return cache[root]
end

function M.save(root, comments)
  root = util.normalize(root)
  cache[root] = comments or {}

  if not util.should_persist() then
    return true
  end

  local path = util.comments_file(root)
  local payload = {
    version = 1,
    comments = cache[root],
  }

  local ok, encoded = pcall(vim.json.encode, payload)
  if not ok then
    util.notify("Failed to encode comments", vim.log.levels.ERROR)
    return false
  end

  local wrote, err = util.write_file(path, encoded)
  if not wrote then
    util.notify("Failed to write comments: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.clear_cache(root)
  if root then
    cache[util.normalize(root)] = nil
    return
  end
  cache = {}
end

return M
