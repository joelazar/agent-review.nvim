-- Lualine component for agent-review.nvim.
--
-- Basic usage:
--   lualine_x = { require("agent-review.lualine").component() }
--
-- With overrides:
--   require("agent-review.lualine").component({
--     icon = "",
--     color = "DiagnosticInfo",
--     show_zero = true,
--   })

local comments = require("agent-review.comments")
local config = require("agent-review.config")
local util = require("agent-review.util")

local M = {}

-- Cache the git root per buffer. Lualine redraws often and git_root shells out.
local function buf_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return util.current_root()
  end

  local ok, cached = pcall(function()
    return vim.b[bufnr].agent_review_root
  end)
  if ok and type(cached) == "string" and cached ~= "" then
    return cached
  end

  local root = util.current_root()
  pcall(function()
    vim.b[bufnr].agent_review_root = root
  end)
  return root
end

-- Count comments for the given (or current) repo.
function M.count(root)
  root = root or buf_root()
  local ok, items = pcall(comments.list, root)
  if not ok or type(items) ~= "table" then
    return 0
  end
  return #items
end

-- Formatted status string, e.g. "● 3". Returns "" when the count is zero
-- and show_zero is not set.
function M.status(opts)
  opts = opts or {}
  local n = M.count()
  if n == 0 and not opts.show_zero then
    return ""
  end

  local icon = opts.icon
  if icon == nil then
    icon = config.get().sign.text or "●"
  end

  local format = opts.format or "%s %d"
  if icon == "" then
    return tostring(n)
  end
  return string.format(format, icon, n)
end

-- Build a lualine component spec. Any lualine key (color, separator,
-- on_click, ...) can be overridden. Extra keys:
--   icon       override the leading glyph (defaults to config.sign.text)
--   show_zero  keep the component visible when the count is zero
--   format     format string, defaults to "%s %d"
function M.component(opts)
  opts = opts or {}

  local spec_opts = {
    icon = opts.icon,
    show_zero = opts.show_zero,
    format = opts.format,
  }

  local overrides = {}
  for k, v in pairs(opts) do
    if k ~= "icon" and k ~= "show_zero" and k ~= "format" then
      overrides[k] = v
    end
  end

  local component = {
    function()
      return M.status(spec_opts)
    end,
    cond = function()
      if spec_opts.show_zero then
        return true
      end
      return M.count() > 0
    end,
    color = "DiagnosticHint",
    on_click = function()
      vim.cmd("AgentReviewList")
    end,
  }

  return vim.tbl_deep_extend("force", component, overrides)
end

return M
