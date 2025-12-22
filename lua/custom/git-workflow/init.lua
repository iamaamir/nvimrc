--[[
  Git Workflow Plugin
  A modular, extensible git workflow tool for Neovim
  
  Features:
  - Uses Telescope built-ins where available
  - Custom pickers for missing functionality
  - Easy to extend with new utilities
  - Configurable via setup() function
--]]

local M = {}

-- ============================================================================
-- Configuration
-- ============================================================================

--- Default configuration
local default_config = {
  -- Enable/disable notifications
  notifications = {
    enabled = true,
    level = vim.log.levels.INFO, -- INFO, WARN, ERROR
  },
  
  -- Global picker settings
  picker_defaults = {
    debounce = 50, -- Prevent UI blocking (especially in Wezterm)
    preview_width = 0.65, -- Default preview width (0.0 to 1.0)
  },
  
  -- Key mappings (set to false to disable)
  keymaps = {
    fixup = '<leader>gf',
    commits = '<leader>gc',
    branches = '<leader>gb',
    stash = '<leader>gS',
    status = '<leader>gs',
    file_history = '<leader>gh',
    remote = '<leader>gr',
    gitmoji = '<leader>gm',
    log = '<leader>gl',
    rebase = '<leader>gR',
    -- Legacy keymaps
    legacy_commits = '<leader>i',
    legacy_stash = '<leader>T',
  },
  
  -- Picker options
  pickers = {
    fixup = {
      commit_count = 30,
      preview_width = 0.65,
      prompt_title = 'Select commit to fixup',
    },
    remote = {
      prompt_title = 'Git Remotes',
      results_title = 'Remotes',
      debounce = 50,
    },
    status = {
      prompt_title = 'Git Status',
      debounce = 50,
      preview_width = 0.65,
    },
    gitmoji = {
      prompt_title = 'Gitmoji',
      debounce = 50,
      preview_width = 0.65,
      -- Custom gitmojis to extend the default list (appear at the top)
      -- Example:
      -- custom_gitmojis = {
      --   { emoji = "🔧", code = ":eslintfix:", description = "Run ESLint fix", name = "eslintfix" },
      --   { emoji = "🧹", code = ":chore:", description = "Chore tasks", name = "chore" },
      -- }
      custom_gitmojis = {},
    },
    log = {
      prompt_title = 'Git Log',
      debounce = 50,
      preview_width = 0.50,
      commit_count = 1000,
      -- Filter options (can be set when calling picker)
      -- author: string - Filter by author name/email
      -- since: string - Filter by date (e.g., "2024-01-01", "2 weeks ago")
      -- until_date: string - Filter until date
      -- file_path: string - Filter by file path
      -- grep: string - Search commit messages
    },
    rebase = {
      prompt_title = 'Git Rebase',
      debounce = 50,
      preview_width = 0.5,
      commit_count = 50, -- Number of commits from current branch to show
    },
  },
  
  -- Telescope built-in options (passed directly to builtins)
  builtin_opts = {
    git_commits = {},
    git_branches = {},
    git_stash = {},
    git_status = {},
    git_bcommits = {},
  },
}

-- Current configuration (merged with defaults)
local config = vim.deepcopy(default_config)

-- ============================================================================
-- Setup Function
-- ============================================================================

--- Validate configuration values
---@param user_config table Configuration to validate
---@return boolean, string|nil True if valid, error message if invalid
local function validate_config(user_config)
  -- Validate picker_defaults
  if user_config.picker_defaults then
    local defaults = user_config.picker_defaults
    if defaults.debounce and (type(defaults.debounce) ~= 'number' or defaults.debounce < 0) then
      return false, 'picker_defaults.debounce must be a non-negative number'
    end
    if defaults.preview_width and (type(defaults.preview_width) ~= 'number' or defaults.preview_width < 0 or defaults.preview_width > 1) then
      return false, 'picker_defaults.preview_width must be a number between 0 and 1'
    end
  end
  
  -- Validate notifications
  if user_config.notifications then
    local notif = user_config.notifications
    if notif.enabled ~= nil and type(notif.enabled) ~= 'boolean' then
      return false, 'notifications.enabled must be a boolean'
    end
    if notif.level and not vim.tbl_contains({ vim.log.levels.TRACE, vim.log.levels.DEBUG, vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR }, notif.level) then
      return false, 'notifications.level must be a valid vim.log.levels value'
    end
  end
  
  -- Validate picker options
  if user_config.pickers then
    for picker_name, picker_opts in pairs(user_config.pickers) do
      if type(picker_opts) ~= 'table' then
        return false, string.format('pickers.%s must be a table', picker_name)
      end
      if picker_opts.debounce and (type(picker_opts.debounce) ~= 'number' or picker_opts.debounce < 0) then
        return false, string.format('pickers.%s.debounce must be a non-negative number', picker_name)
      end
      if picker_opts.preview_width and (type(picker_opts.preview_width) ~= 'number' or picker_opts.preview_width < 0 or picker_opts.preview_width > 1) then
        return false, string.format('pickers.%s.preview_width must be a number between 0 and 1', picker_name)
      end
      -- Validate gitmoji custom_gitmojis
      if picker_name == 'gitmoji' and picker_opts.custom_gitmojis then
        if type(picker_opts.custom_gitmojis) ~= 'table' then
          return false, 'pickers.gitmoji.custom_gitmojis must be a table'
        end
        for i, custom in ipairs(picker_opts.custom_gitmojis) do
          if type(custom) ~= 'table' then
            return false, string.format('pickers.gitmoji.custom_gitmojis[%d] must be a table', i)
          end
          if not custom.emoji or not custom.code then
            return false, string.format('pickers.gitmoji.custom_gitmojis[%d] must have emoji and code fields', i)
          end
        end
      end
    end
  end
  
  return true, nil
end

--- Setup the plugin with custom configuration
---@param user_config? table User configuration to merge with defaults
---   - notifications: table - Notification settings { enabled = bool, level = vim.log.levels.* }
---   - picker_defaults: table - Default picker settings { debounce = number, preview_width = number }
---   - keymaps: table - Key mappings (set to false to disable)
---   - pickers: table - Picker-specific options
---   - builtin_opts: table - Options for Telescope built-ins
function M.setup(user_config)
  user_config = user_config or {}
  
  -- Validate configuration
  local is_valid, error_msg = validate_config(user_config)
  if not is_valid then
    vim.notify('Git Workflow: Invalid configuration: ' .. (error_msg or 'unknown error'), vim.log.levels.ERROR)
    -- Use defaults on validation error
    config = vim.deepcopy(default_config)
  else
    -- Deep merge user config with defaults
    -- Use 'force' to override defaults with user values
    config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), user_config)
  end
  
  -- Merge picker_defaults into individual picker configs if not explicitly set
  for picker_name, picker_opts in pairs(config.pickers) do
    if not picker_opts.debounce then
      picker_opts.debounce = config.picker_defaults.debounce
    end
    if not picker_opts.preview_width then
      picker_opts.preview_width = config.picker_defaults.preview_width
    end
  end
  
  -- Expose config for utils module (for notification settings)
  M._config = config
  
  -- Setup keymaps if enabled
  if config.keymaps then
    local ok, err = pcall(M.setup_keymaps)
    if not ok then
      vim.notify('Git Workflow: Failed to setup keymaps: ' .. tostring(err), vim.log.levels.ERROR)
    end
  end
end

-- ============================================================================
-- Keymap Setup
-- ============================================================================

--- Setup all keymaps based on configuration
function M.setup_keymaps()
  local map = vim.keymap.set
  local keymaps = config.keymaps
  local utils = require 'custom.git-workflow.utils'
  
  -- Git Fixup (custom)
  if keymaps.fixup then
    map('n', keymaps.fixup, function()
      require('custom.git-workflow.pickers.fixup').picker(config.pickers.fixup)
    end, { desc = '[G]it [F]ixup commit', noremap = true, silent = true })
  end
  
  -- Git Commits (Telescope built-in)
  if keymaps.commits then
    map('n', keymaps.commits, function()
      utils.get_builtin().git_commits(config.builtin_opts.git_commits)
    end, { desc = '[G]it [C]ommits', noremap = true, silent = true })
  end
  
  -- Git Branches (Telescope built-in)
  if keymaps.branches then
    map('n', keymaps.branches, function()
      utils.get_builtin().git_branches(config.builtin_opts.git_branches)
    end, { desc = '[G]it [B]ranch', noremap = true, silent = true })
  end
  
  -- Git Stash (Telescope built-in)
  if keymaps.stash then
    map('n', keymaps.stash, function()
      utils.get_builtin().git_stash(config.builtin_opts.git_stash)
    end, { desc = '[G]it [S]tash', noremap = true, silent = true })
  end
  
  -- Git Status (Telescope with stage/unstage actions)
  if keymaps.status then
    map('n', keymaps.status, function()
      require('custom.git-workflow.pickers.status').picker(config.pickers.status)
    end, { desc = '[G]it [S]tatus', noremap = true, silent = true })
  end
  
  -- Git File History (Telescope built-in)
  if keymaps.file_history then
    map('n', keymaps.file_history, function()
      utils.get_builtin().git_bcommits(config.builtin_opts.git_bcommits)
    end, { desc = '[G]it File [H]istory', noremap = true, silent = true })
  end
  
  -- Git Remote (custom)
  if keymaps.remote then
    map('n', keymaps.remote, function()
      require('custom.git-workflow.pickers.remote').picker(config.pickers.remote)
    end, { desc = '[G]it [R]emote', noremap = true, silent = true })
  end
  
  -- Gitmoji (custom) - supports both insert and normal mode
  if keymaps.gitmoji then
    -- Normal mode
    map('n', keymaps.gitmoji, function()
      require('custom.git-workflow.pickers.gitmoji').picker(config.pickers.gitmoji)
    end, { desc = 'Gitmoji', noremap = true, silent = true })
    -- Insert mode
    map('i', keymaps.gitmoji, function()
      require('custom.git-workflow.pickers.gitmoji').picker(config.pickers.gitmoji)
    end, { desc = 'Gitmoji', noremap = true, silent = true })
  end

  -- Git Log (custom with filters)
  if keymaps.log then
    map('n', keymaps.log, function()
      require('custom.git-workflow.pickers.log').picker(config.pickers.log)
    end, { desc = '[G]it [L]og', noremap = true, silent = true })
  end

  -- Git Rebase (custom)
  if keymaps.rebase then
    map('n', keymaps.rebase, function()
      require('custom.git-workflow.pickers.rebase').picker(config.pickers.rebase)
    end, { desc = '[G]it [R]ebase', noremap = true, silent = true })
  end
  
  -- Legacy keymaps
  if keymaps.legacy_commits then
    map('n', keymaps.legacy_commits, function()
      utils.get_builtin().git_commits(config.builtin_opts.git_commits)
    end, { desc = 'List commits and compare (legacy)', noremap = true, silent = true })
  end
  
  if keymaps.legacy_stash then
    map('n', keymaps.legacy_stash, function()
      utils.get_builtin().git_stash(config.builtin_opts.git_stash)
    end, { desc = 'Git stash (legacy)', noremap = true, silent = true })
  end
end

-- ============================================================================
-- Public API - Direct Picker Access
-- ============================================================================

--- Get fixup picker function
---@param opts? table Optional picker options
---@return function Picker function
function M.fixup(opts)
  return function()
    require('custom.git-workflow.pickers.fixup').picker(opts or config.pickers.fixup)
  end
end

--- Get remote picker function
---@param opts? table Optional picker options
---@return function Picker function
function M.remote(opts)
  return function()
    require('custom.git-workflow.pickers.remote').picker(opts or config.pickers.remote)
  end
end

--- Get commits picker (Telescope built-in)
---@param opts? table Optional picker options
---@return function Picker function
function M.commits(opts)
  return function()
    require('custom.git-workflow.utils').get_builtin().git_commits(opts or config.builtin_opts.git_commits)
  end
end

--- Get branches picker (Telescope built-in)
---@param opts? table Optional picker options
---@return function Picker function
function M.branches(opts)
  return function()
    require('custom.git-workflow.utils').get_builtin().git_branches(opts or config.builtin_opts.git_branches)
  end
end

--- Get stash picker (Telescope built-in)
---@param opts? table Optional picker options
---@return function Picker function
function M.stash(opts)
  return function()
    require('custom.git-workflow.utils').get_builtin().git_stash(opts or config.builtin_opts.git_stash)
  end
end

--- Get status picker (custom with actions)
---@param opts? table Optional picker options
---@return function Picker function
function M.status(opts)
  return function()
    require('custom.git-workflow.pickers.status').picker(opts or config.pickers.status)
  end
end

--- Get file history picker (Telescope built-in)
---@param opts? table Optional picker options
---@return function Picker function
function M.file_history(opts)
  return function()
    require('custom.git-workflow.utils').get_builtin().git_bcommits(opts or config.builtin_opts.git_bcommits)
  end
end

--- Get gitmoji picker (custom)
---@param opts? table Optional picker options
---@return function Picker function
function M.gitmoji(opts)
  return function()
    require('custom.git-workflow.pickers.gitmoji').picker(opts or config.pickers.gitmoji)
  end
end

--- Get log picker (custom with filters)
---@param opts? table Optional picker options
---@return function Picker function
function M.log(opts)
  return function()
    require('custom.git-workflow.pickers.log').picker(opts or config.pickers.log)
  end
end

--- Get rebase picker (custom)
---@param opts? table Optional picker options
---@return function Picker function
function M.rebase(opts)
  return function()
    require('custom.git-workflow.pickers.rebase').picker(opts or config.pickers.rebase)
  end
end

-- ============================================================================
-- Extension API - Easy way to add new pickers
-- ============================================================================

--- Register a new custom picker
---@param name string Picker name (used as key in config)
---@param picker_module string Module path (e.g., 'custom.git-workflow.pickers.my_picker')
---@param default_opts? table Default options for this picker
function M.register_picker(name, picker_module, default_opts)
  default_opts = default_opts or {}
  
  -- Add to config
  if not config.pickers[name] then
    config.pickers[name] = default_opts
  end
  
  -- Create public API function
  M[name] = function(opts)
    return function()
      require(picker_module).picker(opts or config.pickers[name])
    end
  end
end


return M

