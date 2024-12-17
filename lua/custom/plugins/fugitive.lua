return {
  {
    'sindrets/diffview.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('diffview').setup {}

      function Diffview_summary()
        local summary = vim.fn.system 'git diff --stat'
        vim.cmd 'botright new' -- Open a new split
        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(summary, '\n'))
        vim.bo.buftype = 'nofile'
        vim.bo.bufhidden = 'wipe'
        vim.bo.swapfile = false
        vim.bo.modifiable = false
        vim.bo.filetype = 'gitcommit'
        vim.api.nvim_buf_set_name(0, 'Git Summary')
        vim.api.nvim_buf_set_keymap(0, 'n', 'q', '<cmd>bdelete<CR>', { noremap = true, silent = true })
      end

      function Diffview_resolve_conflict(choice)
        local current_file = vim.fn.expand '%:p'
        if choice == 'ours' then
          vim.cmd 'Gwrite!'
        elseif choice == 'theirs' then
          vim.cmd 'Gread!'
        elseif choice == 'both' then
          vim.cmd('G mergetool ' .. current_file)
        end
        vim.cmd 'DiffviewRefresh'
      end

      function Diffview_custom_log()
        vim.cmd 'DiffviewFileHistory %'
        -- vim.cmd 'botright new'
        -- vim.cmd 'resize 10'
        -- vim.cmd 'read !git log --oneline -n 10'
        -- vim.cmd 'setlocal nomodifiable'
        -- vim.cmd 'normal! gg'
      end

      function Diffview_fetch()
        vim.cmd 'Git fetch'
        vim.cmd 'DiffviewRefresh'
        print 'Fetched and refreshed'
      end

      local function setup_mappings()
        local map_opts = { noremap = true, silent = true }
        vim.api.nvim_buf_set_keymap(0, 'n', 's', '<Cmd>lua require("diffview.actions").toggle_stage_entry()<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'cc', '<Cmd>lua Open_commit_split()<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'P', '<Cmd>Git push | if v:shell_error | echo "Push failed" | endif<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'F', '<Cmd>Git pull | if v:shell_error | echo "Pull failed" | endif<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'q', '<Cmd>DiffviewClose<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'gs', '<Cmd>lua Diffview_summary()<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'gro', '<Cmd>lua Diffview_resolve_conflict("ours")<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'grt', '<Cmd>lua Diffview_resolve_conflict("theirs")<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'grb', '<Cmd>lua Diffview_resolve_conflict("both")<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'gl', '<Cmd>lua Diffview_custom_log()<CR>', map_opts)
        vim.api.nvim_buf_set_keymap(0, 'n', 'gf', '<Cmd>lua Diffview_fetch()<CR>', map_opts)
      end

      -- Set up autocmd to apply mappings to all Diffview buffers
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'DiffviewFiles', 'DiffviewFileHistory' },
        callback = setup_mappings,
      })

      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = 'diffview://*',
        callback = setup_mappings,
      })

      vim.api.nvim_create_user_command('GD', function(opts)
        if opts.args == '' then
          vim.cmd 'DiffviewOpen'
          setup_mappings()
        else
          vim.cmd('G ' .. opts.args)
        end
      end, { nargs = '*', complete = 'file' })
    end,
  },
  {
    'tpope/vim-fugitive',
    event = 'VeryLazy',
  },
  { 'EdenEast/nightfox.nvim' },
}
