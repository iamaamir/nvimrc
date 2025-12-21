# Git Workflow Plugin

A modular, extensible git workflow plugin for Neovim using Telescope by @iamaamir

## Structure

```
lua/custom/git-workflow/
├── init.lua          # Main plugin entry point, configuration, keymaps
├── utils.lua         # Shared utilities (git commands, validation, status parsing, etc.)
└── pickers/
    ├── remote.lua    # Remote picker (custom)
    ├── fixup.lua     # Fixup commit picker (custom)
    └── status.lua    # Status picker with stage/unstage actions (custom)
```

## Usage

### Basic Setup (Default Keymaps)

```lua
require('custom.git-workflow').setup()
```

### Custom Configuration

```lua
require('custom.git-workflow').setup({
  -- Customize keymaps
  keymaps = {
    fixup = '<leader>gf',
    commits = '<leader>gc',
    branches = '<leader>gb',
    stash = '<leader>gs',
    status = '<leader>gS',
    file_history = '<leader>gh',
    remote = '<leader>gr',
    -- Set to false to disable
    legacy_commits = false,
  },
  
  -- Customize picker options
  pickers = {
    fixup = {
      commit_count = 50,
      preview_width = 0.7,
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
  },
  
  -- Pass options to Telescope built-ins
  builtin_opts = {
    git_commits = {
      -- Telescope git_commits options
    },
    git_branches = {},
    git_stash = {},
    git_bcommits = {},
  },
})
```

### Direct API Access

```lua
local git = require('custom.git-workflow')

-- Use pickers directly
git.fixup()()
git.remote()()
git.commits()()
git.branches()()
git.stash()()
git.status()()
git.file_history()()

-- With custom options
git.fixup({ commit_count = 50 })()
```

## Adding New Pickers

### Step 1: Create Picker Module

Create `lua/custom/git-workflow/pickers/my_picker.lua`:

```lua
local utils = require 'custom.git-workflow.utils'

local M = {}

function M.picker(opts)
  opts = opts or {}
  
  -- Validate git repo
  if not utils.ensure_git_repo() then
    return
  end
  
  local telescope = utils.load_telescope()
  
  -- Example: Using git command with utils
  local output = utils.git_systemlist('git log --oneline -n 10', 'Failed to get commits')
  if not output or #output == 0 then
    utils.notify_warn('No commits found')
    return
  end
  
  -- Parse entries
  local entries = {}
  for _, line in ipairs(output) do
    if not utils.is_empty_line(line) then
      table.insert(entries, {
        value = { hash = line:match('^(%w+)'), message = line:sub(9) },
        display = line,
        ordinal = line,
      })
    end
  end
  
  -- Create picker
  telescope.pickers.new({}, {
    prompt_title = opts.prompt_title or 'My Picker',
    finder = telescope.finders.new_table {
      results = entries,
      entry_maker = utils.create_entry_maker(),
    },
    sorter = telescope.conf.generic_sorter {},
    attach_mappings = function(prompt_bufnr)
      telescope.actions.select_default:replace(function()
        telescope.actions.close(prompt_bufnr)
        local selection = utils.get_selection()
        if selection then
          utils.notify_success('Selected: ' .. selection.value.message)
        end
      end)
      return true
    end,
  }):find()
end

return M
```

### Step 2: Register Picker

In your config or `init.lua`:

```lua
local git = require('custom.git-workflow')

-- Register the picker
git.register_picker('my_picker', 'custom.git-workflow.pickers.my_picker', {
  prompt_title = 'My Picker',
  debounce = 50,
  -- default options
})

-- Setup keymap
vim.keymap.set('n', '<leader>gm', git.my_picker(), { desc = 'My Picker' })
```

### Example: Using Git Status Parsing Utilities

If you need to work with git status, use the built-in parsing utilities:

```lua
local utils = require 'custom.git-workflow.utils'

-- Get git status output
local status_output = utils.git_systemlist('git status --porcelain', 'Failed to get status')
if not status_output then
  return
end

-- Parse into entries (automatically handles icons, status text, etc.)
local entries = utils.parse_git_status_porcelain(status_output)

-- Or parse a single line
local entry = utils.parse_git_status_line(' M file.txt')
-- Returns: { value = { path = 'file.txt', is_unstaged = true, ... }, display = '○ [UNSTAGED (Modified)] file.txt', ... }
```

## Available Pickers

### Built-in (Telescope)
- `commits` - Browse commits with preview, checkout, reset
- `branches` - Browse branches with checkout, delete, merge, etc.
- `stash` - Browse stashes with apply action
- `file_history` - Browse file-specific commits with diff views

### Custom
- `status` - Enhanced git status picker with stage/unstage actions
  - **Visual indicators**: `●` (staged), `○` (unstaged), `●○` (both), `?` (untracked)
  - **Multi-selection**: Press `Tab` to select multiple files
  - **Stage files**: Press `<C-s>` to stage selected files
  - **Unstage files**: Press `<C-u>` to unstage selected files
  - **Open file**: Press `Enter` to open the selected file
  - **Auto-refresh**: Picker updates automatically after actions
  - **Preview**: Shows `git diff` for the selected file
- `fixup` - Create fixup commits
- `remote` - Browse remotes and copy URL to clipboard

## Keymaps (Default)

- `<leader>gf` - Git Fixup
- `<leader>gc` - Git Commits
- `<leader>gb` - Git Branches
- `<leader>gs` - Git Stash
- `<leader>gS` - Git Status
- `<leader>gh` - Git File History
- `<leader>gr` - Git Remote
- `<leader>i` - Git Commits (legacy)
- `<leader>T` - Git Stash (legacy)

## Architecture

- **init.lua**: Plugin entry point, configuration, keymap setup, public API
- **utils.lua**: Shared utilities (DRY principle)
  - Git command execution (`git_system`, `git_systemlist`)
  - Git repository validation (`ensure_git_repo`, `is_git_repo`)
  - Git status parsing (`parse_git_status_line`, `parse_git_status_porcelain`)
  - String utilities (`shellescape`, `fnameescape`, `is_empty_line`)
  - Telescope integration (`load_telescope`, `get_builtin`, `create_entry_maker`)
  - Notifications (`notify_success`, `notify_error`, `notify_warn`)
- **pickers/**: Individual picker modules (separation of concerns)
  - Each picker follows the same pattern: `M.picker(opts)` function
  - Uses shared utilities for consistency
  - Can be registered via `register_picker()` API
- **Extensible**: Easy to add new pickers via `register_picker()` or direct keymap setup

## Available Utilities

The `utils` module provides many reusable functions:

### Git Operations
- `utils.git_system(cmd, error_msg)` - Execute git command, return string output
- `utils.git_systemlist(cmd, error_msg)` - Execute git command, return table of lines
- `utils.ensure_git_repo(error_msg)` - Validate git repository, show error if not
- `utils.is_git_repo()` - Check if current directory is a git repo

### Git Status Parsing
- `utils.parse_git_status_line(line)` - Parse single git status porcelain line
- `utils.parse_git_status_porcelain(output)` - Parse full git status output

### String Utilities
- `utils.shellescape(str)` - Escape string for shell commands
- `utils.fnameescape(str)` - Escape string for vim file commands
- `utils.is_empty_line(line)` - Check if line is empty or whitespace-only

### Telescope Integration
- `utils.load_telescope()` - Lazy load Telescope modules
- `utils.get_builtin()` - Get Telescope built-in pickers
- `utils.create_entry_maker()` - Create standard entry maker function
- `utils.get_selection()` - Get current Telescope selection

### Notifications
- `utils.notify_success(msg)` - Show success notification
- `utils.notify_error(msg)` - Show error notification
- `utils.notify_warn(msg)` - Show warning notification

