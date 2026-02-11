-- nvim-tree configuration with floating window
local function get_float_config()
  local screen_w = vim.opt.columns:get()
  local screen_h = vim.opt.lines:get() - vim.opt.cmdheight:get()
  local window_w = screen_w * 0.5
  local window_h = screen_h * 0.8
  local center_x = (screen_w - window_w) / 2
  local center_y = ((vim.opt.lines:get() - window_h) / 2) - vim.opt.cmdheight:get()

  return {
    border = 'rounded',
    relative = 'editor',
    row = center_y,
    col = center_x,
    width = math.floor(window_w),
    height = math.floor(window_h),
  }
end

require('nvim-tree').setup({
  disable_netrw = true,
  hijack_netrw = true,
  respect_buf_cwd = true,
  sync_root_with_cwd = true,
  view = {
    relativenumber = true,
    float = {
      enable = true,
      open_win_config = get_float_config,
    },
  },
})

vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = 'Toggle file explorer' })

-- Lualine configuration
require('lualine').setup({
  options = {
    theme = 'tokyonight',
  },
})

-- Gitsigns configuration
require('gitsigns').setup()

-- Comment.nvim configuration
require('Comment').setup()

-- Autopairs configuration
require('nvim-autopairs').setup()

-- Which-key configuration
require('which-key').setup()
