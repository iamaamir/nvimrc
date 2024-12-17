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
      -- session management on steriodsa but not so automatic
      require('mini.sessions').setup { autoread = true }
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
