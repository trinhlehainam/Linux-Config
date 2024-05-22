if vim.g.vscode then
  return
end

-- IMPORTANT: make sure to setup neodev BEFORE lspconfig
local hasneodev, neodev = pcall(require, "neodev")
if not hasneodev then
  require("utils.log").error("neodev is not installed")
  return
end
neodev.setup({})

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
-- Prefer Telescope Diagnostic
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

vim.diagnostic.config({
  virtual_text = false,
})

-- Custom Diagnostic Signs
local signs = { Error = "", Warn = "", Hint = "", Info = "" }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

-- Putting vim lsp settings inside on_attach is no longer a best pratice
-- Instead use `LspAttach` event in an autocmd
-- See https://vinnymeller.com/posts/neovim_nightly_inlay_hints/#rust-toolsnvim-inlay-hints
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(args)
    if vim.version().minor < 10 then
      require("utils.log").warn("Inlay hints require Neovim 0.10+")
      return
    end

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities.inlayHintProvider then
      vim.keymap.set("n", "th",
        function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }), { bufnr = args.buf })
        end,
        { buffer = args.buf, desc = "Toggle inlay hints" })
    end
    -- whatever other lsp config you want
  end
})

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
--  See https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local servers = {
  dockerls = {},
  bashls = {},
  powershell_es = {},
  lua_ls = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
      completion = { callSnippet = "Replace" },
    },
  },
}

local language_settings = require('configs.lsp').language_settings

local on_attach = require('utils.lsp').on_attach

---@class custom.LspSetupHandler
---@field use_setup boolean
---@field setup? custom.LspConfig.Setup

---@type table<string, custom.LspSetupHandler>
local setup_handlers = {}

for _, settings in pairs(language_settings) do
  local server_name = settings.lspconfig.server
  if server_name == nil or server_name == "" then
    goto continue
  end
  servers[server_name] = settings.lspconfig.settings

  local setup = settings.lspconfig.setup
  local use_setup = settings.lspconfig.use_setup
  setup_handlers[server_name] = {
    use_setup = use_setup,
    setup = setup
  }

  ::continue::
end

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local hascmplsp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not hascmplsp then
  require("utils.log").error("cmp_nvim_lsp is not installed")
  return
end
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = cmp_nvim_lsp.default_capabilities(capabilities)

-- Setup mason so it can manage external tooling
require('mason').setup({
  inlay_hints = { enalbed = true },
})

-- Ensure the servers above are installed
local mason_lspconfig = require('mason-lspconfig')
mason_lspconfig.setup {
  ensure_installed = vim.tbl_keys(servers),
}

local lspconfig = require('lspconfig')
mason_lspconfig.setup_handlers {
  function(server_name)
    --- @type boolean
    local useSetup = vim.tbl_get(setup_handlers, server_name, 'use_setup')
    if useSetup ~= nil and type(useSetup) == "boolean" and not useSetup then
      return
    end

    --- @type custom.LspConfig.Setup | nil
    local setup = vim.tbl_get(setup_handlers, server_name, 'setup')
    if setup ~= nil and type(setup) == "function" then
      setup(capabilities, on_attach)
    else
      lspconfig[server_name].setup {
        capabilities = capabilities,
        on_attach = on_attach,
        settings = servers[server_name],
      }
    end
  end,
}

for _, settings in pairs(language_settings) do
  if settings.config ~= nil and type(settings.config) == "function" then
    settings.config()
  end
end

-- Language server for Postgres written in Rust
-- NOTE: This framework is not production ready yet, check back later
-- lspconfig.postgres_lsp.setup{}
--
