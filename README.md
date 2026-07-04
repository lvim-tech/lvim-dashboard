# lvim-dashboard

The start **dashboard** of the **lvim-tech** set — a declarative, section-based greeter buffer. It ships the
render **engine** only; the content (banner, menu, panes) is yours, defined as a `sections` tree of item
tables, generator functions, or references to the built-in sections (header / keys / recent_files / projects /
startup / session). Actions that open a finder go through **lvim-picker**.

Highlights: a single, idempotent teardown lifecycle (one autocmd group, deleted once — no double-delete
crash); palette self-theming (the `LvimUiDashboard*` groups track the colorscheme); optional auto-open on an
empty startup; side-by-side panes; auto-assigned keys.

## Requirements

Requires **Neovim >= 0.12.x**, [lvim-utils](https://github.com/lvim-tech/lvim-utils) (base) and
[lvim-picker](https://github.com/lvim-tech/lvim-picker) (the built-in `pick` actions open its finders).

## Installation

### lvim-installer (recommended)

```vim
:LvimInstaller plugins
```

### Native (vim.pack)

```lua
vim.pack.add({
    { src = "https://github.com/lvim-tech/lvim-utils" },
    { src = "https://github.com/lvim-tech/lvim-ui" },
    { src = "https://github.com/lvim-tech/lvim-picker" },
    { src = "https://github.com/lvim-tech/lvim-dashboard" },
})
require("lvim-dashboard").setup({ enable = true })
```

## Usage

`setup()` merges your options and, when `enable = true`, registers `:LvimDashboard` and (with `auto_open`) the
empty-startup auto-open. The module ships the engine only — define your `preset` (banner + menu) and/or
`sections`.

```vim
:LvimDashboard              " open the dashboard
:LvimDashboard pick files   " open a finder source directly
```

```lua
require("lvim-dashboard").setup({
    enable = true,
    preset = {
        header = table.concat({ "  L V I M  " }, "\n"),
        keys = {
            { icon = "", key = "f", desc = "Find File", action = ":LvimPicker files" },
            { icon = "", key = "r", desc = "Recent", action = ":LvimPicker oldfiles" },
            { icon = "", key = "q", desc = "Quit", action = ":qa" },
        },
    },
    sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
    },
})
```

## Configuration

`setup()` merges your options into the live config in place (LIST values like `sections` / `preset.keys`
REPLACE wholesale, never index-merge). The full default config:

```lua
require("lvim-dashboard").setup({
    enable = false, -- master switch (false = no auto-open, :LvimDashboard not registered)
    auto_open = true, -- auto-open on an empty startup (no file, single window, not piped stdin)
    should_open = nil, -- optional extra gate: a fun(): boolean returning false to suppress the auto-open
    hide_cursor = true, -- hide the hardware cursor while the dashboard is up (via lvim-utils.cursor)

    width = 60, -- the dashboard pane width (one column's character width)
    row = nil, -- fixed vertical position (rows); nil = centred
    col = nil, -- fixed horizontal position (cols); nil = centred
    pane_gap = 4, -- empty columns between side-by-side panes

    -- the pool of keys auto-assigned (in order) to items asking for one (autokey = true)
    autokeys = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",

    -- Shared building blocks the built-in sections pull from — DEFINE THESE IN YOUR CONFIG (engine ships empty).
    preset = {
        pick = nil, -- the pick(source, opts) backend; nil = the built-in (lvim-picker). Set a fun(source, opts) to override.
        keys = {}, -- the `keys` section rows: each { icon, key, desc, action, enabled? }
        header = "", -- the ASCII banner for the `header` section
    },

    -- The sections rendered top to bottom — item TABLE / generator fun(self) / { section = "<name>" } built-in
    -- (header / keys / recent_files / projects / startup / session). REPLACE wholesale to design your own.
    sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
    },

    -- Per-field formatters — how icon / header / footer / file fields become styled text.
    formats = {
        header = { "%s", align = "center" },
        footer = { "%s", align = "center" },
        icon = { "%s", width = 2, hl = "icon" },
    },

    -- Fallback leading glyphs for file/directory items with no devicon.
    icons = {
        file = "", -- nf-fa-file
        directory = "", -- nf-fa-folder
    },

    -- Highlight groups for every element (all default to the self-themed LvimUiDashboard* groups).
    hl = {
        header = "LvimUiDashboardHeader",
        footer = "LvimUiDashboardFooter",
        icon = "LvimUiDashboardIcon",
        key = "LvimUiDashboardKey",
        desc = "LvimUiDashboardDesc",
        title = "LvimUiDashboardTitle",
        file = "LvimUiDashboardFile",
        dir = "LvimUiDashboardDir",
        special = "LvimUiDashboardSpecial",
        normal = "LvimUiDashboardNormal",
        cursorline = "LvimUiDashboardCursorLine",
    },

    -- The dashboard buffer / window options (a clean, chrome-free scratch buffer).
    bo = {
        bufhidden = "wipe",
        buftype = "nofile",
        buflisted = false,
        filetype = "lvim-dashboard",
        swapfile = false,
        undofile = false,
        modifiable = false,
    },
    wo = {
        colorcolumn = "",
        cursorcolumn = false,
        cursorline = false,
        foldmethod = "manual",
        list = false,
        number = false,
        relativenumber = false,
        signcolumn = "no",
        spell = false,
        statuscolumn = "",
        wrap = false,
    },

    debug = false, -- trace the render/resolve passes to :messages (debugging only)
})
```

## License

BSD-3-Clause.
