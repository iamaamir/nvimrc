--[[
copy-filepath.nvim - Easy file path copying for Neovim
Author: iamaamir
Created: 2025-03-18
--]]

-- Module definition
local M = {}

-- Default configuration
local config = {
  keymaps = {
    copy_path = '<Leader>cp', -- set to false to disable
  },
  keymap_opts = {
    silent = true,
    noremap = true,
  },
  -- New configuration options
  format_opts = {
    -- Remove trailing slashes
    trailing_slash = false,
    -- Convert backslashes to forward slashes (Windows)
    normalize_slashes = true,
    -- Shorten home directory to ~
    home_tilde = true,
  },
  -- Notification settings
  notify = {
    enable = true,
    duration = 3000,
    level = vim.log.levels.INFO,
  },
}

-- Extended path options
local path_options = {
  {
    label = 'Copy Full Path',
    callback = function()
      return vim.fn.expand '%:p'
    end,
    desc = 'Absolute path of the current file',
  },
  {
    label = 'Copy Relative Path',
    callback = function()
      return vim.fn.expand '%'
    end,
    desc = 'Path relative to current working directory',
  },
  {
    label = 'Copy Filename',
    callback = function()
      return vim.fn.expand '%:t'
    end,
    desc = 'Just the filename',
  },
  {
    label = 'Copy Directory Path',
    callback = function()
      return vim.fn.expand '%:p:h'
    end,
    desc = 'Directory containing the current file',
  },
  {
    label = 'Copy Filename Without Extension',
    callback = function()
      return vim.fn.expand '%:t:r'
    end,
    desc = 'Filename without extension',
  },
}

-- Utility functions
local utils = {
  -- Format path according to config
  format_path = function(path)
    if not path then
      return ''
    end

    local formatted = path

    -- Normalize slashes
    if config.format_opts.normalize_slashes then
      formatted = formatted:gsub('\\', '/')
    end

    -- Remove trailing slash
    if config.format_opts.trailing_slash then
      formatted = formatted:gsub('/$', '')
    end

    -- Replace home directory with tilde
    if config.format_opts.home_tilde then
      local home = vim.loop.os_homedir()
      if home then
        formatted = formatted:gsub('^' .. home, '~')
      end
    end

    return formatted
  end,

  -- Notify user
  notify = function(msg, level)
    if config.notify.enable then
      vim.notify(msg, level or config.notify.level, {
        title = 'Copy Filepath',
        timeout = config.notify.duration,
      })
    end
  end,

  -- Check if system clipboard is available
  has_clipboard = function()
    return vim.fn.has 'clipboard' == 1
  end,
}

-- Function to copy text to system clipboard
local function copy_to_clipboard(text)
  if not utils.has_clipboard() then
    utils.notify('System clipboard not available!', vim.log.levels.ERROR)
    return false
  end

  local formatted_text = utils.format_path(text)
  vim.fn.setreg('+', formatted_text)
  utils.notify('Copied: ' .. formatted_text)
  return true
end

-- Main function to show path options
function M.show_path_options()
  local current_buf = vim.api.nvim_get_current_buf()

  -- Check if buffer has a valid file
  if vim.bo[current_buf].buftype ~= '' then
    utils.notify('Not a valid file buffer!', vim.log.levels.WARN)
    return
  end

  vim.ui.select(path_options, {
    prompt = 'Select path type to copy:',
    format_item = function(item)
      return string.format('%s (%s)', item.label, item.desc)
    end,
  }, function(choice)
    if not choice then
      return
    end

    local path = choice.callback()
    copy_to_clipboard(path)
  end)
end

-- Function to set up keymaps
local function setup_keymaps()
  if config.keymaps.copy_path then
    vim.keymap.set(
      'n',
      config.keymaps.copy_path,
      function()
        M.show_path_options()
      end,
      vim.tbl_extend('force', config.keymap_opts, {
        desc = 'Copy filepath options',
      })
    )
  end
end

-- Function to copy specific path type directly
function M.copy_path(path_type)
  for _, option in ipairs(path_options) do
    if option.label:lower():gsub('%s+', '_') == path_type:lower() then
      local path = option.callback()
      copy_to_clipboard(path)
      return
    end
  end
  utils.notify('Invalid path type: ' .. path_type, vim.log.levels.ERROR)
end

-- Setup function for configuration
function M.setup(opts)
  -- Merge user config with defaults
  if opts then
    config = vim.tbl_deep_extend('force', config, opts)
  end

  -- Create user commands
  vim.api.nvim_create_user_command('CopyFilePath', function()
    M.show_path_options()
  end, {})

  -- Create commands for each path type
  for _, option in ipairs(path_options) do
    local cmd_name = 'CopyFilePath' .. option.label:gsub('%s+', '')
    vim.api.nvim_create_user_command(cmd_name, function()
      local path = option.callback()
      copy_to_clipboard(path)
    end, {})
  end

  -- Set up keymaps
  setup_keymaps()
end

return M
