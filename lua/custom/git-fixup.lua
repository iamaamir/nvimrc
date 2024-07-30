local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'

local M = {}

local function get_recent_commits()
  local output = vim.fn.systemlist 'git log --oneline -n 10'
  local commits = {}
  for _, line in ipairs(output) do
    local hash, message = line:match '(%w+)%s(.+)'
    table.insert(commits, { hash = hash, message = message })
  end
  return commits
end

local function create_fixup(commit)
  vim.fn.system('git commit --fixup=' .. commit.hash)
  print('Created fixup commit for: ' .. commit.hash .. ' - ' .. commit.message)
end

function M.fixup_picker()
  local commits = get_recent_commits()

  pickers
    .new({}, {
      prompt_title = 'Select commit to fixup',
      finder = finders.new_table {
        results = commits,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.hash .. ' ' .. entry.message,
            ordinal = entry.hash .. ' ' .. entry.message,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          create_fixup(selection.value)
        end)
        return true
      end,
    })
    :find()
end

return M
