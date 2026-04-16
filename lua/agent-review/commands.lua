local M = {}

local registered = false

function M.register()
  if registered then
    return
  end

  vim.api.nvim_create_user_command("AgentReviewComment", function(opts)
    require("agent-review").comment({ line1 = opts.line1, line2 = opts.line2 })
  end, {
    desc = "Add or edit an agent-review comment for the current line or range",
    range = true,
  })

  vim.api.nvim_create_user_command("AgentReviewFileComment", function()
    require("agent-review").file_comment()
  end, { desc = "Add or edit an agent-review file comment" })

  vim.api.nvim_create_user_command("AgentReviewToggle", function()
    require("agent-review").toggle()
  end, { desc = "Toggle agent-review comments at cursor" })

  vim.api.nvim_create_user_command("AgentReviewDelete", function()
    require("agent-review").delete()
  end, { desc = "Delete an agent-review comment at cursor" })

  vim.api.nvim_create_user_command("AgentReviewList", function()
    require("agent-review").list()
  end, { desc = "List agent-review comments" })

  vim.api.nvim_create_user_command("AgentReviewExport", function()
    require("agent-review").export()
  end, { desc = "Export agent-review comments" })

  registered = true
end

return M
