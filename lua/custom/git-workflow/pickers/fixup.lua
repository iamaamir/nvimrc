--[[
  Git Fixup Picker
  Creates a fixup commit for the selected commit
--]]

local utils = require 'custom.git-workflow.utils'

local M = {}

--- Validate commit hash format
---@param hash string Commit hash
---@return boolean True if valid
local function is_valid_hash(hash)
  return hash and type(hash) == 'string' and hash:match('^[%w]+$') and #hash >= 7
end

--- Create fixup commit for selected commit
---@param commit table Commit info with hash and message
local function create_fixup(commit)
  if not commit or not commit.hash then
    utils.notify_error('Invalid commit selection: missing commit hash')
    return
  end
  
  if not is_valid_hash(commit.hash) then
    utils.notify_error('Invalid commit hash format: ' .. tostring(commit.hash))
    return
  end
  
  -- Check if there are staged changes
  -- git diff --cached --quiet returns 0 if there are staged changes, 1 if none
  local staged_result = vim.fn.system('git diff --cached --quiet')
  if vim.v.shell_error ~= 0 then
    -- Exit code 1 means no staged changes
    utils.notify_error('No staged changes found. Please stage your changes first.')
    return
  end
  
  local escaped_hash = utils.shellescape(commit.hash)
  local result = utils.git_system('git commit --fixup=' .. escaped_hash)
  if result then
    local msg = commit.message and (' - ' .. commit.message) or ''
    utils.notify_success('Created fixup commit for: ' .. commit.hash .. msg)
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

