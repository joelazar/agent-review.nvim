local M = {}

M.defaults = {
  sign = {
    name = "PiReviewComment",
    text = "●",
    texthl = "DiagnosticHint",
    linehl = "",
    numhl = "",
    priority = 10,
  },
  float = {
    border = "rounded",
    max_width = 100,
    max_height = 20,
  },
  editor = {
    border = "rounded",
    width = 80,
    min_height = 8,
  },
  hover = {
    enabled = true,
    delay = 600,
  },
  picker = {
    title = "Pi Review Comments",
  },
  export = {
    copy_to_clipboard = true,
    clipboard_register = "+",
  },
  storage = {
    persist = false,
    root_dir = vim.fn.stdpath("state") .. "/pi-review",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  if opts ~= nil then
    M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  end
  return M.options
end

function M.get()
  return M.options
end

return M
