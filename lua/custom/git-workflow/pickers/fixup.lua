--[[
  Git Fixup Picker
  Creates a fixup commit for the selected commit
--]]

local utils = require 'custom.git-workflow.utils'

local M = {}

--- Create fixup commit for selected commit
---@param commit table Commit info with hash and message
local function create_fixup(commit)
  if not commit or not commit.hash then
    utils.notify_error('Invalid commit selection')
    return
  end
  
  local result = utils.git_system('git commit --fixup=' .. commit.hash)
  if result then
    utils.notify_success('Created fixup commit for: ' .. commit.hash .. ' - ' .. (commit.message or ''))
  else
    utils.notify_error('Failed to create fixup commit. Make sure you have staged changes.')
  end
end

--- Create and show fixup picker
---@param opts? table Optional configuration
function M.picker(opts)
  opts = opts or {}
  
  -- Validate git repo
  if not utils.ensure_git_repo() then
    return
  end
  
  local telescope = utils.load_telescope()
  local commit_count = opts.commit_count or 30
  
  telescope.pickers.new({}, {
    prompt_title = opts.prompt_title or 'Select commit to fixup',
    finder = telescope.finders.new_oneshot_job(
      { 'git', 'log', '--oneline', '-n', tostring(commit_count) },
      {
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
      }
    ),
    sorter = telescope.conf.generic_sorter {},
    previewer = telescope.previewers.new_termopen_previewer {
      get_command = function(entry)
        if entry and entry.value and entry.value.hash then
          return { 'git', 'show', '--color=always', '--stat', '--patch', entry.value.hash }
        end
        return { 'echo', 'Invalid entry' }
      end,
    },
    layout_config = {
      preview_width = opts.preview_width or 0.65,
    },
    debounce = opts.debounce or 50,
    attach_mappings = function(prompt_bufnr)
      telescope.actions.select_default:replace(function()
        telescope.actions.close(prompt_bufnr)
        local selection = utils.get_selection()
        if selection and selection.value then
          create_fixup(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

return M

