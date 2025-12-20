--[[
  Picker Template
  Copy this file to create a new picker
  
  Usage:
  1. Copy this file to pickers/your_picker.lua
  2. Implement the picker function
  3. Register it in your config using git.register_picker()
--]]

local utils = require 'custom.git-workflow.utils'

local M = {}

--- Create and show the picker
---@param opts? table Optional configuration
---   - prompt_title: string - Title for the picker
---   - results_title: string - Title for results
---   - debounce: number - Debounce delay (default: 50)
---   - ... (add your custom options here)
function M.picker(opts)
  opts = opts or {}
  
  -- Validate git repo (if needed)
  if not utils.ensure_git_repo() then
    return
  end
  
  local telescope = utils.load_telescope()
  
  -- Fetch data
  local output = utils.git_systemlist('git your-command-here', 'Failed to fetch data')
  if not output or #output == 0 then
    utils.notify_warn('No results found')
    return
  end
  
  -- Parse entries
  local entries = {}
  for _, line in ipairs(output) do
    if not utils.is_empty_line(line) then
      -- Parse your line format here
      -- Example:
      -- local value, display = line:match('pattern')
      -- if value then
      --   table.insert(entries, {
      --     value = { ... },
      --     display = display,
      --     ordinal = value,
      --   })
      -- end
    end
  end
  
  if #entries == 0 then
    utils.notify_warn('No results found')
    return
  end
  
  -- Create picker
  telescope.pickers.new({}, {
    prompt_title = opts.prompt_title or 'Your Picker Title',
    results_title = opts.results_title or 'Results',
    finder = telescope.finders.new_table {
      results = entries,
      entry_maker = utils.create_entry_maker(),
    },
    sorter = telescope.conf.generic_sorter {},
    debounce = opts.debounce or 50,
    
    -- Optional: Add previewer
    -- previewer = telescope.previewers.new_termopen_previewer {
    --   get_command = function(entry)
    --     return { 'git', 'show', entry.value.hash }
    --   end,
    -- },
    
    attach_mappings = function(prompt_bufnr)
      telescope.actions.select_default:replace(function()
        telescope.actions.close(prompt_bufnr)
        local selection = utils.get_selection()
        
        if selection and selection.value then
          -- Your action here
          -- Example:
          -- utils.notify_success('Selected: ' .. selection.value.name)
        end
      end)
      
      -- Optional: Add custom keymaps
      -- map('i', '<C-s>', function()
      --   -- Custom action
      -- end)
      
      return true
    end,
  }):find()
end

return M

