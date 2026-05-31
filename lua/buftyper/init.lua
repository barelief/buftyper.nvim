-- buftyper/init.lua
local M = {}

local config  = require('buftyper.config')
local session = require('buftyper.session')

local mode_labels = {
  n  = { 'NORMAL',   'Statement' },
  i  = { 'INSERT',   'String'    },
  v  = { 'VISUAL',   'Special'   },
  V  = { 'V-LINE',   'Special'   },
  ['\22'] = { 'V-BLOCK', 'Special' },
  c  = { 'COMMAND',  'WarningMsg'},
  R  = { 'REPLACE',  'Error'     },
  t  = { 'TERMINAL', 'Comment'   },
}

local function update_mode_indicator()
  if session.is_active() then return end  -- BufTyper sets its own statusline
  local m    = vim.fn.mode()
  local info = mode_labels[m] or { m:upper(), 'Normal' }
  vim.wo.statusline = string.format('%%#%s#  %s  %%* %%f %%=%%l:%%c', info[2], info[1])
end

function M.setup(opts)
  config.setup(opts)
  if config.options.show_mode_indicator then
    vim.api.nvim_create_autocmd({ 'ModeChanged', 'BufEnter', 'WinEnter' }, {
      callback = update_mode_indicator,
    })
    update_mode_indicator()
  end
end

function M.activate(opts)
  session.activate(opts)
end

return M
