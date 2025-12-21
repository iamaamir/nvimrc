--[[
  Git Status Picker with Actions
  Enhanced version of telescope.builtin.git_status with custom stage/unstage actions
--]]

local utils = require 'custom.git-workflow.utils'

local M = {}

-- ============================================================================
-- Git Actions
-- ============================================================================

--- Validate file path for git operations
---@param filepath string File path to validate
---@return boolean True if valid
local function validate_filepath(filepath)
  if not filepath or type(filepath) ~= 'string' or filepath == '' then
    return false
  end
  
  -- Check for dangerous patterns
  if filepath:match('%.%.') or filepath:match('^/') or filepath:match(';') or filepath:match('&&') then
    return false
  end
  
  return true
end

--- Stage a file
---@param filepath string File path to stage
---@return boolean Success
local function stage_file(filepath)
  if not validate_filepath(filepath) then
    utils.notify_error('Invalid file path: ' .. tostring(filepath))
    return false
  end

  local escaped_path = utils.shellescape(filepath)
  local result = utils.git_system('git add ' .. escaped_path)
  if result then
    utils.notify_success('Staged: ' .. filepath)
    return true
  else
    utils.notify_error('Failed to stage: ' .. filepath)
    return false
  end
end

--- Unstage a file
---@param filepath string File path to unstage
---@return boolean Success
local function unstage_file(filepath)
  if not validate_filepath(filepath) then
    utils.notify_error('Invalid file path: ' .. tostring(filepath))
    return false
  end

  local escaped_path = utils.shellescape(filepath)
  local result = utils.git_system('git reset HEAD -- ' .. escaped_path)
  if result then
    utils.notify_success('Unstaged: ' .. filepath)
    return true
  else
    utils.notify_error('Failed to unstage: ' .. filepath)
    return false
  end
end

--- Stage all files
---@return boolean Success
local function stage_all()
  local result = utils.git_system 'git add -A'
  if result then
    utils.notify_success 'Staged all files'
    return true
  else
    utils.notify_error 'Failed to stage all files'
    return false
  end
end

--- Unstage all files
---@return boolean Success
local function unstage_all()
  local result = utils.git_system 'git reset HEAD --'
  if result then
    utils.notify_success 'Unstaged all files'
    return true
  else
    utils.notify_error 'Failed to unstage all files'
    return false
  end
end

--- Get file path from entry
---@param entry table Telescope entry
---@return string|nil File path
local function get_filepath(entry)
  if not entry then
    return nil
  end

  -- Format 1: entry.value.path (our custom format)
  if entry.value and type(entry.value) == 'table' and entry.value.path then
    return entry.value.path
  end

  -- Format 2: entry.value is the path string
  if entry.value and type(entry.value) == 'string' then
    return entry.value
  end

  -- Format 3: entry.path directly
  if entry.path then
    return entry.path
  end

  return nil
end

--- Get entry status info
---@param entry table Telescope entry
---@return table|nil Status info {is_staged, is_unstaged, status_text}
local function get_status_info(entry)
  if not entry or not entry.value or type(entry.value) ~= 'table' then
    return nil
  end

  return {
    is_staged = entry.value.is_staged or false,
    is_unstaged = entry.value.is_unstaged or false,
    status_text = entry.value.status_text or '',
  }
end

--- Get all selected file paths (single or multi-select)
---@param prompt_bufnr number Prompt buffer number
---@return table Array of file paths
local function get_selected_filepaths(prompt_bufnr)
  local action_state = require 'telescope.actions.state'
  local action_utils = require 'telescope.actions.utils'
  local filepaths = {}

  -- Get current picker
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  if not current_picker then
    return filepaths
  end

  -- Try to get multi-selections first
  local multi_selections = current_picker:get_multi_selection()
  if multi_selections and #multi_selections > 0 then
    for _, entry in ipairs(multi_selections) do
      local filepath = get_filepath(entry)
      if filepath then
        table.insert(filepaths, filepath)
      end
    end
  end

  -- If no multi-selections, use current selection
  if #filepaths == 0 then
    local selection = action_state.get_selected_entry()
    if selection then
      local filepath = get_filepath(selection)
      if filepath then
        table.insert(filepaths, filepath)
      end
    end
  end

  return filepaths
end

-- ============================================================================
-- Picker
-- ============================================================================

--- Create and show git status picker with custom actions
---@param opts? table Optional configuration
function M.picker(opts)
  opts = opts or {}

  -- Validate git repo
  if not utils.ensure_git_repo() then
    return
  end

  local telescope = utils.load_telescope()

  -- Get git status with porcelain format for better parsing
  local status_output = utils.git_systemlist('git status --porcelain', 'Failed to get git status. Make sure you are in a git repository.')
  if not status_output then
    return
  end
  
  if #status_output == 0 then
    utils.notify_warn('No changes found. Working tree is clean.')
    return
  end

  -- Parse git status entries with clear staged/unstaged indicators
  local entries = utils.parse_git_status_porcelain(status_output)

  if #entries == 0 then
    utils.notify_warn('No valid changes found. All files may be ignored or invalid.')
    return
  end

  -- Create custom picker with enhanced display
  local picker_instance = telescope.pickers.new({}, {
    prompt_title = opts.prompt_title or 'Git Status',
    finder = telescope.finders.new_table {
      results = entries,
      entry_maker = utils.create_entry_maker(),
    },
    sorter = telescope.conf.generic_sorter {},
    previewer = telescope.previewers.new_termopen_previewer {
      get_command = function(entry)
        local filepath = get_filepath(entry)
        if filepath then
          return { 'git', '--no-pager', 'diff', '--color=always', filepath }
        end
        return { 'echo', 'No file selected' }
      end,
    },
    debounce = opts.debounce or 50,
    layout_config = opts.preview_width and {
      preview_width = opts.preview_width,
    } or nil,

    attach_mappings = function(prompt_bufnr, map)
      local actions = telescope.actions
      local action_state = telescope.action_state

      -- Function to refresh picker with updated git status
      local function refresh_picker()
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        if not current_picker then
          return
        end

        local new_status = utils.git_systemlist('git status --porcelain', 'Failed to get git status')
        if not new_status then
          return
        end

        local new_entries = utils.parse_git_status_porcelain(new_status)

        local new_finder = telescope.finders.new_table {
          results = new_entries,
          entry_maker = utils.create_entry_maker(),
        }
        current_picker:refresh(new_finder, { reset_prompt = true })
      end

      -- Helper to show current selection info
      local function show_selection_info()
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        if not current_picker then
          return
        end

        local selection = action_state.get_selected_entry()
        local multi_selections = current_picker:get_multi_selection()
        local multi_count = multi_selections and #multi_selections or 0

        if selection then
          local filepath = get_filepath(selection)
          local status_info = get_status_info(selection)
          if filepath then
            local status_desc = status_info and status_info.status_text or 'Unknown'
            local info = '▶ ' .. filepath .. ' [' .. status_desc .. ']'
            if multi_count > 0 then
              info = info .. ' | ' .. multi_count .. ' file(s) selected'
            end
            -- Show in echo area (non-intrusive)
            vim.api.nvim_echo({ { info, 'Comment' } }, false, {})
          end
        end
      end

      -- Show info when toggling selection
      local function toggle_selection_action()
        actions.toggle_selection(prompt_bufnr)
        vim.schedule(show_selection_info)
      end
      map('i', '<Tab>', toggle_selection_action)

      -- Normal mode: Stage selected file (s = stage)
      local function stage_selected_action()
        local filepaths = get_selected_filepaths(prompt_bufnr)
        if #filepaths == 0 then
          utils.notify_warn 'No files selected'
          return
        end

        local success_count = 0
        for _, filepath in ipairs(filepaths) do
          if stage_file(filepath) then
            success_count = success_count + 1
          end
        end

        if success_count > 0 then
          if #filepaths > 1 then
            utils.notify_success('Staged ' .. success_count .. ' file(s)')
          end
          -- Refresh picker to show updated status
          vim.schedule(function()
            refresh_picker()
            show_selection_info()
          end)
        end
      end
      map('n', 's', stage_selected_action)

      -- Normal mode: Unstage selected file (u = unstage)
      local function unstage_selected_action()
        local filepaths = get_selected_filepaths(prompt_bufnr)
        if #filepaths == 0 then
          utils.notify_warn 'No files selected'
          return
        end

        local success_count = 0
        for _, filepath in ipairs(filepaths) do
          if unstage_file(filepath) then
            success_count = success_count + 1
          end
        end

        if success_count > 0 then
          if #filepaths > 1 then
            utils.notify_success('Unstaged ' .. success_count .. ' file(s)')
          end
          -- Refresh picker to show updated status
          vim.schedule(function()
            refresh_picker()
            show_selection_info()
          end)
        end
      end
      map('n', 'u', unstage_selected_action)

      -- Normal mode: Stage all files (a = add all)
      local function stage_all_action()
        if stage_all() then
          -- Refresh picker to show updated status
          vim.schedule(function()
            refresh_picker()
            show_selection_info()
          end)
        end
      end
      map('n', 'a', stage_all_action)

      -- Normal mode: Unstage all files (x = remove all)
      local function unstage_all_action()
        if unstage_all() then
          -- Refresh picker to show updated status
          vim.schedule(function()
            refresh_picker()
            show_selection_info()
          end)
        end
      end
      map('n', 'x', unstage_all_action)

      -- Normal mode: Commit changes (c = commit)
      local function commit_changes_action()
        -- Close the picker first
        actions.close(prompt_bufnr)
        -- Use Fugitive's Git commit command
        vim.cmd 'Git commit'
      end
      map('n', 'c', commit_changes_action)

      -- Default action: Open file
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection then
          local filepath = get_filepath(selection)
          if filepath then
            actions.close(prompt_bufnr)
            vim.cmd('edit ' .. utils.fnameescape(filepath))
          end
        end
      end)

      -- Stage files: <C-s> (supports single and multi-select)
      map('i', '<C-s>', stage_selected_action)
      
      -- Unstage files: <C-u> (supports single and multi-select)
      map('i', '<C-u>', unstage_selected_action)
      
      -- Stage all files: <C-a> (regardless of selection, a = add all)
      map('i', '<C-a>', stage_all_action)
      
      -- Unstage all files: <C-x> (regardless of selection, x = remove all)
      map('i', '<C-x>', unstage_all_action)
      
      -- Commit changes: <C-c> (opens Fugitive commit interface)
      map('i', '<C-c>', commit_changes_action)

      -- Show initial selection info
      map('i', '<C-s>', function()
        local filepaths = get_selected_filepaths(prompt_bufnr)
        if #filepaths == 0 then
          utils.notify_warn 'No files selected. Use Tab to select files for multi-select.'
          return
        end

        local success_count = 0
        for _, filepath in ipairs(filepaths) do
          if stage_file(filepath) then
            success_count = success_count + 1
          end
        end

        if success_count > 0 then
          if #filepaths > 1 then
            utils.notify_success('Staged ' .. success_count .. ' file(s)')
          end
          -- Refresh picker to show updated status
          vim.schedule(function()
            refresh_picker()
            show_selection_info()
          end)
        end
      end, { desc = 'Stage selected file(s)' })

      -- Unstage files: <C-u> (supports single and multi-select)
      map('i', '<C-u>', function()
        local filepaths = get_selected_filepaths(prompt_bufnr)
        if #filepaths == 0 then
          utils.notify_warn 'No files selected. Use Tab to select files for multi-select.'
          return
        end

        local success_count = 0
        for _, filepath in ipairs(filepaths) do
          if unstage_file(filepath) then
            success_count = success_count + 1
          end
        end

        if success_count > 0 then
          if #filepaths > 1 then
            utils.notify_success('Unstaged ' .. success_count .. ' file(s)')
          end
          -- Refresh picker to show updated status
          vim.schedule(function()
            refresh_picker()
            show_selection_info()
          end)
        end
      end, { desc = 'Unstage selected file(s)' })

      -- Stage all files: <C-a> (regardless of selection, a = add all)
      map('i', '<C-a>', function()
        if stage_all() then
          -- Refresh picker to show updated status
          vim.schedule(function()
            refresh_picker()
            show_selection_info()
          end)
        end
      end, { desc = 'Stage all files' })

      -- Unstage all files: <C-x> (regardless of selection, x = remove all)
      map('i', '<C-x>', function()
        if unstage_all() then
          -- Refresh picker to show updated status
          vim.schedule(function()
            refresh_picker()
            show_selection_info()
          end)
        end
      end, { desc = 'Unstage all files' })

      -- Commit changes: <C-c> (opens Fugitive commit interface)
      map('i', '<C-c>', function()
        -- Close the picker first
        actions.close(prompt_bufnr)
        -- Use Fugitive's Git commit command
        vim.cmd 'Git commit'
      end, { desc = 'Commit changes' })

      -- Show initial selection info
      vim.schedule(show_selection_info)

      -- Keybindings:
      -- Insert Mode:
      --   - Tab: Toggle selection on current file (multi-selection)
      --   - Enter: Open selected file
      --   - <C-s>: Stage selected file(s) (single or multi-select)
      --   - <C-u>: Unstage selected file(s) (single or multi-select)
      --   - <C-a>: Stage all files (regardless of selection)
      --   - <C-x>: Unstage all files (regardless of selection)
      --   - <C-c>: Commit changes (opens Fugitive commit interface)
      -- Normal Mode:
      --   - s: Stage selected file(s) (single or multi-select)
      --   - u: Unstage selected file(s) (single or multi-select)
      --   - a: Stage all files (regardless of selection)
      --   - x: Unstage all files (regardless of selection)
      --   - c: Commit changes (opens Fugitive commit interface)
      -- Status codes: M=Modified, A=Added, D=Deleted, ??=Untracked, R=Renamed

      return true
    end,
  })

  picker_instance:find()
end

return M
