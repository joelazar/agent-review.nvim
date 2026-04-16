local M = {}

local registered = false

function M.register()
  if registered then
    return
  end

  vim.api.nvim_create_user_command("PiReviewComment", function(opts)
    require("pi-review").comment({ line1 = opts.line1, line2 = opts.line2 })
  end, {
    desc = "Add or edit a pi-review comment for the current line or range",
    range = true,
  })

  vim.api.nvim_create_user_command("PiReviewFileComment", function()
    require("pi-review").file_comment()
  end, { desc = "Add or edit a pi-review file comment" })

  vim.api.nvim_create_user_command("PiReviewToggle", function()
    require("pi-review").toggle()
  end, { desc = "Toggle pi-review comments at cursor" })

  vim.api.nvim_create_user_command("PiReviewDelete", function()
    require("pi-review").delete()
  end, { desc = "Delete a pi-review comment at cursor" })

  vim.api.nvim_create_user_command("PiReviewList", function()
    require("pi-review").list()
  end, { desc = "List pi-review comments" })

  vim.api.nvim_create_user_command("PiReviewExport", function()
    require("pi-review").export()
  end, { desc = "Export pi-review comments" })

  registered = true
end

return M
