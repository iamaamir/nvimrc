--[[
  Git Log Picker with Filters
  Browse git commits with advanced filtering options
  Supports filtering by author, date, file path, and message search
--]]

local utils = require 'custom.git-workflow.utils'

local M = {}

-- ============================================================================
-- Git Log Parsing
-- ============================================================================

--- Parse git log line with format: hash|author|date|message
---@param line string Git log line
---@return table|nil Parsed commit entry or nil
local function parse_log_line(line)
  if utils.is_empty_line(line) then
    return nil
  end

  -- Format: hash|author|date|message
  -- Using --pretty=format with custom separator
  local hash, author, date, message = line:match('^([%w]+)|([^|]+)|([^|]+)|(.+)$')
  if not hash or not author or not date or not message then
    return nil
  end

  return {
    hash = hash,
    author = author:gsub('^%s*(.-)%s*$', '%1'), -- Trim whitespace
    date = date:gsub('^%s*(.-)%s*$', '%1'), -- Trim whitespace
    message = message:gsub('^%s*(.-)%s*$', '%1'), -- Trim whitespace
  }
end

--- Build git log command with filters
---@param opts table Filter options
---@return table Git log command arguments
local function build_log_command(opts)
  local cmd = { 'git', 'log', '--pretty=format:%H|%an|%ad|%s', '--date=short', '--no-merges' }

  -- Filter by author
  if opts.author and opts.author ~= '' then
    table.insert(cmd, '--author=' .. opts.author)
  end

  -- Filter by date range
  if opts.since and opts.since ~= '' then
    table.insert(cmd, '--since=' .. opts.since)
  end
  if opts.until_date and opts.until_date ~= '' then
    table.insert(cmd, '--until=' .. opts.until_date)
  end

  -- Filter by file path
  if opts.file_path and opts.file_path ~= '' then
    table.insert(cmd, '--')
    table.insert(cmd, opts.file_path)
  end

  -- Filter by message (grep)
  if opts.grep and opts.grep ~= '' then
    table.insert(cmd, '--grep=' .. opts.grep)
  end

  -- Limit number of commits
  local limit = opts.commit_count or 100
  table.insert(cmd, '-n')
  table.insert(cmd, tostring(limit))

  return cmd
end

-- ============================================================================
-- Actions
-- ============================================================================

--- Show full commit details
---@param commit table Commit info
local function show_commit(commit)
  if not commit or not commit.hash then
    utils.notify_error('Invalid commit selection')
    return
  end

  -- Use Fugitive's Git show if available, otherwise use git show
  local ok = pcall(vim.cmd, 'Git show ' .. commit.hash)
  if not ok then
    -- Fallback to terminal command
    vim.cmd('terminal git show --color=always ' .. commit.hash)
  end
end

--- Checkout commit
---@param commit table Commit info
local function checkout_commit(commit)
  if not commit or not commit.hash then
    utils.notify_error('Invalid commit selection')
    return
  end

  local escaped_hash = utils.shellescape(commit.hash)
  local result = utils.git_system('git checkout ' .. escaped_hash)
  if result then
    utils.notify_success('Checked out commit: ' .. commit.hash)
  else
    utils.notify_error('Failed to checkout commit: ' .. commit.hash)
  end
end

--- Copy commit hash to clipboard
---@param commit table Commit info
local function copy_hash(commit)
  if not commit or not commit.hash then
    return
  end

  local ok1 = pcall(function()
    vim.fn.setreg('+', commit.hash)
  end)
  local ok2 = pcall(function()
    vim.fn.setreg('*', commit.hash)
  end)

  if ok1 or ok2 then
    utils.notify_success('Copied commit hash to clipboard: ' .. commit.hash)
  else
    utils.notify_error('Failed to copy commit hash to clipboard')
  end
end

-- ============================================================================
-- Picker
-- ============================================================================

--- Create and show git log picker with filters
---@param opts? table Optional configuration
function M.picker(opts)
  opts = opts or {}

  -- Validate git repo
  if not utils.ensure_git_repo() then
    return
  end

  local telescope = utils.load_telescope()

  -- Build initial git log command
  local log_cmd = build_log_command({
    author = opts.author or '',
    since = opts.since or '',
    until_date = opts.until_date or '',
    file_path = opts.file_path or '',
    grep = opts.grep or '',
    commit_count = opts.commit_count or 100,
  })

  -- Fetch commits
  local output = utils.git_systemlist(log_cmd, 'Failed to fetch git log')
  if not output then
    return
  end

  if #output == 0 then
    utils.notify_warn('No commits found matching the current filters.')
    return
  end

  -- Parse entries
  local entries = {}
  for _, line in ipairs(output) do
    local commit = parse_log_line(line)
    if commit then
      -- Create display string with rich information
      local short_hash = commit.hash:sub(1, 7)
      local display = string.format('%s │ %s │ %s │ %s', short_hash, commit.author, commit.date, commit.message)

      table.insert(entries, {
        value = commit,
        display = display,
        ordinal = commit.hash .. ' ' .. commit.author .. ' ' .. commit.date .. ' ' .. commit.message,
      })
    end
  end

  if #entries == 0 then
    utils.notify_warn('No valid commits found.')
    return
  end

  -- Create picker
  telescope.pickers.new({}, {
    prompt_title = opts.prompt_title or 'Git Log',
    finder = telescope.finders.new_table {
      results = entries,
      entry_maker = utils.create_entry_maker(),
    },
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
      preview_width = opts.preview_width or 0.50,
    },
    debounce = opts.debounce or 50,
    attach_mappings = function(prompt_bufnr, map)
      local actions = telescope.actions
      local action_state = telescope.action_state

      -- Default action: Show commit details
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          actions.close(prompt_bufnr)
          vim.schedule(function()
            show_commit(selection.value)
          end)
        end
      end)

      -- Normal mode: 's' to show commit
      local function show_commit_action()
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          actions.close(prompt_bufnr)
          vim.schedule(function()
            show_commit(selection.value)
          end)
        end
      end
      map('n', 's', show_commit_action)

      -- Normal mode: 'c' to checkout commit
      local function checkout_commit_action()
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          actions.close(prompt_bufnr)
          vim.schedule(function()
            checkout_commit(selection.value)
          end)
        end
      end
      map('n', 'c', checkout_commit_action)

      -- Normal mode: 'y' to copy commit hash
      local function copy_hash_action()
        local selection = action_state.get_selected_entry()
        if selection and selection.value then
          copy_hash(selection.value)
        end
      end
      map('n', 'y', copy_hash_action)

      -- Insert mode: <C-y> to copy commit hash
      map('i', '<C-y>', copy_hash_action)

      return true
    end,
  }):find()
end

return M

