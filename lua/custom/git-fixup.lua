local M = {}

-- Lazy load Telescope modules (only when function is called)
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

-- Get commits with more details
local function get_recent_commits(count)
  count = count or 30 -- Increased from 10 to 30
  local output = vim.fn.systemlist('git log --oneline -n ' .. count)
  local commits = {}
  for _, line in ipairs(output) do
    local hash, message = line:match '(%w+)%s(.+)'
    if hash and message then
      table.insert(commits, { hash = hash, message = message })
    end
  end
  return commits
end

local function create_fixup(commit)
  local result = vim.fn.system('git commit --fixup=' .. commit.hash)
  if vim.v.shell_error == 0 then
    vim.notify('Created fixup commit for: ' .. commit.hash .. ' - ' .. commit.message, vim.log.levels.INFO)
  else
    vim.notify('Failed to create fixup commit. Make sure you have staged changes.', vim.log.levels.ERROR)
  end
end

function M.fixup_picker()
  local telescope = load_telescope()

  telescope.pickers
    .new({}, {
      prompt_title = 'Select commit to fixup',
      finder = telescope.finders.new_oneshot_job({ 'git', 'log', '--oneline', '-n', '30' }, {
        entry_maker = function(line)
          local hash, message = line:match('(%w+)%s(.+)')
          if hash and message then
            return {
              value = { hash = hash, message = message },
              display = hash .. ' ' .. message,
              ordinal = hash .. ' ' .. message,
            }
          end
          return nil
        end,
      }),
      sorter = telescope.conf.generic_sorter {},
      previewer = telescope.previewers.new_termopen_previewer {
        get_command = function(entry)
          return { 'git', 'show', '--color=always', '--stat', '--patch', entry.value.hash }
        end,
      },
      layout_config = {
        preview_width = 0.65, -- 65% of screen width for preview
      },
      attach_mappings = function(prompt_bufnr)
        telescope.actions.select_default:replace(function()
          telescope.actions.close(prompt_bufnr)
          local selection = telescope.action_state.get_selected_entry()
          if selection then
            create_fixup(selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

return M
