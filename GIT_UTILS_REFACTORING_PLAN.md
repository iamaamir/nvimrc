# Git Utils Refactoring Plan

## Current State Analysis

### What We Have:
1. **Custom implementations** for all git operations
2. **Telescope pickers** for: commits, stashes, branches, status, file history, remotes
3. **Multi-selection support** with staging/unstaging
4. **Custom fixup picker**

### What Telescope Built-ins Offer:

#### ✅ `telescope.builtin.git_status`
- **Auto-refresh** after staging/unstaging (exactly what we need!)
- Built-in `git_staging_toggle` action
- Tab key for staging/unstaging
- Preview with file diffs
- Better integration with Telescope ecosystem

#### ✅ `telescope.builtin.git_commits`
- Multiple preview modes (diff to parent, diff to head, diff as was, commit message)
- Built-in actions: checkout, reset (mixed/soft/hard)
- Better commit parsing and display

#### ✅ `telescope.builtin.git_branches`
- Rich branch display (author, upstream, date)
- Built-in actions: checkout, track, rebase, create, switch, delete, merge
- Better branch information

#### ✅ `telescope.builtin.git_stash`
- Built-in apply action
- Better stash parsing

#### ✅ `telescope.builtin.git_bcommits`
- File-specific commit history
- Built-in diff views (vertical, horizontal, tab)
- Better than our custom file_history_picker

## Refactoring Strategy

### Phase 1: Replace with Telescope Built-ins (Immediate Win)

**Replace:**
- `git_utils.commit_picker` → `telescope.builtin.git_commits`
- `git_utils.branch_picker` → `telescope.builtin.git_branches`
- `git_utils.stash_picker` → `telescope.builtin.git_stash`
- `git_utils.file_history_picker` → `telescope.builtin.git_bcommits`
- `git_utils.status_picker` → `telescope.builtin.git_status` (with custom mappings)

**Keep:**
- `git_fixup.fixup_picker` (custom functionality)
- `git_utils.remote_picker` (Telescope doesn't have this)

### Phase 2: Buffer-Based Status View (Like Fugitive)

**Create:** `git_utils.status_buffer` - A buffer-based git status view

**Features:**
- Real-time updates (refresh on file changes)
- Inline staging/unstaging (press `s` on line)
- Visual diff preview
- Better for complex workflows
- Can coexist with Telescope picker

**Implementation:**
- Use `git status --porcelain` to populate buffer
- Key mappings:
  - `s` - Stage/unstage file
  - `u` - Unstage file
  - `X` - Discard changes (with confirmation)
  - `o` - Open file
  - `d` - Show diff
  - `r` - Refresh
  - `q` - Close

### Phase 3: Hybrid Approach

**Best of Both Worlds:**
- **Telescope pickers** for: browsing, searching, quick actions
- **Buffer view** for: detailed status, complex staging workflows
- **Custom utilities** for: fixup commits, remotes, etc.

## Implementation Plan

### Step 1: Update keymaps to use built-ins
```lua
local builtin = require 'telescope.builtin'

-- Use built-in git pickers
map('n', '<leader>gc', builtin.git_commits, { desc = '[G]it [C]ommits' })
map('n', '<leader>gb', builtin.git_branches, { desc = '[G]it [B]ranches' })
map('n', '<leader>gs', builtin.git_stash, { desc = '[G]it [S]tash' })
map('n', '<leader>gh', builtin.git_bcommits, { desc = '[G]it File [H]istory' })
map('n', '<leader>gS', builtin.git_status, { desc = '[G]it [S]tatus' })
```

### Step 2: Create buffer-based status view
- New file: `lua/custom/git-status-buffer.lua`
- Implement buffer creation, updating, and key mappings

### Step 3: Clean up old code
- Remove unused pickers from `git-utils.lua`
- Keep only: `remote_picker` and helper functions

## Benefits

1. **Less code to maintain** - Use battle-tested Telescope built-ins
2. **Better UX** - Auto-refresh in status picker
3. **More features** - Built-in actions we don't have to implement
4. **Flexibility** - Buffer view for complex workflows, picker for quick actions
5. **Consistency** - Follow Telescope patterns and conventions

## Migration Notes

- All existing keymaps will continue to work
- Users get better functionality immediately
- Can gradually migrate to buffer view if preferred
- No breaking changes

