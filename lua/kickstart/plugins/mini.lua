return {
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- require('mini.base16').setup {
      --   palette = {
      --     base00 = '#FFF1EB', --background
      --     base01 = '#FFEBE7', -- sidebar & text under cursor and
      --     base02 = '#FFF9E0', -- selection highlight
      --     base03 = '#553326', -- comments
      --     base04 = '#002D70', -- diagnostic
      --     base05 = '#013614', -- autocomplete box bg
      --     base06 = '#ffffff', -- yet to figure out
      --     base07 = '#591B08',
      --     base08 = '#303030',
      --     base09 = '#303030',
      --     base0A = '#3B3B3B',
      --     base0B = '#112749',
      --     base0C = '#E05320',
      --     base0D = '#0265D2',
      --     base0E = '#049D40',
      --     base0F = '#DE9C00',
      --   },
      --   use_cterm = true,
      -- }
      -- Robust session management with local sessions
      -- Sessions are stored locally in each directory with directory-based naming
      local function get_session_file()
        local cwd = vim.fn.getcwd()
        local dir_name = vim.fn.fnamemodify(cwd, ':t')
        
        -- Use directory name, fallback to 'session' if empty
        dir_name = dir_name ~= '' and dir_name or 'session'
        
        -- Sanitize directory name for filename (remove special chars, keep alphanumeric, dash, underscore, dot)
        dir_name = dir_name:gsub('[^%w%-_%.]', '_')
        
        return string.format('.nvim-session-%s.vim', dir_name)
      end
      
      require('mini.sessions').setup {
        -- Enable autoread and autowrite
        autoread = true,
        autowrite = true,
        
        -- Disable global sessions (only use local)
        directory = '',
        
        -- Use directory-based session file name (evaluated at setup time for current directory)
        -- For dynamic behavior, we'll use autocommands and custom commands
        file = get_session_file(),
        
        -- Force settings for better UX
        force = {
          read = false,   -- Don't force read (check for unsaved buffers)
          write = true,   -- Allow overwriting existing sessions
          delete = false, -- Don't force delete (safety)
        },
        
        -- Hooks for better feedback (post hooks provide sufficient notification)
        hooks = {
          post = {
            read = function(session)
              if session.path then
                vim.notify(string.format('Session loaded: %s', session.path), vim.log.levels.INFO)
              end
            end,
            write = function(session)
              if session.path then
                vim.notify(string.format('Session saved: %s', session.path), vim.log.levels.INFO)
              end
            end,
            delete = function(session)
              if session.path then
                vim.notify(string.format('Session deleted: %s', session.path), vim.log.levels.INFO)
              end
            end,
          },
        },
      }
      
      -- Track directories where we've already notified about missing sessions
      local notified_dirs = {}
      
      -- Update session file name when directory changes
      local sessions_group = vim.api.nvim_create_augroup('MiniSessionsDynamic', { clear = true })
      
      -- Function to update config and check for session
      local function update_session_config()
        local cwd = vim.fn.getcwd()
        local new_file = get_session_file()
        require('mini.sessions').config.file = new_file
        
        -- Update v:this_session to current directory's session for autowrite
        -- This ensures autowrite uses the correct session file when directory changes
        local session_path = cwd .. '/' .. new_file
        if vim.fn.filereadable(session_path) == 1 then
          vim.v.this_session = session_path
        end
        
        -- Subtle notification if no session exists (once per directory)
        if not notified_dirs[cwd] and vim.fn.filereadable(session_path) == 0 then
          -- Only notify if we have buffers open (user is actually working)
          if #vim.api.nvim_list_bufs() > 0 then
            notified_dirs[cwd] = true
            vim.notify(
              'No session found. Session will be auto-saved on quit. Use :SessionWrite to save now.',
              vim.log.levels.INFO,
              { title = 'Session Management' }
            )
          end
        end
      end
      
      -- Update on directory change
      vim.api.nvim_create_autocmd('DirChanged', {
        group = sessions_group,
        callback = update_session_config,
        desc = 'Update session file name when directory changes',
      })
      
      -- Also update on initial load (DirChanged may not fire on startup)
      vim.api.nvim_create_autocmd('VimEnter', {
        group = sessions_group,
        callback = function()
          -- Small delay to ensure cwd is set correctly
          vim.defer_fn(update_session_config, 10)
        end,
        desc = 'Update session config on initial load',
      })
      
      -- Clear notification cache when session is created
      local original_post_write = require('mini.sessions').config.hooks.post.write
      require('mini.sessions').config.hooks.post.write = function(session)
        if original_post_write then original_post_write(session) end
        -- Clear notification for this directory since session now exists
        local cwd = vim.fn.getcwd()
        notified_dirs[cwd] = nil
        -- Update v:this_session to the newly written session
        if session.path then
          vim.v.this_session = session.path
        end
      end
      
      -- Create helper commands for session management with directory-based names
      vim.api.nvim_create_user_command('SessionWrite', function()
        local session_file = get_session_file()
        require('mini.sessions').write(session_file)
      end, { desc = 'Write session with directory-based name' })
      
      vim.api.nvim_create_user_command('SessionRead', function()
        local session_file = get_session_file()
        local session_path = vim.fn.getcwd() .. '/' .. session_file
        if vim.fn.filereadable(session_path) == 1 then
          require('mini.sessions').read(session_file)
        else
          vim.notify(string.format('No session found: %s', session_path), vim.log.levels.WARN)
        end
      end, { desc = 'Read session with directory-based name' })
      
      vim.api.nvim_create_user_command('SessionDelete', function()
        local session_file = get_session_file()
        local session_path = vim.fn.getcwd() .. '/' .. session_file
        
        -- Check if this is the current session
        local is_current = vim.v.this_session == session_path
        
        if is_current then
          -- Ask for confirmation when deleting current session
          local confirm = vim.fn.input('Delete current session? This will close all buffers. (y/N): ')
          if confirm:lower() ~= 'y' then
            vim.notify('Session deletion cancelled', vim.log.levels.INFO)
            return
          end
        end
        
        -- Use force=true to allow deletion of current session
        require('mini.sessions').delete(session_file, { force = true })
      end, { desc = 'Delete session with directory-based name' })
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      -- local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      -- statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      -- statusline.section_location = function()
      --   return '%2l:%-2v'
      -- end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
      --  Mini file explorer

      require('mini.files').setup {
        options = {
          use_as_default_explorer = false,
        },
        mappings = {
          go_in_plus = '<CR>',
        },
      }
      local minifiles_toggle = function()
        if not MiniFiles.close() then
          MiniFiles.open()
        end
      end
      local reveal_current_file = function()
        MiniFiles.open(vim.api.nvim_buf_get_name(0))
      end
      vim.keymap.set('n', '<Leader>e', minifiles_toggle)
      vim.keymap.set('n', '-', reveal_current_file)
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
