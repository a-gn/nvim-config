# Neovim configuration

All configuration lives in `init.lua`.

## Privacy

Swap files, write-backup files, and shada are all disabled. Nothing that touches file contents, register contents, command history, marks, or jump-list paths is ever written to disk.

## Plugins

Managed by [lazy.nvim](https://github.com/folke/lazy.nvim). Current plugins:

- **mason** + **mason-lspconfig** — installs and manages LSP server binaries (pyright, ruff pre-installed).
- **nvim-lspconfig** — wires the installed servers into Neovim. Built-in completion (Neovim 0.11+) is enabled on LSP attach; no completion plugin is needed.
- **nvim-tree** — file-tree sidebar, toggled with `<leader>e`.
- **telescope** — fuzzy finder.

## Session restore

When Neovim is opened with no file arguments, it automatically restores the window layout, open buffers, cursor positions, fold state, and tab pages from the previous session in the same directory. Sessions are stored in `~/.local/state/nvim/sessions/`, one file per working directory.

`sessionoptions` is set to `buffers,curdir,folds,tabpages,winsize,localoptions` — structural state only. Registers, history, marks, and search patterns are never saved (shada is disabled).

nvim-tree is closed just before the session is written so its special buffer is not captured, then reopened with `find_file` after restore. The tree panel's internal expand/collapse state is not preserved; it re-opens pointing at the current file.

## Private config overlay

At startup, `init.lua` scans `~/.config/nvim-private-config.d/` for subdirectories and sources every `*.lua` file found inside them. This directory is not part of this repo — it lives in the dotfiles repo alongside other private configuration and is symlinked into place by the dotfiles setup script.

To add a private extension, create a subdirectory under `nvim-private-config.d/` and place `.lua` files in it. They are loaded after the core config so they can rely on all plugins and keymaps being set up.
