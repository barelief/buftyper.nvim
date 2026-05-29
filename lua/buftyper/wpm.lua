-- buftyper/wpm.lua
-- Live display: rolling LIVE_WINDOW_SECS average. Strokes age out of the window,
-- so the value decays naturally toward 0 over ~LIVE_WINDOW_SECS when you stop typing.
-- Summary: cumulative average over active typing time (idle gaps >IDLE_GAP_SECS excluded)
-- plus accuracy (correct_keystrokes / total_keystrokes).
local M = {}

local MIN_SECS         = 2   -- grace period before reporting a live value
local IDLE_GAP_SECS    = 3   -- summary: gaps larger than this don't count as active time
local LIVE_WINDOW_SECS = 5   -- live WPM trailing window

local timer            = nil
local first_stroke_hr  = nil
local last_stroke_hr   = nil
local session_start_hr = nil
local active_ns        = 0
local correct_chars    = 0
local incorrect_chars  = 0

-- Sequential list of recent strokes for the live window.
-- We keep it as a true sequence (no index holes) so `#hist` and `ipairs` are reliable.
local hist = {}

local function now() return vim.loop.hrtime() end

local function reset_state()
  first_stroke_hr = nil
  last_stroke_hr  = nil
  active_ns       = 0
  correct_chars   = 0
  incorrect_chars = 0
  hist            = {}
end

local function prune(cutoff_hr)
  while hist[1] and hist[1].t < cutoff_hr do
    table.remove(hist, 1)
  end
end

local function record_stroke(correct)
  local t = now()
  if first_stroke_hr then
    local gap = t - last_stroke_hr
    if gap < IDLE_GAP_SECS * 1e9 then
      active_ns = active_ns + gap
    end
  else
    first_stroke_hr = t
  end
  last_stroke_hr = t

  if correct then correct_chars = correct_chars + 1
  else incorrect_chars = incorrect_chars + 1 end

  table.insert(hist, { t = t, correct = correct })
  prune(t - LIVE_WINDOW_SECS * 1e9)
end

local function format_duration(secs)
  secs = math.floor(secs)
  local m = math.floor(secs / 60)
  local s = secs % 60
  if m > 0 then return string.format('%dm %ds', m, s) end
  return string.format('%ds', s)
end

function M.start()
  reset_state()
  session_start_hr = now()
  if timer then timer:stop() end
  timer = vim.loop.new_timer()
  timer:start(0, 500, vim.schedule_wrap(function() M.update() end))
end

function M.stop()
  if timer then timer:stop(); timer = nil end
end

function M.inc_correct()   record_stroke(true)  end
function M.inc_incorrect() record_stroke(false) end

function M.value()
  if not first_stroke_hr then return nil end
  local t = now()
  local session_elapsed = (t - first_stroke_hr) / 1e9
  if session_elapsed < MIN_SECS then return nil end

  prune(t - LIVE_WINDOW_SECS * 1e9)
  local correct_in_window = 0
  for _, h in ipairs(hist) do
    if h.correct then correct_in_window = correct_in_window + 1 end
  end

  local window = math.min(LIVE_WINDOW_SECS, session_elapsed)
  return math.floor((correct_in_window / 5) / (window / 60) + 0.5)
end

function M.live_accuracy()
  local total = correct_chars + incorrect_chars
  if total == 0 then return nil end
  return math.floor(correct_chars / total * 100 + 0.5)
end

function M.summary()
  local total_secs = session_start_hr and ((now() - session_start_hr) / 1e9) or 0
  local active_secs = active_ns / 1e9
  if last_stroke_hr then
    local cur_gap = (now() - last_stroke_hr) / 1e9
    if cur_gap < IDLE_GAP_SECS then active_secs = active_secs + cur_gap end
  end
  local total = correct_chars + incorrect_chars
  local wpm, accuracy
  if active_secs >= 1 then
    wpm = math.floor((correct_chars / 5) / (active_secs / 60) + 0.5)
  end
  if total > 0 then
    accuracy = math.floor(correct_chars / total * 100 + 0.5)
  end
  return {
    wpm      = wpm,
    accuracy = accuracy,
    duration = format_duration(total_secs),
  }
end

function M.update()
  if not require('buftyper.session').is_active() then return end
  if not require('buftyper.config').options.show_wpm then return end
  local ok, lualine = pcall(require, 'lualine')
  if ok then pcall(lualine.refresh) end
end

return M
