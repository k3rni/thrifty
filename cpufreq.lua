-- 1. na mouseover wyświetl textboxa z informacją z cpupower
-- 2. na rklika wyświetl menu:
--    - jeśli tylko 1 cpu, pomiń submenu, wyświetl od razu
--    - per cpu, wyświetl listę freq i governorów
--    - na wybranie freq spróbuj ustawić ten freq
--    - na wybranie gov spróbuj ustawić tego gov (będzie wymagać sudo)
--

local awful        = require("awful")
local beautiful    = require("beautiful")
local naughty      = require("naughty")

local io           = { popen = io.popen, open = io.open }
local os           = { date = os.date }
local tonumber     = tonumber

local cpupower = {}
local cpupower_notification = nil

function cpupower:hide()
  if cpupower_notification ~= nil then
    naughty.destroy(cpupower_notification)
    cpupower_notification = nil
  end
end

function cpupower:show(timeout, scr)
  cpupower:hide()
  local f, text
  f = io.popen('cpupower frequency-info')
  text = '<tt>' .. f:read('*a') .. '</tt>'
  f:close()

  cpupower_notification = naughty.notify({
    text = text,
    timeout = timeout or 0,
    screen = scr or 1
  })
end

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

function current_freq()
  -- wczytaj /proc/cpuinfo, wez pierwsza odczytana wartosc
  local fp = io.open('/proc/cpuinfo')
  for line in fp:lines() do
    local freq
    freq = string.match(line, 'cpu MHz%s+:%s+(%d+.%d+)')
    -- naughty.notify({text = 'L=' .. line }) 
    if freq ~= nil then
      return tonumber(string.gsub(freq, '%.', ''), 10)
    end
  end
end

function mhz_string(freq)
  local freq = tonumber(freq, 10)
  local repr
  if freq > 1e6 then
    repr = string.format('%.2f GHz', freq / 1e6)
  else
    repr = string.format('%.2f MHz', freq / 1e3)
  end
  return string.gsub(string.gsub(repr, '0+%s', ' '), '%. ', ' ')
end

function cpupower:build_menu()
  cpupower:hide()
  -- 1. /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies
  local freqs = {}
  local governors = {}
  local fp = io.open('/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies', 'r')
  for line in fp:lines('*n') do
    freqs[#freqs+1] = line
  end
  fp:close()
  -- 2. /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
  fp = io.open('/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors', 'r')
  -- TODO
  fp:close()
  local freq_items = {}
  local menu = awful.menu.new()
  for i, freq in ipairs(freqs) do
    local freq = tonumber(freq)
    local label = mhz_string(freq)
    local theme
    if freq == current_freq() then
      theme = {}
    else
      theme = {font = beautiful.get().font .. ' bold'}
    end
    -- freq_items[#freq_items + 1] = { label, function() try_set_freq(freq) end }
    menu:add({theme = theme, text = label, cmd = function() try_set_freq(freq) end })
  end
  local governor_items = {}
  -- return awful.menu.new({items = freq_items })
  return menu
end

function cpupower:menu()
  if cpupower.menulist == nil then
    cpupower.menulist = cpupower:build_menu()
  end

  cpupower.menulist:toggle()
end

return setmetatable(cpupower, { __call = function(_, ...) return create(...) end })
