# agent-review.nvim

`agent-review.nvim` is a small Neovim plugin for leaving review notes in code and turning them into a prompt you can send back to your coding agent.

## Features

- line and range comments
- file comments
- a small floating editor for multi-line notes
- signcolumn markers for commented locations
- hover preview at the cursor
- a `Snacks.picker` list of all comments
- export to a scratch buffer, with optional clipboard copy
- ephemeral comments by default

## Installation

```lua
{
  "joelazar/agent-review.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  opts = {},
}
```

## Setup

```lua
require("agent-review").setup({
  sign = {
    text = "●",
    texthl = "DiagnosticHint",
  },
  hover = {
    enabled = true,
    delay = 600,
  },
  export = {
    copy_to_clipboard = true,
    clipboard_register = "+",
  },
  storage = {
    persist = false,
  },
})
```

## Commands

- `:AgentReviewComment` — add or edit a comment on the current line or selected range
- `:AgentReviewFileComment` — add or edit a file comment
- `:AgentReviewToggle` — show or hide comments at the cursor
- `:AgentReviewDelete` — delete a comment at the cursor
- `:AgentReviewList` — open all comments for the current repo
- `:AgentReviewExport` — open the export in a scratch buffer

Inside the `Snacks` picker:

- `e` / `<C-e>` — edit the selected comment
- `dd` / `<C-d>` — delete the selected comment(s)

## Suggested keymaps

```lua
vim.keymap.set("n", "<leader>rc", "<cmd>AgentReviewComment<cr>")
vim.keymap.set("x", "<leader>rc", ":AgentReviewComment<cr>")
vim.keymap.set("n", "<leader>rf", "<cmd>AgentReviewFileComment<cr>")
vim.keymap.set("n", "<leader>rt", "<cmd>AgentReviewToggle<cr>")
vim.keymap.set("n", "<leader>rd", "<cmd>AgentReviewDelete<cr>")
vim.keymap.set("n", "<leader>rl", "<cmd>AgentReviewList<cr>")
vim.keymap.set("n", "<leader>re", "<cmd>AgentReviewExport<cr>")
```

## Export shape

The export stays short and starts with the file location:

````md
Please address these review comments:

- /absolute/path/to/lua/agent-review/export.lua:12
  This can be shorter and more direct.

  ```lua
  local value = build_something()
  ```

- /absolute/path/to/lua/agent-review/init.lua:40-45
  Extract this block into a helper.

  ```lua
  if condition then
    do_the_thing()
  end
  ```

- /absolute/path/to/lua/agent-review/store.lua
  This file is mixing storage and formatting concerns.
````

## Lualine component

Shows the comment count for the current repo. Hidden when the count is zero.
Click it to run `:AgentReviewList`.

```lua
require("lualine").setup({
  sections = {
    lualine_x = { require("agent-review").lualine() },
  },
})
```

Overrides:

```lua
require("agent-review").lualine({
  icon = "",
  color = "DiagnosticInfo",
  show_zero = true,       -- keep visible when count is 0
  format = "%s %d notes", -- args are (icon, count)
  on_click = function() vim.cmd("AgentReviewExport") end,
})
```

## Testing

Run the smoke test from the repo root:

```bash
nvim --headless -u NONE -S tests/smoke.lua
```

## Notes

Comments are ephemeral by default, so they only live for the current Neovim session.

If you want them to persist:

```lua
require("agent-review").setup({
  storage = {
    persist = true,
  },
})
```

The comment editor opens in a small floating buffer. Press `<C-s>`, `<D-s>`, or `<leader>w` to save. Use `q` or `<Esc>` in normal mode to cancel.

Hover preview is on by default. It opens after `hover.delay` milliseconds and disappears when you move away.

If your agent launches Neovim and sets the `AGENT_REVIEW_EXPORT_PATH`, `AGENT_REVIEW_EXPORT_TOKEN`, and `AGENT_REVIEW_EXPORT_ROOT` env vars, comments are written to that path on `VimLeavePre` as a JSON payload (`{ version, token, root, text }`) and the agent can read it back when Neovim exits. [pi-nvim](https://github.com/joelazar/pi-nvim) is one such integration: it opens Neovim from inside [pi](https://github.com/badlogic/pi-mono) and drops the exported text into pi's input editor on return.
