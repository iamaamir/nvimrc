--[[
  Git Remote Picker
  Lists git remotes and allows copying URL to clipboard
--]]

local utils = require 'custom.git-workflow.utils'

local M = {}

--- Create and show remote picker
---@param opts? table Optional configuration
function M.picker(opts)
  opts = opts or {}
  
  -- Validate git repo
  if not utils.ensure_git_repo() then
    return
  end
  
  local telescope = utils.load_telescope()
  
  -- Fetch remotes
  local output = utils.git_systemlist('git remote -v', 'Failed to fetch remotes')
  if not output or #output == 0 then
    utils.notify_warn('No remotes found')
    return
  end
  
  -- Parse entries
  local entries = {}
  for _, line in ipairs(output) do
    if not utils.is_empty_line(line) then
      local name, rest = line:match('^([^%s\t]+)[%s\t]+(.+)$')
      if name and rest then
        local url, action = rest:match('^(.+)%s+%((%w+)%)$')
        if url and action then
          table.insert(entries, {
            value = { name = name, url = url, action = action },
            display = name .. ' │ ' .. url .. ' (' .. action .. ')',
            ordinal = name,
          })
        end
      end
    end
  end
  
  if #entries == 0 then
    utils.notify_warn('No remotes found')
    return
  end
  
  -- Create picker
  telescope.pickers.new({}, {
    prompt_title = opts.prompt_title or 'Git Remotes',
    results_title = opts.results_title or 'Remotes',
    finder = telescope.finders.new_table {
      results = entries,
      entry_maker = utils.create_entry_maker(),
    },
    sorter = telescope.conf.generic_sorter {},
    debounce = opts.debounce or 50,
    layout_config = opts.preview_width and {
      preview_width = opts.preview_width,
    } or nil,
    attach_mappings = function(prompt_bufnr)
      telescope.actions.select_default:replace(function()
        telescope.actions.close(prompt_bufnr)
        local selection = utils.get_selection()
        
        if selection and selection.value and selection.value.url then
          local url = selection.value.url
          local name = selection.value.name or 'remote'
          
          -- Copy to clipboard
          local ok1 = pcall(function()
            vim.fn.setreg('+', url)
          end)
          local ok2 = pcall(function()
            vim.fn.setreg('*', url)
          end)
          
          if ok1 or ok2 then
            utils.notify_success('Copied ' .. name .. ' URL to clipboard: ' .. url)
          else
            utils.notify_error('Failed to copy URL to clipboard')
          end
        end
      end)
      return true
    end,
  }):find()
end

return M

