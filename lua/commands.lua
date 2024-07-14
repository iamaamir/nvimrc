local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local command = vim.api.nvim_create_user_command

-- [[ Basic Commands ]]
-- e.g command! -nargs=* EslintFix :!npx eslint % --fix
command('EslintFix', '!npx eslint % --fix', { bang = true })
command('BufOnly', 'wa | %bdelete | edit # | bdelete # | normal `"', {})
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

-- [[ Basic Autocommands end]]
