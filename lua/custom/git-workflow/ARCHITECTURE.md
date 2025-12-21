# Git Workflow Plugin - Architecture

## File Structure

```sh
lua/custom/git-workflow/
├── init.lua              # Main plugin entry, config, keymaps
├── utils.lua             # Shared utilities (DRY)
├── README.md             # User documentation
├── ARCHITECTURE.md       # This file
├── EXAMPLE_EXTENSION.lua  # Example of extending
└── pickers/
    ├── _template.lua     # Template for new pickers
    ├── fixup.lua         # Fixup commit picker
    └── remote.lua        # Remote picker
```

## Module Responsibilities

### `init.lua`
- Plugin entry point
- Configuration management
- Keymap setup
- Public API
- Extension registration

### `utils.lua`
- Telescope integration (lazy loading)
- Git repository validation
- Git command execution
- String utilities
- Entry maker creation
- Notification helpers

### `pickers/*.lua`
- Individual picker implementations
- Self-contained modules
- Use shared utilities from `utils.lua`
- Accept `opts` table for configuration

## Data Flow

```
User Keypress
    ↓
init.lua (setup_keymaps)
    ↓
Picker Module (pickers/*.lua)
    ↓
utils.lua (shared functions)
    ↓
Telescope API
    ↓
Git Commands
```

## Extension Pattern

1. **Create picker module** in `pickers/your_picker.lua`
2. **Use utils** for common operations
3. **Register picker** via `register_picker()`
4. **Add keymap** (optional, can be in setup)

## Configuration System

- **Default config** in `init.lua`
- **User config** merged via `setup()`
- **Deep merge** for nested tables
- **Optional** - all keymaps can be disabled

## Best Practices

1. **Always validate git repo** before operations
2. **Use utils functions** instead of direct vim.fn calls
3. **Handle errors gracefully** with notifications
4. **Lazy load** Telescope modules
5. **Accept opts** for configurability
6. **Return early** on validation failures

## Example: Adding a Tag Picker

```lua
-- 1. Create pickers/tag.lua
local utils = require 'custom.git-workflow.utils'

local M = {}

function M.picker(opts)
  opts = opts or {}
  if not utils.ensure_git_repo() then return end
  
  local telescope = utils.load_telescope()
  local output = utils.git_systemlist('git tag --sort=-creatordate')
  -- ... parse and create picker
end

return M

-- 2. Register in your config
local git = require('custom.git-workflow')
git.register_picker('tag', 'custom.git-workflow.pickers.tag', {
  prompt_title = 'Git Tags',
})

-- 3. Use it
vim.keymap.set('n', '<leader>gt', git.tag())
```

