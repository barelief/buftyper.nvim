-- buftyper/config.lua
local M = {}

M.options = {
  dim_hl             = "BufTyperDim",
  error_hl           = "BufTyperError",
  done_hl            = "BufTyperDone",
  show_wpm           = true,
  show_mode_indicator = false,  -- set true if you don't use lualine
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
