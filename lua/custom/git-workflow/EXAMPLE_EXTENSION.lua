--[[
  Example: Adding a New Picker
  
  This file demonstrates how to extend the git-workflow plugin
  with a new custom picker.
--]]

local git = require('custom.git-workflow')

-- Example: Add a tag picker
-- Step 1: Create lua/custom/git-workflow/pickers/tag.lua
-- (See _template.lua for structure)

-- Step 2: Register the picker
git.register_picker('tag', 'custom.git-workflow.pickers.tag', {
  prompt_title = 'Git Tags',
  results_title = 'Tags',
  debounce = 50,
})

-- Step 3: Setup keymap (optional - can also be done in setup())
vim.keymap.set('n', '<leader>gt', git.tag(), {
  desc = '[G]it [T]ags',
  noremap = true,
  silent = true,
})

-- Example: Custom configuration
git.setup({
  keymaps = {
    -- Add your custom keymap
    tag = '<leader>gt',
  },
  pickers = {
    tag = {
      prompt_title = 'Select Tag',
      -- ... other options
    },
  },
})

