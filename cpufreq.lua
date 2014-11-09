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

local io           = { popen = io.popen }
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
  widget:buttons(awful.util.table.join(awful.button({ }, 2, function()
    cpupower:menu()
  end)))
end

function cpupower:menu()
  cpupower:hide()
  -- 1. /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies
  local freqs = {}
  local governors = {}
  local fp = io.open('/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies', 'r')
  while true do
    local f = fp:read('*n')
    if f ~= nil then
      freqs[#freqs+1] = f
    else
      break
    end
  end
  fp:close()
  -- 2. /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
  fp = io.open('/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors', 'r')
  while true do
    -- nie ma read word, trzeba splitowac
    local f = fp:read('*n')
    if f ~= nil then
      freqs[#freqs+1] = f
    else
      break
    end
  end
  fp:close()

end


return setmetatable(cpupower, { __call = function(_, ...) return create(...) end })
