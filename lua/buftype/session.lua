-- buftype/session.lua
local config = require("buftype.config")
local highlight = require("buftype.highlight")
local wpm = require("buftype.wpm")

local M = {}

local session_state = nil
local autocmd_ids = {}
local keymap_modes = {} -- { [mode] = { key = true, ... } }

local function save_state(bufnr)
  return {
    bufnr = bufnr,
    wrap = vim.wo.wrap,
    modifiable = vim.bo[bufnr].modifiable,
    cursor = vim.api.nvim_win_get_cursor(0),
    statusline = vim.o.statusline, -- global (works with laststatus=3 / lualine)
    showmode = vim.o.showmode,
  }
end

local function restore_state(bufnr, state)
  vim.wo.wrap = state.wrap
  vim.bo[bufnr].modifiable = state.modifiable
  vim.o.showmode = state.showmode
  pcall(vim.api.nvim_win_set_cursor, 0, state.cursor)
end

local function add_keymap(mode, key, fn, bufnr)
  if type(fn) == "function" then
    vim.keymap.set(mode, key, fn, { buffer = bufnr, nowait = true, silent = true })
  else
    vim.api.nvim_buf_set_keymap(bufnr, mode, key, fn, { nowait = true, noremap = true, silent = true })
  end
  keymap_modes[mode] = keymap_modes[mode] or {}
  keymap_modes[mode][key] = true
end

local function clear_all_keymaps(bufnr)
  for mode, keys in pairs(keymap_modes) do
    for key in pairs(keys) do
      pcall(vim.api.nvim_buf_del_keymap, bufnr, mode, key)
    end
  end
  keymap_modes = {}
end

local function setup_keymaps(bufnr)
  local function handle_char(key)
    return function()
      if not session_state then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      line = line - 1
      local target_line = lines[line + 1] or ""
      local expected = target_line:sub(col + 1, col + 1)
      if key == expected then
        highlight.reveal_char(bufnr, line, col)
        wpm.inc_correct()
      else
        highlight.error_char(bufnr, line, col)
        wpm.inc_incorrect()
      end
      -- Always advance
      col = col + 1
      vim.api.nvim_win_set_cursor(0, { line + 1, col })
      local cl, cc = unpack(vim.api.nvim_win_get_cursor(0))
      highlight.set_cursor_char(bufnr, cl - 1, cc)
      highlight.update_word_highlights(bufnr, cl - 1, cc)
    end
  end

  -- All printable ASCII in insert mode
  for i = 32, 126 do
    local k = string.char(i)
    add_keymap("i", k, handle_char(k), bufnr)
  end

  -- Backspace
  add_keymap("i", "<BS>", function()
    if not session_state then
      return
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    line = line - 1
    if col > 0 then
      col = col - 1
      highlight.dim_char(bufnr, line, col)
      vim.api.nvim_win_set_cursor(0, { line + 1, col })
    elseif line > 0 then
      line = line - 1
      col = #(lines[line + 1] or "")
      highlight.dim_char(bufnr, line, col)
      vim.api.nvim_win_set_cursor(0, { line + 1, col })
    end
    highlight.set_cursor_char(bufnr, line, col)
    highlight.update_word_highlights(bufnr, line, col)
  end, bufnr)

  -- Enter: only advance when at end of line (col == #current_line)
  add_keymap("i", "<CR>", function()
    if not session_state then
      return
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    line = line - 1
    local target_line = lines[line + 1] or ""
    if col >= #target_line and line + 1 < #lines then
      wpm.inc_correct()
      line = line + 1
      col = 0
      vim.api.nvim_win_set_cursor(0, { line + 1, col })
    end
    highlight.set_cursor_char(bufnr, line, col)
    highlight.update_word_highlights(bufnr, line, col)
  end, bufnr)

  -- Esc exits
  add_keymap("i", "<Esc>", function()
    M.deactivate()
  end, bufnr)
  -- Normal mode Esc also deactivates (in case ModeChanged fires late)
  add_keymap("n", "<Esc>", function()
    M.deactivate()
  end, bufnr)
end

local function lualine_patch(session_st)
  local ok_ll, lualine = pcall(require, "lualine")
  local ok_lc, lc = pcall(require, "lualine.config")
  if not ok_ll or not ok_lc then
    return false
  end

  local current = lc.get_config()
  session_st.lualine_config = vim.deepcopy(current)
  local patched = vim.deepcopy(current)

  -- Replace mode with TYPING
  patched.sections.lualine_a = {
    function()
      return "TYPING"
    end,
  }

  -- Add WPM component to the right side
  patched.sections.lualine_z = patched.sections.lualine_z or {}
  table.insert(patched.sections.lualine_z, 1, function()
    local v = require("buftype.wpm").value()
    return v and ("⌨ " .. tostring(v) .. " WPM") or "⌨ —"
  end)

  lualine.setup(patched)
  lualine.refresh()
  return true
end

local function lualine_restore(session_st)
  if not session_st.lualine_config then
    return
  end
  local ok, lualine = pcall(require, "lualine")
  if not ok then
    return
  end
  lualine.setup(session_st.lualine_config)
  lualine.refresh()
end

function M.is_active()
  return session_state ~= nil
end

function M.activate()
  local bufnr = vim.api.nvim_get_current_buf()
  if session_state then
    return
  end
  session_state = save_state(bufnr)

  vim.wo.wrap = true
  vim.bo[bufnr].modifiable = false
  highlight.setup_highlights()
  highlight.dim_all(bufnr)
  wpm.start()
  setup_keymaps(bufnr)

  -- Highlight the first char to type
  local start_line, start_col = unpack(vim.api.nvim_win_get_cursor(0))
  highlight.set_cursor_char(bufnr, start_line - 1, start_col)
  highlight.update_word_highlights(bufnr, start_line - 1, start_col)

  -- Force stay in insert mode when anything moves us to normal/visual/etc.
  local aid = vim.api.nvim_create_autocmd("ModeChanged", {
    buffer = bufnr,
    callback = function()
      if not session_state then
        return
      end
      local m = vim.fn.mode()
      if m ~= "i" and m ~= "ic" and m ~= "ix" then
        vim.schedule(function()
          if session_state then
            vim.cmd("startinsert")
          end
        end)
      end
    end,
  })
  table.insert(autocmd_ids, aid)

  -- Re-apply highlight groups if colorscheme changes mid-session
  local cs_aid = vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      if session_state then
        highlight.setup_highlights()
      end
    end,
  })
  table.insert(autocmd_ids, cs_aid)

  vim.api.nvim_echo({ { "  TYPING mode — press <Esc> to exit", "Comment" } }, false, {})
  vim.o.showmode = false

  -- Patch lualine if available, otherwise fall back to plain statusline
  if not lualine_patch(session_state) then
    vim.o.statusline = "%#ModeMsg#  TYPING  %*  %f  %=  ⌨ — WPM  │  <Esc> to finish  %l:%c"
  end

  vim.cmd("startinsert")
end

function M.deactivate()
  if not session_state then
    return
  end
  local saved = session_state
  session_state = nil -- clear first so ModeChanged doesn't re-enter insert

  local bufnr = saved.bufnr

  for _, id in ipairs(autocmd_ids) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  autocmd_ids = {}

  highlight.clear_all(bufnr)
  wpm.stop()
  local summary = wpm.summary()
  vim.bo[bufnr].modifiable = true
  lualine_restore(saved)
  restore_state(bufnr, saved)
  clear_all_keymaps(bufnr)
  vim.cmd("stopinsert")
  vim.schedule(function()
    local parts = { { '  ', 'Normal' } }
    if summary.wpm then
      table.insert(parts, { '󰓅 Avg. ' .. tostring(summary.wpm) .. ' WPM', 'ModeMsg' })
      if summary.accuracy then
        table.insert(parts, { ' · ' .. tostring(summary.accuracy) .. '%', 'Comment' })
      end
      table.insert(parts, { '   󰔛 Sess. ' .. summary.duration, 'Comment' })
    else
      table.insert(parts, { '󰔛 Sess. ' .. summary.duration, 'Comment' })
    end
    vim.api.nvim_echo(parts, true, {})
  end)
end

return M
