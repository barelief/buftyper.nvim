-- plugin/buftyper.lua
local buftyper = require('buftyper')

vim.api.nvim_create_user_command('BufTyper', function()
  buftyper.activate()
end, { desc = 'Activate Buffer Typing Mode' })

vim.keymap.set('n', '<leader>uB', function()
  buftyper.activate()
end, { desc = 'Buffer Typing Mode' })

vim.keymap.set('v', '<leader>uB', function()
  local mode = vim.fn.mode()

  -- Read the LIVE selection. While still in visual mode the '< / '> marks hold
  -- the *previous* selection, so use getpos('v') (anchor) and getpos('.') (cursor).
  -- getpos returns 1-based line and 1-based byte col; convert to 0-based.
  local vpos = vim.fn.getpos('v')
  local cpos = vim.fn.getpos('.')
  local start_line, start_col = vpos[2] - 1, vpos[3] - 1
  local end_line, end_col     = cpos[2] - 1, cpos[3] - 1

  -- Leave visual mode so we start the session cleanly in insert.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)

  -- Normalize: ensure start is before end
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  -- For linewise visual, practice full lines
  if mode == 'V' then
    start_col = 0
    local last_line = vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, false)[1] or ""
    end_col = #last_line > 0 and (#last_line - 1) or 0
  end

  buftyper.activate({
    start_line = start_line,
    start_col  = start_col,
    end_line   = end_line,
    end_col    = end_col,
  })
end, { desc = 'Buffer Typing Mode (selection)' })

-- Auto-deactivate on BufLeave
vim.api.nvim_create_autocmd('BufLeave', {
  callback = function()
    if package.loaded['buftyper.session'] then
      require('buftyper.session').deactivate()
    end
  end,
})
