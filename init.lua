-- GUI
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.background = 'dark'
vim.opt.colorcolumn = '121'

-- Formatting
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.expandtab = true

-- Privacy: disable all features that persist file contents or paths to disk.
-- swapfile: stores buffer contents for crash recovery.
-- writebackup: creates a full file copy before each write.
-- shadafile=NONE: disables shada entirely (register contents, file paths in
--   marks/buffer-list/jump-list, command and search history).
vim.opt.swapfile = false
vim.opt.writebackup = false
vim.opt.shadafile = "NONE"

-- Session: layout only — registers/history/marks are excluded because shada
-- is disabled above; sessionoptions controls only structural state.
vim.opt.sessionoptions = "buffers,curdir,folds,tabpages,winsize"

-- Use system clipboard
vim.opt.clipboard = 'unnamed'

-- Required by nvim-tree; must be set before plugins load
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Installs and manages LSP server binaries
  { "mason-org/mason.nvim", opts = {} },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = { ensure_installed = { "pyright", "ruff" } },
  },

  -- Configures the installed servers
  {
    "neovim/nvim-lspconfig",
    dependencies = { "mason-org/mason-lspconfig.nvim" },
    config = function()
        vim.lsp.enable({ "pyright", "ruff" })
    end,
  },

  -- File tree
  { "nvim-tree/nvim-tree.lua", opts = {} },

  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- Claude Code IDE bridge: lets `/ide` discover this Neovim, exposes the
  -- active file and selection to a coupled Claude Code terminal.
  {
    "coder/claudecode.nvim",
    opts = { terminal = { provider = "native" } },
  },
})

-- Built-in completion (Neovim 0.11+, no plugin needed)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, args.data.client_id, args.buf, {
        autotrigger = false,
        autocomplete_trigger_character_limit = -1,
      })

      -- Completion menu keybindings
      local opts = { buffer = args.buf, silent = true }

      -- Tab accepts the completion
      vim.keymap.set("i", "<Tab>", function()
        if vim.fn.pumvisible() == 1 then
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-y>", true, true, true), "n")
        else
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, true, true), "n")
        end
      end, opts)

      -- Escape closes the completion menu without inserting anything
      vim.keymap.set("i", "<Esc>", function()
        if vim.fn.pumvisible() == 1 then
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-e>", true, true, true), "n")
        else
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, true, true), "n")
        end
      end, opts)

      -- Enter and Space keep their normal behavior even with the popup open
      vim.keymap.set("i", "<CR>", function()
        if vim.fn.pumvisible() == 1 then
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-e>", true, true, true), "n")
        else
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, true, true), "n")
        end
      end, opts)

      vim.keymap.set("i", "<Space>", function()
        if vim.fn.pumvisible() == 1 then
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-e>", true, true, true), "n")
        else
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Space>", true, true, true), "n")
        end
      end, opts)
    end
    -- gd is not a 0.11 default; K, grn, gra, grr, gri already are
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = args.buf })
  end,
})

vim.keymap.set("n", "<leader>e", ":NvimTreeFindFileToggle<CR>", { silent = true })

-- Private config overlay: load all *.lua files from subdirectories of
-- ~/.config/nvim-private-config.d/ if that directory exists.
-- This keeps machine-specific or sensitive config out of the public repo.
local _private_dir = vim.fn.expand("~/.config/nvim-private-config.d")
if vim.fn.isdirectory(_private_dir) == 1 then
  for _, subdir in ipairs(vim.fn.glob(_private_dir .. "/*", false, true)) do
    for _, f in ipairs(vim.fn.glob(subdir .. "/*.lua", false, true)) do
      dofile(f)
    end
  end
end

-- Per-directory session save/restore.
-- NvimTree is closed before saving so its window is absent from the session
-- file, then reopened afterwards so it is always present on reopen.
local _session_dir = vim.fn.stdpath("state") .. "/sessions"
vim.fn.mkdir(_session_dir, "p")

local function _session_file()
  return _session_dir .. "/" .. vim.fn.getcwd():gsub("/", "%%") .. ".vim"
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    pcall(function() require("nvim-tree.api").tree.close() end)
    vim.cmd("mksession! " .. vim.fn.fnameescape(_session_file()))
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  nested = true,  -- allow BufRead & LSP autocmds to fire for restored buffers
  callback = function()
    if vim.fn.argc() == 0 then
      local sf = _session_file()
      if vim.fn.filereadable(sf) == 1 then
        vim.cmd("silent! source " .. vim.fn.fnameescape(sf))
      end
    end
    require("nvim-tree.api").tree.open({ find_file = true })
    local non_tree = vim.tbl_filter(function(w)
      return vim.bo[vim.api.nvim_win_get_buf(w)].filetype ~= "NvimTree"
    end, vim.api.nvim_list_wins())
    if #non_tree == 1 then
      vim.api.nvim_set_current_win(non_tree[1])
    end
  end,
})
