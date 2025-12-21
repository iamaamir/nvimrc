-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  require('custom.command-runner').setup(),
  require('custom.copy-filepath').setup(),
  -- Git Workflow Plugin - Configure with options
  require('custom.git-workflow').setup({
    -- Example: Customize default picker settings (ACTIVE - for testing)
    picker_defaults = {
      debounce = 50, -- Prevent UI blocking
      preview_width = 0.75, -- Wider preview pane (default is 0.65)
    },
    
    -- Example: Customize specific picker options (ACTIVE - for testing)
    pickers = {
      fixup = {
        commit_count = 10, -- Show more commits (default is 30)
        preview_width = 0.6, -- Override default for this picker
      },
      status = {
        preview_width = 0.5, -- 50-50 split for status picker
      },
      gitmoji = {
        -- Add custom gitmojis (appear at the top of the list)
        custom_gitmojis = {
          { emoji = "🔧", code = ":eslintfix:", description = "Run ESLint fix", name = "eslintfix" },
          { emoji = "🧹", code = ":chore:", description = "Chore tasks", name = "chore" },
        },
      },
    },
    
    -- Example: Disable notifications (set to false)
    -- notifications = { enabled = false },
    
    -- Example: Disable specific keymaps
    -- keymaps = {
    --   legacy_commits = false, -- Disable legacy keymap
    -- },
  }),
}
