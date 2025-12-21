--[[
  Git Workflow Plugin - Shared Utilities
  Common functions used across all pickers
--]]

local M = {}

-- ============================================================================
-- Telescope Integration
-- ============================================================================

--- Lazy load Telescope modules (only when needed)
---@return table Telescope modules
function M.load_telescope()
  return {
    pickers = require 'telescope.pickers',
    finders = require 'telescope.finders',
    conf = require('telescope.config').values,
    actions = require 'telescope.actions',
    action_state = require 'telescope.actions.state',
    previewers = require 'telescope.previewers',
  }
end

--- Get Telescope built-in pickers (lazy loaded)
---@return table Telescope builtin pickers
function M.get_builtin()
  return require 'telescope.builtin'
end

-- ============================================================================
-- Git Repository Validation
-- ============================================================================

-- Cache for git repo check (per buffer)
local git_repo_cache = {}

--- Check if current directory is a git repository
---@param cwd? string Optional working directory to check (defaults to current)
---@return boolean True if git repo
function M.is_git_repo(cwd)
  cwd = cwd or vim.fn.getcwd()
  
  -- Check cache first
  if git_repo_cache[cwd] ~= nil then
    return git_repo_cache[cwd]
  end
  
  -- Check git repo
  local cmd = cwd and string.format('cd %s && git rev-parse --git-dir 2>/dev/null', vim.fn.shellescape(cwd)) or 'git rev-parse --git-dir 2>/dev/null'
  local result = vim.fn.system(cmd)
  local is_repo = vim.v.shell_error == 0
  
  -- Cache result
  git_repo_cache[cwd] = is_repo
  
  return is_repo
end

--- Clear git repo cache (useful for testing or when repo status changes)
function M.clear_git_repo_cache()
  git_repo_cache = {}
end

--- Validate git repository and show error if not
---@param error_msg? string Custom error message
---@return boolean True if valid git repo
function M.ensure_git_repo(error_msg)
  if not M.is_git_repo() then
    vim.notify(error_msg or 'Not in a git repository', vim.log.levels.ERROR)
    return false
  end
  return true
end

-- ============================================================================
-- String Utilities
-- ============================================================================

--- Check if line is empty or whitespace-only
---@param line string Line to check
---@return boolean True if empty
function M.is_empty_line(line)
  return not line or line == '' or line:match('^%s*$')
end

--- Safely escape shell arguments
---@param str string String to escape
---@return string Escaped string
function M.shellescape(str)
  return vim.fn.shellescape(str)
end

--- Safely escape vim file names
---@param str string String to escape
---@return string Escaped string
function M.fnameescape(str)
  return vim.fn.fnameescape(str)
end

-- ============================================================================
-- Git Command Execution
-- ============================================================================

--- Execute git command and return output lines
---@param cmd string|table Git command (string or table of args)
---@param error_msg? string Custom error message
---@return table|nil Output lines or nil on error
function M.git_systemlist(cmd, error_msg)
  if not cmd then
    vim.notify('Git command is required', vim.log.levels.ERROR)
    return nil
  end
  
  local cmd_str = type(cmd) == 'table' and table.concat(cmd, ' ') or cmd
  
  -- Validate command doesn't contain dangerous patterns
  if type(cmd_str) == 'string' and (cmd_str:match(';') or cmd_str:match('&&') or cmd_str:match('||')) then
    vim.notify('Git command contains unsafe characters', vim.log.levels.ERROR)
    return nil
  end
  
  local ok, output = pcall(vim.fn.systemlist, cmd)
  if not ok then
    local err = error_msg or ('Git command execution failed: ' .. cmd_str)
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end
  
  if vim.v.shell_error ~= 0 then
    local err = error_msg or ('Git command failed: ' .. cmd_str)
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end
  
  return output
end

--- Execute git command and return single output string
---@param cmd string|table Git command
---@param error_msg? string Custom error message
---@return string|nil Output string or nil on error
function M.git_system(cmd, error_msg)
  if not cmd then
    vim.notify('Git command is required', vim.log.levels.ERROR)
    return nil
  end
  
  local cmd_str = type(cmd) == 'table' and table.concat(cmd, ' ') or cmd
  
  -- Validate command doesn't contain dangerous patterns
  if type(cmd_str) == 'string' and (cmd_str:match(';') or cmd_str:match('&&') or cmd_str:match('||')) then
    vim.notify('Git command contains unsafe characters', vim.log.levels.ERROR)
    return nil
  end
  
  local ok, output = pcall(vim.fn.system, cmd)
  if not ok then
    local err = error_msg or ('Git command execution failed: ' .. cmd_str)
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end
  
  if vim.v.shell_error ~= 0 then
    local err = error_msg or ('Git command failed: ' .. cmd_str)
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end
  
  return output
end

-- ============================================================================
-- Telescope Entry Maker
-- ============================================================================

--- Create standard entry maker for Telescope table finders
---@return function Entry maker function
function M.create_entry_maker()
  return function(entry)
    return {
      value = entry.value,
      display = tostring(entry.display),
      ordinal = tostring(entry.ordinal),
    }
  end
end

--- Get current selection from Telescope
---@return table|nil Selected entry or nil
function M.get_selection()
  return M.load_telescope().action_state.get_selected_entry()
end

-- ============================================================================
-- Git Status Parsing
-- ============================================================================

--- Parse a single git status porcelain line
---@param line string Git status line in porcelain format (XY filename)
---@return table|nil Entry table with status info or nil if invalid
function M.parse_git_status_line(line)
  if M.is_empty_line(line) then
    return nil
  end
  
  -- Git porcelain format: XY filename
  -- X = staged status, Y = unstaged status
  -- Common values: M=modified, A=added, D=deleted, ?=untracked, R=renamed
  local staged_code, unstaged_code, filepath = line:match('^(.)(.)%s+(.+)$')
  
  if not filepath then
    return nil
  end
  
  -- Determine status with clear indicators
  local status_icon = ''
  local status_text = ''
  local is_staged = false
  local is_unstaged = false
  
  -- Check staged status
  if staged_code == 'M' or staged_code == 'A' or staged_code == 'D' or staged_code == 'R' then
    is_staged = true
    status_icon = '●'  -- Staged indicator
    if staged_code == 'M' then
      status_text = 'STAGED (Modified)'
    elseif staged_code == 'A' then
      status_text = 'STAGED (Added)'
    elseif staged_code == 'D' then
      status_text = 'STAGED (Deleted)'
    elseif staged_code == 'R' then
      status_text = 'STAGED (Renamed)'
    end
  end
  
  -- Check unstaged status
  if unstaged_code == 'M' or unstaged_code == 'D' then
    is_unstaged = true
    if is_staged then
      status_icon = '●○'  -- Both staged and unstaged
      status_text = 'STAGED + UNSTAGED (Modified)'
    else
      status_icon = '○'  -- Unstaged indicator
      if unstaged_code == 'M' then
        status_text = 'UNSTAGED (Modified)'
      elseif unstaged_code == 'D' then
        status_text = 'UNSTAGED (Deleted)'
      end
    end
  end
  
  -- Check untracked
  if unstaged_code == '?' then
    status_icon = '?'
    status_text = 'UNTRACKED'
  end
  
  -- Create display string with clear indicators
  local display = string.format('%s [%s] %s', status_icon, status_text, filepath)
  
  return {
    value = {
      path = filepath,
      staged_code = staged_code,
      unstaged_code = unstaged_code,
      is_staged = is_staged,
      is_unstaged = is_unstaged,
      status_text = status_text,
    },
    display = display,
    ordinal = filepath,
  }
end

--- Parse git status porcelain output into entries
---@param output table Array of lines from git status --porcelain
---@return table Array of entry tables
function M.parse_git_status_porcelain(output)
  local entries = {}
  
  if not output then
    return entries
  end
  
  for _, line in ipairs(output) do
    local entry = M.parse_git_status_line(line)
    if entry then
      table.insert(entries, entry)
    end
  end
  
  return entries
end

-- ============================================================================
-- Notification Helpers
-- ============================================================================

-- Get notification config (lazy loaded from plugin config)
local function get_notification_config()
  -- Try to get config from plugin
  local ok, plugin = pcall(require, 'custom.git-workflow')
  if ok and plugin._config then
    return plugin._config.notifications or { enabled = true, level = vim.log.levels.INFO }
  end
  -- Default if plugin not loaded yet
  return { enabled = true, level = vim.log.levels.INFO }
end

--- Show success notification
---@param msg string Message to show
function M.notify_success(msg)
  local notif_config = get_notification_config()
  if notif_config.enabled then
    vim.notify(msg, notif_config.level)
  end
end

--- Show error notification
---@param msg string Message to show
function M.notify_error(msg)
  local notif_config = get_notification_config()
  if notif_config.enabled then
    vim.notify(msg, vim.log.levels.ERROR)
  end
end

--- Show warning notification
---@param msg string Message to show
function M.notify_warn(msg)
  local notif_config = get_notification_config()
  if notif_config.enabled then
    vim.notify(msg, vim.log.levels.WARN)
  end
end

return M

