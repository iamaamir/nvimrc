return {
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('diffview').setup {}

      local function diffview_toggle_files()
        print 'diffview_toggle_files called'
        if vim.bo.filetype == 'DiffviewFiles' then
          vim.cmd 'DiffviewToggleFiles'
        else
          vim.cmd 'DiffviewFocusFiles'
        end
      end

      local function diffview_file_history()
        local file = vim.fn.expand '%:p'
        vim.cmd('DiffviewFileHistory ' .. file)
      end

      local function refresh_diffview()
        if vim.bo.filetype == 'DiffviewFiles' then
          vim.cmd 'DiffviewRefresh'
        end
      end

      local function open_commit_split()
        vim.cmd 'botright Git commit'

        vim.cmd 'resize 20'
      end

      _G.open_commit_split = open_commit_split

      vim.api.nvim_create_user_command('GD', function(opts)
        if opts.args == '' then
          vim.cmd 'DiffviewOpen'

          local map_opts = { noremap = true, silent = true }

          vim.api.nvim_buf_set_keymap(0, 'n', 's', '<Cmd>lua require("diffview.actions").toggle_stage_entry()<CR>', map_opts)
          vim.api.nvim_buf_set_keymap(0, 'n', 'cc', '<Cmd>lua _G.open_commit_split()<CR>', map_opts)
          vim.api.nvim_buf_set_keymap(0, 'n', 'P', '<Cmd>Git push<CR>', map_opts)
          vim.api.nvim_buf_set_keymap(0, 'n', 'F', '<Cmd>Git pull<CR>', map_opts)
          vim.api.nvim_buf_set_keymap(0, 'n', 'q', '<Cmd>DiffviewClose<CR>', map_opts)
          vim.api.nvim_buf_set_keymap(0, 'n', '-', '<Cmd>DiffviewFocusFiles<CR>', map_opts)
        else
          vim.cmd('G ' .. opts.args)
        end
      end, { nargs = '*', complete = 'file' })
    end,
  },
  {
    'tpope/vim-fugitive',
  },
}
