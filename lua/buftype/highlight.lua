-- buftype/highlight.lua
local M = {}
local ns        = vim.api.nvim_create_namespace('buftype')
local ns_cursor = vim.api.nvim_create_namespace('buftype_cursor')
local ns_words  = vim.api.nvim_create_namespace('buftype_words')

function M.setup_highlights()
  -- Lighter gray than Comment — clearly dimmed but still readable
  vim.cmd([[highlight default BufTypeDim   guifg=#888888 ctermfg=102]])
  vim.cmd([[highlight default BufTypeError guifg=#ffff00 guibg=#ff0000 gui=bold,undercurl guisp=#ffff00 ctermfg=15 ctermbg=203]])
  vim.cmd([[highlight default link BufTypeDone  NONE]])
  vim.cmd([[highlight default BufTypeCursor guifg=#000000 guibg=#e5c07b ctermfg=0 ctermbg=214]])
  -- Current word: dimmed orange. Next word: bright orange.
  vim.cmd([[highlight default BufTypeCurrentWord guifg=#a05a2c ctermfg=130]])
  vim.cmd([[highlight default BufTypeNextWord    guifg=#ff8c00 ctermfg=208]])
end

local function find_words(line_text)
  local words = {}
  local i = 1
  while i <= #line_text do
    local s = line_text:find('%S', i)
    if not s then break end
    local e = line_text:find('%s', s) or (#line_text + 1)
    table.insert(words, { s = s - 1, e = e - 1 })
    i = e
  end
  return words
end

-- Highlight current word (containing or just after the cursor) in dim orange,
-- and the following word in bright orange.
function M.update_word_highlights(bufnr, line, col)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_words, 0, -1)
  local total = vim.api.nvim_buf_line_count(bufnr)

  local current, next_word

  -- Look starting from current line
  local l = line
  while l < total and not current do
    local text = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1] or ""
    local ws = find_words(text)
    for i, w in ipairs(ws) do
      local start_col = (l == line) and col or 0
      if w.e > start_col then
        current = { line = l, s = math.max(w.s, start_col), e = w.e }
        if ws[i + 1] then
          next_word = { line = l, s = ws[i + 1].s, e = ws[i + 1].e }
        end
        break
      end
    end
    l = l + 1
  end

  -- If next_word still missing, search subsequent lines
  if current and not next_word then
    local ll = current.line + 1
    while ll < total do
      local text = vim.api.nvim_buf_get_lines(bufnr, ll, ll + 1, false)[1] or ""
      local ws = find_words(text)
      if #ws > 0 then
        next_word = { line = ll, s = ws[1].s, e = ws[1].e }
        break
      end
      ll = ll + 1
    end
  end

  if current then
    vim.api.nvim_buf_set_extmark(bufnr, ns_words, current.line, current.s, {
      end_col  = current.e,
      hl_group = 'BufTypeCurrentWord',
      hl_mode  = 'replace',
      priority = 1100,
    })
  end
  if next_word then
    vim.api.nvim_buf_set_extmark(bufnr, ns_words, next_word.line, next_word.s, {
      end_col  = next_word.e,
      hl_group = 'BufTypeNextWord',
      hl_mode  = 'replace',
      priority = 1100,
    })
  end
end

function M.dim_all(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for l, line in ipairs(lines) do
    for c = 0, #line - 1 do
      vim.api.nvim_buf_set_extmark(bufnr, ns, l - 1, c, {
        end_col  = c + 1,
        hl_group = require('buftype.config').options.dim_hl,
        hl_mode  = 'replace',
        priority = 1000,
      })
    end
  end
end

function M.dim_char(bufnr, line, col)
  local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
  if col >= #line_text then return end
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, {line, col}, {line, col + 1}, {})
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(bufnr, ns, mark[1])
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
    end_col  = col + 1,
    hl_group = require('buftype.config').options.dim_hl,
    hl_mode  = 'replace',
    priority = 1000,
  })
end

-- Deletes dim/error extmark — underlying treesitter syntax shows through.
function M.reveal_char(bufnr, line, col)
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, {line, col}, {line, col + 1}, {})
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(bufnr, ns, mark[1])
  end
end

-- Error has highest priority (1200) so it always shows above the cursor marker.
function M.error_char(bufnr, line, col)
  local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
  if col >= #line_text then return end
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, {line, col}, {line, col + 1}, {})
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(bufnr, ns, mark[1])
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns, line, col, {
    end_col  = col + 1,
    hl_group = require('buftype.config').options.error_hl,
    hl_mode  = 'replace',
    priority = 1200,
  })
end

-- Cursor marker: yellow = waiting, red = just typed wrong
function M.set_cursor_char(bufnr, line, col)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_cursor, 0, -1)
  local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
  if col >= #line_text then
    vim.api.nvim_buf_set_extmark(bufnr, ns_cursor, line, math.max(col - 1, 0), {
      virt_text     = { { ' ↵', 'BufTypeCursor' } },
      virt_text_pos = 'eol',
    })
    return
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns_cursor, line, col, {
    end_col  = col + 1,
    hl_group = 'BufTypeCursor',
    hl_mode  = 'replace',
    priority = 1300,
  })
end

-- Red cursor: shown when wrong key was pressed on this char
function M.set_error_cursor(bufnr, line, col)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_cursor, 0, -1)
  local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
  if col >= #line_text then return end
  vim.api.nvim_buf_set_extmark(bufnr, ns_cursor, line, col, {
    end_col  = col + 1,
    hl_group = require('buftype.config').options.error_hl,
    hl_mode  = 'replace',
    priority = 1300,
  })
end

function M.clear_all(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns,        0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_cursor, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_words,  0, -1)
end

return M
