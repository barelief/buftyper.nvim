-- plugin/buftyper.lua
local buftyper = require('buftyper')

vim.api.nvim_create_user_command('BufTyper', function()
  buftyper.activate()
end, { desc = 'Activate Buffer Typing Mode' })

vim.keymap.set('n', '<leader>uB', function()
  buftyper.activate()
end, { desc = 'Buffer Typing Mode' })

-- Auto-deactivate on BufLeave
vim.api.nvim_create_autocmd('BufLeave', {
  callback = function()
    if package.loaded['buftyper.session'] then
      require('buftyper.session').deactivate()
    end
  end,
})
