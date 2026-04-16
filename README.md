# pi-review.nvim

`pi-review.nvim` is a small Neovim plugin for leaving review notes in code and turning them into a prompt you can send back to pi.

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
  "joelazar/pi-review.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  opts = {},
}
```

## Setup

```lua
require("pi-review").setup({
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

- `:PiReviewComment` — add or edit a comment on the current line or selected range
- `:PiReviewFileComment` — add or edit a file comment
- `:PiReviewToggle` — show or hide comments at the cursor
- `:PiReviewDelete` — delete a comment at the cursor
- `:PiReviewList` — open all comments for the current repo
- `:PiReviewExport` — open the export in a scratch buffer

Inside the `Snacks` picker:

- `e` / `<C-e>` — edit the selected comment
- `dd` / `<C-d>` — delete the selected comment(s)

## Suggested keymaps

```lua
vim.keymap.set("n", "<leader>rc", "<cmd>PiReviewComment<cr>")
vim.keymap.set("x", "<leader>rc", ":PiReviewComment<cr>")
vim.keymap.set("n", "<leader>rf", "<cmd>PiReviewFileComment<cr>")
vim.keymap.set("n", "<leader>rt", "<cmd>PiReviewToggle<cr>")
vim.keymap.set("n", "<leader>rd", "<cmd>PiReviewDelete<cr>")
vim.keymap.set("n", "<leader>rl", "<cmd>PiReviewList<cr>")
vim.keymap.set("n", "<leader>re", "<cmd>PiReviewExport<cr>")
```

## Export shape

The export stays short and starts with the file location:

````md
Please address these review comments:

- /absolute/path/to/lua/pi-review/export.lua:12
  This can be shorter and more direct.
  ```lua
  local value = build_something()
  ```

- /absolute/path/to/lua/pi-review/init.lua:40-45
  Extract this block into a helper.
  ```lua
  if condition then
    do_the_thing()
  end
  ```

- /absolute/path/to/lua/pi-review/store.lua
  This file is mixing storage and formatting concerns.
````

## Testing

Run the smoke test from the repo root:

```bash
nvim --headless -u NONE -S tests/smoke.lua
```

## Notes

Comments are ephemeral by default, so they only live for the current Neovim session.

If you want them to persist:

```lua
require("pi-review").setup({
  storage = {
    persist = true,
  },
})
```

The comment editor opens in a small floating buffer. Press `<C-s>`, `<D-s>`, or `<leader>w` to save. Use `q` or `<Esc>` in normal mode to cancel.

Hover preview is on by default. It opens after `hover.delay` milliseconds and disappears when you move away.

If you launch Neovim from pi's `nvim` extension, comments are exported through a one-shot temp file on `VimLeavePre` and loaded back into pi's input editor when Neovim exits.

See [PLAN.md](./PLAN.md) for the current plan.
