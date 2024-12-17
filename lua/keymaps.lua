-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
local map = vim.keymap.set

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map('i', 'jk', '<Esc>')
map('n', 'x', '"_x')

-- Diagnostic keymaps
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
map('n', '<leader>de', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Yank to clipboard
map('n', 'Y', '"+yg$') --to the end of line
map('n', 'y', '"+y')
map('v', 'y', '"+y')

--  substitue Current/Selected Word
map({ 'n', 'v' }, '<leader>st', function()
  local word
  if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' or vim.fn.mode() == '\22' then
    -- Save the current selection
    vim.cmd 'noau normal! "vy"'
    word = vim.fn.getreg 'v'
    vim.fn.setreg('v', {})
  else
    word = vim.fn.expand '<cword>'
  end

  if word == '' then
    print 'No Selection found'
    return
  end

  local escaped = vim.fn.escape(word, '/\\')
  local cmd = string.format('%%s/%s/', escaped)
  vim.fn.feedkeys(':' .. cmd, 'n')
end)

map('n', 'W', function()
  vim.cmd 'w' -- save the file
  vim.cmd 'Gw!' -- stage the file
  vim.cmd 'G cmp' -- write the commit a and push it
end)

map('n', '<leader>gf', [[:lua require('custom.git-fixup').fixup_picker()<CR>]], { noremap = true, silent = true })

map('n', '<leader>i', function()
  local commits = vim.fn.systemlist 'git log --oneline -n 20'
  vim.ui.select(commits, {
    prompt = 'Select commit:',
  }, function(choice)
    if choice then
      local commit_hash = choice:match '^%w+'
      vim.cmd('DiffviewOpen ' .. commit_hash)
    end
  end)
end, { desc = 'list the commits and compare', noremap = true })

map('n', '<leader>T', function()
  local stashes = vim.fn.systemlist 'git stash list'
  vim.ui.select(stashes, {
    prompt = 'Select stash:',
  }, function(choice)
    if choice then
      local stash_name = choice:match '^[^:]+'
      vim.cmd('Git stash apply ' .. stash_name)
      vim.cmd 'DiffviewRefresh'
    end
  end)
end)
--- vim: ts=2 sts=2 sw=2 et
