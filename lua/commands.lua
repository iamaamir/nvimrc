local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local command = vim.api.nvim_create_user_command

-- [[ Basic Commands ]]
-- e.g command! -nargs=* EslintFix :!npx eslint % --fix
command('EslintFix', ':w | !npx eslint % --fix', { bang = true })
command('BufOnly', 'wa | %bdelete | edit # | bdelete # | normal `"', {})

-- restarts everything except Copilot for the current buffer
vim.api.nvim_create_user_command('LspRestartSafe', function()
  local bufnr = vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if client.name ~= 'GitHub Copilot' then
      pcall(vim.cmd, 'LspRestart ' .. client.name)
    end
  end
end, {})
-- [[ Basic Commands end]]
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`
--
-- Highlight when yanking (copying) text
autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Update a buffer's contents on focus if it changed outside of Vim.
autocmd({ 'FocusGained', 'BufEnter' }, {
  pattern = '*',
  group = augroup('update_buffer_contents_if_changed_outside_neovim', {}),
  callback = function()
    vim.api.nvim_command 'checktime'
  end,
})

autocmd('VimEnter', {
  callback = function()
    if vim.fn.argv(0) == '.' then
      require('telescope.builtin').find_files()
    end
  end,
})
-- [[ Basic Autocommands end]]
