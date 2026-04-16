local config = require("agent-review.config")

local M = {}

function M.notify(message, level)
  vim.notify("[agent-review] " .. message, level or vim.log.levels.INFO)
end

function M.now()
  return os.time()
end

function M.trim(text)
  return vim.trim(text or "")
end

function M.join(...)
  return table.concat({ ... }, "/")
end

function M.normalize(path)
  return vim.fs.normalize(path)
end

function M.exists(path)
  local stat = (vim.uv or vim.loop).fs_stat(path)
  return stat ~= nil
end

function M.is_dir(path)
  local stat = (vim.uv or vim.loop).fs_stat(path)
  return stat and stat.type == "directory" or false
end

function M.ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

function M.read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

function M.write_file(path, content)
  M.ensure_dir(vim.fs.dirname(path))
  local fd, err = io.open(path, "w")
  if not fd then
    return nil, err
  end
  fd:write(content)
  fd:close()
  return true
end

function M.git_root(start_path)
  local path = start_path
  if not path or path == "" then
    path = vim.api.nvim_buf_get_name(0)
  end

  local dir = path ~= "" and (M.is_dir(path) and path or vim.fs.dirname(path)) or (vim.uv or vim.loop).cwd()
  local output = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and output[1] and output[1] ~= "" then
    return M.normalize(output[1])
  end
  return M.normalize((vim.uv or vim.loop).cwd())
end

function M.relative_path(root, path)
  root = M.normalize(root)
  path = M.normalize(path)
  local prefix = root .. "/"
  if path == root then
    return "."
  end
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
  return path
end

function M.repo_id(root)
  return vim.fn.sha256(root):sub(1, 16)
end

function M.repo_state_dir(root)
  local base = config.get().storage.root_dir
  return M.join(base, M.repo_id(root))
end

function M.comments_file(root)
  return M.join(M.repo_state_dir(root), "comments.json")
end

function M.should_persist()
  return config.get().storage.persist == true
end

function M.current_root()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file ~= "" then
    return M.git_root(current_file)
  end

  local cwd = vim.fn.getcwd()
  if cwd and cwd ~= "" then
    return M.git_root(cwd)
  end

  local alt = vim.fn.bufname("#")
  if alt and alt ~= "" then
    return M.git_root(alt)
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" then
        return M.git_root(name)
      end
    end
  end

  return M.git_root((vim.uv or vim.loop).cwd())
end

function M.current_context(bufnr)
  bufnr = bufnr or 0
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return nil, "Current buffer has no file"
  end

  local root = M.git_root(file)
  return {
    bufnr = bufnr,
    root = root,
    file = M.normalize(file),
    file_rel = M.relative_path(root, file),
  }
end

function M.make_id()
  local random = math.random(0, 0x7fffffff)
  return string.format("%d-%08x", M.now(), random)
end

function M.truncate(text, max_len)
  if #text <= max_len then
    return text
  end
  return text:sub(1, math.max(0, max_len - 1)) .. "…"
end

function M.buf_display_name(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return "[No Name]"
  end
  local root = M.git_root(file)
  return M.relative_path(root, file)
end

return M
