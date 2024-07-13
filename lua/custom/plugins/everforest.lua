return {
  'neanias/everforest-nvim',
  version = false,
  lazy = false,
  priority = 1000, -- make sure to load this before all the other start plugins
  init = function()
    -- Load the colorscheme here.
    -- Like many other themes, this one has different styles, and you could load
    vim.cmd.colorscheme 'everforest'

    -- You can configure highlights by doing something like
    vim.cmd.hi 'Comment gui=none'
  end,
}
