-- The cpupower tools need root priviledges. To make this script work,
-- put these lines in a file under /etc/sudoers.d or just add them near
-- the end of /etc/sudoers (using `visudo`)
-- ## Allow cpufreq commands for anybody
-- Cmnd_AliasCPUFREQ = /usr/bin/cpupower 
-- ALL ALL=(ALL) NOPASSWD: CPUFREQ

local awful        = require("awful")
local naughty      = require("naughty")
local io           = { popen = io.popen, open = io.open }
local os           = { date = os.date }
local tonumber     = tonumber

local cpupower = {path = '/sys/devices/system/cpu/cpu0/',
                  command = 'sudo cpupower'}
local cpupower_notification = nil

-- hide the notification, useful when we want to show the menu
function cpupower:hide()
  if cpupower_notification ~= nil then
    naughty.destroy(cpupower_notification)
    cpupower_notification = nil
  end
end

-- show notification, containing data returned by cpupower command
-- timeout: time in seconds to keep notification. skip to use naughty's default
-- scr: screen to display on, skip to use current (wherever the mouse pointer is)
function cpupower:show(timeout, scr)
  cpupower:hide()
  local f, text
  f = io.popen('cpupower frequency-info')
  text = '<tt>' .. f:read('*a') .. '</tt>'
  f:close()

  cpupower_notification = naughty.notify({
    text = text,
    timeout = timeout or 0,
    screen = scr or mouse.screen
  })
end

-- install our event handlers (mouseover and click) on a widget
-- widget: a standard awful widget
-- args: optional table with scr_pos - screen number and position - top_left or top_right
function cpupower:attach(widget, args)
  local args = args or {}
  cpupower.scr_pos = args.scr_pos or 1
  cpupower.position = args.position or "top_right"
  widget:connect_signal('mouse::enter', function() cpupower:show(0, scr_pos) end)
  widget:connect_signal('mouse::leave', function() cpupower:hide() end)
  widget:buttons(awful.util.table.join(
    awful.button({ }, 1, function() cpupower:menu() end))
  )
end

-- read current CPU frequency from /proc/cpuinfo
-- cannot read this from /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq because the
-- default permissions don't allow it
function current_freq()
  local fp = io.open('/proc/cpuinfo')
  for line in fp:lines() do
    local freq
    freq = string.match(line, 'cpu MHz%s+:%s+(%d+.%d+)')
    if freq ~= nil then
      -- strip the dot and parse as number
      return tonumber(string.gsub(freq, '%.', ''), 10)
    end
  end
end

-- get current scaling upper and lower frequencies
function cpupower:read_scaling_limits()
  local fp
  fp = io.open(cpupower.path .. 'cpufreq/scaling_min_freq', 'r')
  local current_lower = fp:read('*n')
  fp:close()

  fp = io.open(cpupower.path .. 'cpufreq/scaling_max_freq', 'r')
  local current_upper = fp:read('*n')
  fp:close()

  return current_lower, current_upper
end

-- format a number given in kHz (as returned by read_scaling_limits() or current_freq())
-- in MHz or GHz if appropriate. 
function mhz_string(freq)
  local freq = tonumber(freq, 10)
  local repr
  if freq > 1e6 then
    -- scale into GHz
    repr = string.format('%.2f GHz', freq / 1e6)
  else
    repr = string.format('%.2f MHz', freq / 1e3)
  end
  -- strip any trailing zeros, and then any dangling decimal points
  return string.gsub(string.gsub(repr, '0+%s', ' '), '%. ', ' ')
end

-- create the menu
function cpupower:build_menu()
  cpupower:hide()

  -- read available frequencies
  -- Assumption: all CPUs have the same set of frequencies.
  local freqs = {}
  local fp = io.open(cpupower.path .. 'cpufreq/scaling_available_frequencies', 'r')
  for line in fp:lines('*n') do
    freqs[#freqs+1] = line
  end
  fp:close()

  -- read available governors
  -- those are usually provided by kernel modules: cpufreq_<governor_name>
  -- standard governors are ondemand, performance, conservative, powersave
  local governors = {}
  fp = io.open(cpupower.path .. 'cpufreq/scaling_available_governors', 'r')
  local line = fp:read('*l')
  for word in string.gmatch(line, '%a+') do
    governors[#governors + 1] = word
  end
  fp:close()

  current_lower, current_upper = cpupower:read_scaling_limits()

  -- add menu items to choose governor
  local menu = awful.menu.new()
  for i, gov in ipairs(governors) do
    menu:add({text = gov, cmd = function() cpupower:set_governor(gov) end})
  end

  -- add submenus for upper and lower frequency bounds (for selected governor)
  menu:add({text = 'set upper', cmd = cpupower:freq_menu(freqs, function(freq) return (freq == current_upper) end,
  function(...) cpupower:set_upper_limit(...) end)})
  menu:add({text = 'set lower', cmd = cpupower:freq_menu(freqs, function(freq) return (freq == current_lower) end,
  function(...) cpupower:set_lower_limit(...) end)})
  return menu
end

-- generate a frequency menu from the given list, emblem func and command
-- emblem is a callable that can return true or a string; it's called for each
-- frequency, and if it returns a string, it's added to the menu entry. additionaly,
-- if it returns true instead of a string, a tickmark ('✓') is added instead.
-- cmd is a function to call with the selected frequency
function cpupower:freq_menu(freqs, emblem, cmd)
  local menuitems = {}
  for i, freq in ipairs(freqs) do
    local freq = tonumber(freq)
    local label = mhz_string(freq)
    local em = emblem(freq)
    if em then
      if em == true then em = '✓' end
      label = label .. em
    end
    menuitems[#menuitems + 1] = { text = label, cmd = function() cmd(freq) end }
  end
  return menuitems
end

-- toggle menu display
function cpupower:menu()
  cpupower.menulist = cpupower:build_menu()
  cpupower.menulist:toggle()
end

-- use cpupower command to set scaling parameters
-- display whatever is returned as a popup
function cpupower:set_governor(governor)
  local fp = io.popen(cpupower.command .. ' frequency-set --governor ' .. governor)
  naughty.notify({text = fp:read('*a')})
  fp:close()
end

function cpupower:set_lower_limit(freq)
  local fp = io.popen(cpupower.command .. ' frequency-set --min ' .. freq)
  naughty.notify({text = fp:read('*a')})
  fp:close()
end

function cpupower:set_upper_limit(freq)
  local fp = io.popen(cpupower.command .. ' frequency-set --max ' .. freq)
  naughty.notify({text = fp:read('*a')})
  fp:close()
end

return setmetatable(cpupower, { __call = function(_, ...) return create(...) end })
