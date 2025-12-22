--[[
  Git Rebase Picker
  Interactive rebase picker for selecting base branch/commit and starting rebase
--]]

local utils = require 'custom.git-workflow.utils'

local M = {}

-- ============================================================================
-- Git Rebase Helpers
-- ============================================================================

--- Get current branch name
---@return string|nil Current branch name
local function get_current_branch()
  local branch = utils.git_system('git rev-parse --abbrev-ref HEAD', 'Failed to get current branch')
  if branch then
    return branch:gsub('^%s*(.-)%s*$', '%1') -- Trim whitespace
  end
  return nil
end

--- Get commits from current branch (for rebasing onto same branch)
---@param limit? number Maximum number of commits to show (default: 50)
---@return table List of commit entries
local function get_current_branch_commits(limit)
  limit = limit or 50
  local current_branch = get_current_branch()
  if not current_branch then
    return {}
  end

  -- Get commits from current branch
  local cmd = string.format('git log --oneline --pretty=format:"%%h|%%an|%%ad|%%s" --date=short -n %d %s', limit, current_branch)
  local commits = utils.git_systemlist(cmd, 'Failed to get branch commits')
  if not commits or #commits == 0 then
    return {}
  end

  local parsed_commits = {}
  for _, line in ipairs(commits) do
    if not utils.is_empty_line(line) then
      local hash, author, date, message = line:match('^([%w]+)|([^|]+)|([^|]+)|(.+)$')
      if hash and author and date and message then
        table.insert(parsed_commits, {
          name = hash, -- Use hash as name for commits
          hash = hash,
          author = author:gsub('^%s*(.-)%s*$', '%1'),
          date = date:gsub('^%s*(.-)%s*$', '%1'),
          message = message:gsub('^%s*(.-)%s*$', '%1'),
          is_commit = true, -- Mark as commit (not branch)
          current = false,
          display = string.format('📝 %s %s (%s)', hash:sub(1, 7), message, author),
        })
      end
    end
  end

  return parsed_commits
end

--- Get list of branches (local and remote) that can be used as rebase base
---@return table List of branch entries
local function get_rebase_branches()
  local branches = {}
  local current_branch = get_current_branch()

  -- Get local branches (compatible with older git versions)
  local local_branches = utils.git_systemlist('git branch', 'Failed to get local branches')
  if local_branches then
    for _, line in ipairs(local_branches) do
      -- Parse "  branch_name" or "* branch_name" format
      local branch = line:match('^%s*%*?%s*(.+)$')
      branch = branch and branch:gsub('^%s*(.-)%s*$', '%1') or nil
      if branch and branch ~= '' and branch ~= current_branch then
        table.insert(branches, {
          name = branch,
          remote = false,
          current = false,
          is_commit = false, -- Mark as branch
          display = '📌 ' .. branch,
        })
      end
    end
  end

  -- Get remote branches (compatible with older git versions)
  local remote_branches = utils.git_systemlist('git branch -r', 'Failed to get remote branches')
  if remote_branches then
    for _, line in ipairs(remote_branches) do
      -- Parse "  origin/branch_name" format
      local branch = line:match('^%s*%*?%s*(.+)$')
      branch = branch and branch:gsub('^%s*(.-)%s*$', '%1') or nil
      -- Skip HEAD references
      if branch and branch ~= '' and not branch:match('HEAD') then
        table.insert(branches, {
          name = branch,
          remote = true,
          current = false,
          is_commit = false, -- Mark as branch
          display = '🌐 ' .. branch,
        })
      end
    end
  end

  return branches
end

--- Get commits that would be rebased (commits ahead of base)
---@param base string Base branch/commit
---@param is_commit? boolean Whether base is a commit hash (true) or branch (false)
---@return table|nil List of commits
local function get_rebase_commits(base, is_commit)
  local current_branch = get_current_branch()
  if not current_branch then
    return nil
  end

  local cmd
  if is_commit then
    -- If rebasing onto a commit in the same branch, rebase commits after that commit
    -- Use ^base to exclude the base commit itself
    cmd = string.format('git log --oneline --pretty=format:"%%h|%%an|%%ad|%%s" --date=short %s^..HEAD', base)
  else
    -- If rebasing onto a branch, get commits that are in current branch but not in base
    cmd = string.format('git log --oneline --pretty=format:"%%h|%%an|%%ad|%%s" --date=short %s..%s', base, current_branch)
  end

  local commits = utils.git_systemlist(cmd, 'Failed to get rebase commits')
  if not commits or #commits == 0 then
    return nil
  end

  local parsed_commits = {}
  for _, line in ipairs(commits) do
    if not utils.is_empty_line(line) then
      local hash, author, date, message = line:match('^([%w]+)|([^|]+)|([^|]+)|(.+)$')
      if hash and author and date and message then
        table.insert(parsed_commits, {
          hash = hash,
          author = author:gsub('^%s*(.-)%s*$', '%1'),
          date = date:gsub('^%s*(.-)%s*$', '%1'),
          message = message:gsub('^%s*(.-)%s*$', '%1'),
        })
      end
    end
  end

  return parsed_commits
end

-- ============================================================================
-- Actions
-- ============================================================================

--- Start interactive rebase
---@param base string Base branch/commit to rebase onto
---@param is_commit? boolean Whether base is a commit hash (true) or branch (false)
local function start_rebase(base, is_commit)
  if not base or base == '' then
    utils.notify_error('Invalid base selection')
    return
  end

  local current_branch = get_current_branch()
  if not current_branch then
    utils.notify_error('Failed to get current branch')
    return
  end

  -- Check if there are commits to rebase
  local commits = get_rebase_commits(base, is_commit)
  if not commits or #commits == 0 then
    local base_desc = is_commit and string.format('commit %s', base:sub(1, 7)) or base
    utils.notify_warn(string.format('No commits to rebase onto %s', base_desc))
    return
  end

  -- Confirm before starting rebase
  local base_desc = is_commit and string.format('commit %s', base:sub(1, 7)) or base
  local confirm_msg = string.format('Start interactive rebase onto %s? (%d commit(s))', base_desc, #commits)
  vim.ui.select({ 'Yes', 'No' }, {
    prompt = confirm_msg,
  }, function(choice)
    if choice == 'Yes' then
      -- Start interactive rebase
      vim.cmd('terminal git rebase -i ' .. utils.fnameescape(base))
      utils.notify_success(string.format('Starting interactive rebase onto %s', base_desc))
    end
  end)
end

--- Show commits that would be rebased
---@param base string Base branch/commit
---@param is_commit? boolean Whether base is a commit hash (true) or branch (false)
local function show_rebase_commits(base, is_commit)
  if not base or base == '' then
    utils.notify_error('Invalid base selection')
    return
  end

  local commits = get_rebase_commits(base, is_commit)
  if not commits or #commits == 0 then
    local base_desc = is_commit and string.format('commit %s', base:sub(1, 7)) or base
    utils.notify_warn(string.format('No commits to rebase onto %s', base_desc))
    return
  end

  -- Show commits in a quickfix list or buffer
  local base_desc = is_commit and string.format('commit %s', base:sub(1, 7)) or base
  local lines = {}
  table.insert(lines, string.format('Commits that would be rebased onto %s:', base_desc))
  table.insert(lines, '')
  for i, commit in ipairs(commits) do
    table.insert(lines, string.format('%d. %s %s (%s) - %s', i, commit.hash:sub(1, 7), commit.message, commit.author, commit.date))
  end

  -- Open in a new buffer
  vim.cmd('botright new')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'wipe'
  vim.bo.swapfile = false
  vim.bo.modifiable = false
  vim.bo.filetype = 'git'
  vim.api.nvim_buf_set_name(0, 'Git Rebase Preview')
  vim.api.nvim_buf_set_keymap(0, 'n', 'q', '<cmd>bdelete<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(0, 'n', '<Esc>', '<cmd>bdelete<CR>', { noremap = true, silent = true })
end

-- ============================================================================
-- Picker
-- ============================================================================

--- Create and show the rebase picker
---@param opts? table Optional configuration
function M.picker(opts)
  opts = opts or {}

  -- Validate git repo
  if not utils.ensure_git_repo() then
    return
  end

  local telescope = utils.load_telescope()

  -- Get branches
  local branches = get_rebase_branches()
  
  -- Get commits from current branch (for rebasing onto same branch)
  local current_branch_commits = get_current_branch_commits(opts.commit_count or 50)
  
  -- Combine branches and commits
  local entries = {}
  
  -- Add section header for current branch commits (if any)
  if #current_branch_commits > 0 then
    local current_branch = get_current_branch()
    if current_branch then
      table.insert(entries, {
        value = { name = 'HEADER', is_header = true },
        display = '━━━ Commits on ' .. current_branch .. ' ━━━',
        ordinal = '0_header',
      })
      
      -- Add commits from current branch
      for _, commit in ipairs(current_branch_commits) do
        table.insert(entries, {
          value = commit,
          display = commit.display,
          ordinal = commit.hash,
        })
      end
    end
  end
  
  -- Add section header for branches (if any)
  if #branches > 0 then
    table.insert(entries, {
      value = { name = 'HEADER', is_header = true },
      display = '━━━ Branches ━━━',
      ordinal = '1_header',
    })
    
    -- Add branches
    for _, branch in ipairs(branches) do
      table.insert(entries, {
        value = branch,
        display = branch.display,
        ordinal = branch.name,
      })
    end
  end
  
  if #entries == 0 then
    utils.notify_warn('No branches or commits found')
    return
  end

  -- Create picker
  telescope.pickers.new({}, {
    prompt_title = opts.prompt_title or 'Git Rebase',
    finder = telescope.finders.new_table {
      results = entries,
      entry_maker = function(entry)
        -- Handle headers
        if entry.value and entry.value.is_header then
          return {
            value = entry.value,
            display = entry.display,
            ordinal = entry.ordinal,
            -- Make headers non-selectable by making them invalid entries
            valid = false,
          }
        end
        -- Use default entry maker for regular entries
        return utils.create_entry_maker()(entry)
      end,
    },
    sorter = telescope.conf.generic_sorter {},
    previewer = telescope.previewers.new_termopen_previewer {
      get_command = function(entry)
        if not entry or not entry.value then
          return { 'echo', 'Invalid entry' }
        end
        
        -- Skip headers
        if entry.value.is_header then
          return { 'echo', '' }
        end
        
        local base = entry.value.name
        local is_commit = entry.value.is_commit or false
        local current_branch = get_current_branch()
        
        if is_commit then
          -- For commits, show commits after this commit
          local cmd = string.format('git log --oneline --pretty=format:"%%h %%s (%%an, %%ad)" --date=short %s^..HEAD', base)
          return { 'sh', '-c', cmd .. ' || echo "No commits to rebase"' }
        else
          -- For branches, don't show preview if rebasing onto current branch
          if base == current_branch then
            return { 'echo', string.format('Cannot rebase %s onto itself', current_branch) }
          end
          
          -- Use git log to show commits that would be rebased
          local cmd = string.format('git log --oneline --pretty=format:"%%h %%s (%%an, %%ad)" --date=short %s..%s', base, current_branch or 'HEAD')
          return { 'sh', '-c', cmd .. ' || echo "No commits to rebase"' }
        end
      end,
    },
    layout_config = {
      preview_width = opts.preview_width or 0.5,
    },
    debounce = opts.debounce or 50,
    attach_mappings = function(prompt_bufnr, map)
      local actions = telescope.actions
      local action_state = telescope.action_state

      -- Default action: Start interactive rebase
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection and selection.value and not selection.value.is_header then
          actions.close(prompt_bufnr)
          vim.schedule(function()
            local is_commit = selection.value.is_commit or false
            start_rebase(selection.value.name, is_commit)
          end)
        end
      end)

      -- Normal mode: 'r' to start rebase
      local function start_rebase_action()
        local selection = action_state.get_selected_entry()
        if selection and selection.value and not selection.value.is_header then
          actions.close(prompt_bufnr)
          vim.schedule(function()
            local is_commit = selection.value.is_commit or false
            start_rebase(selection.value.name, is_commit)
          end)
        end
      end
      map('n', 'r', start_rebase_action)

      -- Normal mode: 'p' to preview commits
      local function preview_commits_action()
        local selection = action_state.get_selected_entry()
        if selection and selection.value and not selection.value.is_header then
          actions.close(prompt_bufnr)
          vim.schedule(function()
            local is_commit = selection.value.is_commit or false
            show_rebase_commits(selection.value.name, is_commit)
          end)
        end
      end
      map('n', 'p', preview_commits_action)

      -- Normal mode: 's' to show commit details
      local function show_commit_details_action()
        local selection = action_state.get_selected_entry()
        if selection and selection.value and not selection.value.is_header then
          local base = selection.value.name
          local is_commit = selection.value.is_commit or false
          local commits = get_rebase_commits(base, is_commit)
          if commits and #commits > 0 then
            -- Show first commit details
            local ok = pcall(vim.cmd, 'Git show ' .. commits[1].hash)
            if not ok then
              vim.cmd('terminal git show --color=always ' .. commits[1].hash)
            end
          end
        end
      end
      map('n', 's', show_commit_details_action)

      return true
    end,
  }):find()
end

return M

