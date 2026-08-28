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
  git = {
    enable = true,
  },
  renderer = {
    highlight_git = "name",
    icons = {
      show = {
        git = true,
      },
    },
  },
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
require('gitsigns').setup({
  on_attach = function(bufnr)
    local gs = require('gitsigns')

    local function map(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
    end

    -- Hunk navigation
    map('n', ']c', function()
      if vim.wo.diff then
        vim.cmd.normal({ ']c', bang = true })
      else
        gs.nav_hunk('next')
      end
    end, 'Next hunk')

    map('n', '[c', function()
      if vim.wo.diff then
        vim.cmd.normal({ '[c', bang = true })
      else
        gs.nav_hunk('prev')
      end
    end, 'Prev hunk')

    -- Hunk actions
    map('n', '<leader>hs', gs.stage_hunk, 'Stage hunk')
    map('n', '<leader>hr', gs.reset_hunk, 'Reset hunk')
    map('v', '<leader>hs', function() gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Stage hunk')
    map('v', '<leader>hr', function() gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') }) end, 'Reset hunk')
    map('n', '<leader>hS', gs.stage_buffer, 'Stage buffer')
    map('n', '<leader>hR', gs.reset_buffer, 'Reset buffer')
    map('n', '<leader>hu', gs.undo_stage_hunk, 'Undo stage hunk')
    map('n', '<leader>hp', gs.preview_hunk, 'Preview hunk')
    map('n', '<leader>hb', function() gs.blame_line({ full = true }) end, 'Blame line')
    map('n', '<leader>tb', gs.toggle_current_line_blame, 'Toggle line blame')
    map('n', '<leader>hd', gs.diffthis, 'Diff this')
    map('n', '<leader>td', gs.toggle_deleted, 'Toggle deleted')

    -- Text object for a hunk
    map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Select hunk')
  end,
})

-- Diffview configuration
require('diffview').setup()

vim.keymap.set('n', '<leader>gd', ':DiffviewOpen<CR>', { desc = 'Open diff view' })
vim.keymap.set('n', '<leader>gh', ':DiffviewFileHistory<CR>', { desc = 'File history (diff view)' })
vim.keymap.set('n', '<leader>gq', ':DiffviewClose<CR>', { desc = 'Close diff view' })

-- Comment.nvim configuration
require('Comment').setup()

-- Autopairs configuration
require('nvim-autopairs').setup()

-- Which-key configuration
require('which-key').setup()
