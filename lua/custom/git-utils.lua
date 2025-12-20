--[[
  Git Utilities - Custom Pickers
  Only contains utilities not available in Telescope built-ins
  
  Telescope built-ins used for:
  - git_commits: telescope.builtin.git_commits
  - git_branches: telescope.builtin.git_branches
  - git_stash: telescope.builtin.git_stash
  - git_status: telescope.builtin.git_status (with auto-refresh!)
  - git_file_history: telescope.builtin.git_bcommits
--]]

local M = {}

-- ============================================================================
-- CORE HELPERS
-- ============================================================================

-- Lazy load Telescope modules
local function load_telescope()
  return {
    pickers = require 'telescope.pickers',
    finders = require 'telescope.finders',
    conf = require('telescope.config').values,
    actions = require 'telescope.actions',
    action_state = require 'telescope.actions.state',
    previewers = require 'telescope.previewers',
  }
end

-- Check if we're in a git repo
local function is_git_repo()
  local result = vim.fn.system('git rev-parse --git-dir 2>/dev/null')
  return vim.v.shell_error == 0
end

-- Check if line is empty
local function is_empty_line(line)
  return not line or line == '' or line:match('^%s*$')
end

-- Create standard entry maker for Telescope
local function create_entry_maker()
  return function(entry)
    return {
      value = entry.value,
      display = tostring(entry.display),
      ordinal = tostring(entry.ordinal),
    }
  end
end

-- Get selection from Telescope
local function get_selection()
  return load_telescope().action_state.get_selected_entry()
end

-- ============================================================================
-- REMOTE PICKER (Custom - Telescope doesn't have this)
-- ============================================================================

M.remote_picker = function()
  local telescope = load_telescope()

  -- Validate git repo
  if not is_git_repo() then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return
  end

  -- Fetch remotes
  local output = vim.fn.systemlist('git remote -v')
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to fetch remotes', vim.log.levels.ERROR)
    return
  end

  if not output or #output == 0 then
    vim.notify('No remotes found', vim.log.levels.WARN)
    return
  end

  -- Parse entries
  local entries = {}
  for _, line in ipairs(output) do
    if not is_empty_line(line) then
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
    vim.notify('No remotes found', vim.log.levels.WARN)
    return
  end

  -- Create picker
  telescope.pickers.new({}, {
    prompt_title = 'Git Remotes',
    results_title = 'Remotes',
    finder = telescope.finders.new_table {
      results = entries,
      entry_maker = create_entry_maker(),
    },
    sorter = telescope.conf.generic_sorter {},
    debounce = 50,
    attach_mappings = function(prompt_bufnr)
      telescope.actions.select_default:replace(function()
        telescope.actions.close(prompt_bufnr)
        local selection = get_selection()
        if selection and selection.value and selection.value.url then
          -- Copy remote URL to clipboard
          local url = selection.value.url
          local name = selection.value.name or 'remote'
          
          local ok1 = pcall(function()
            vim.fn.setreg('+', url)
          end)
          local ok2 = pcall(function()
            vim.fn.setreg('*', url)
          end)
          
          if ok1 or ok2 then
            vim.notify('Copied ' .. name .. ' URL to clipboard: ' .. url, vim.log.levels.INFO)
          else
            vim.notify('Failed to copy URL to clipboard', vim.log.levels.ERROR)
          end
        end
      end)
      return true
    end,
  }):find()
end

return M
