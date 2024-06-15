local LanguageSetting = require("configs.lsp.base")
local M = LanguageSetting:new()

local log = require("utils.log")
local common = require("utils.common")

M.treesitter.filetypes = { "php" }
if common.IS_WINDOWS then
	M.lspconfig.server = "intelephense"
else
	-- NOTE: phpactor is not yet supported for Windows platform.
	M.lspconfig.server = "phpactor"
end
M.lspconfig.use_masonlsp_setup = true

M.formatterconfig.servers = { "blade-formatter", "php-cs-fixer" }
M.formatterconfig.formatters_by_ft = {
	blade = { "blade-formatter" },
	-- php = { "php-cs-fixer" },
}

M.linterconfig.servers = { "easy-coding-standard" }
M.linterconfig.linters_by_ft = {
	-- php = { "easy-coding-standard" },
}

M.lspconfig.setup = function(capabilities, on_attach)
	-- NOTE: laravel.nvim use lspconfig to detect installed servers
	-- Need to set up lspconfig first
	require("lspconfig")[M.lspconfig.server].setup({
		capabilities = capabilities,
		on_attach = on_attach,
	})
end

M.after_masonlsp_setup = function()
	local haslaravel, laravel = pcall(require, "laravel")

	if not haslaravel then
		log.error("laravel.nvim is not installed")
		return
	end

	laravel.setup({
		features = {
			null_ls = {
				enable = false,
			},
		},
	})

	vim.keymap.set("n", "<leader>la", ":Laravel artisan<cr>", { desc = "[L]aravel [A]rtisan" })
	vim.keymap.set("n", "<leader>lm", ":Laravel related<cr>", { desc = "[L]aravel [R]elated" })
	vim.keymap.set("n", "<leader>lr", ":Laravel routes<cr>", { desc = "Find [L]aravel [R]outes" })
end

return M
