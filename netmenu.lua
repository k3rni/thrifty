local awful = require("awful")
local naughty = require("naughty")

-- lua, napisz se stdlib zanim zaczniesz pisać program
function shell(command)
  local fp = io.popen(command, "r")
  return fp:read("*a")
end

function split(str, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep)
  string.gsub(str, pattern, function(c) fields[#fields+1] = c end)
  return fields
end

function array_join( ...)
  local result = {}
  for i = 1, select('#', ...) do
    local that = select(i, ...)
    if type(that) == 'table' then
      for _, v in ipairs(that) do
        result[#result + 1] = v
      end
    else
      result[#result + 1] = that
    end
  end
  return result
end

function toggle_connect(devname)
  -- TODO: napisz; nmcli dev cośtam
  naughty.notify({text = 'TC ' .. devname})
end

function nm_connect_wifi(options)
  local ssid = options.ssid
  local bssid = options.bssid
  local key = options.key
  -- is there a way to read status? :(
  -- TODO: awful.util.spawn
  local result = shell("nmcli dev wifi connect '" .. ssid .. "' bssid " .. bssid)
  if result == "" then
    naughty.notify({text = "Connected to " .. ssid})
  else
    naughty.notify({text = result})
  end
end

function connect_ssid(ssid, bssid, security)
  naughty.notify({text = 'CS ' .. ssid .. ',' .. security})
  if security == 'OPEN' then
    nm_connect_wifi({ssid = ssid, bssid = bssid})
  else
    local keep_trying = true
    while keep_trying do
      -- prompt for password
      -- try connecting
      -- retry if nm fails; loop until connected or user aborts
      awful.prompt.run({prompt = security .. ' key/password: '},
                  mypromptbox[mouse.screen].widget,
                  function(pass) nm_connect_wifi({ssid = ssid, bssid = bssid, password = pass}) end
                )
      keep_trying = false
    end
  end
end

function dev_status()
  local lines = split(shell("nmcli --terse --fields device,type,state dev"), "\n")
  local menuitems = {}
  for i, line in ipairs(lines) do
    local devname, devtype, devstatus
    devname, devtype, devstatus = unpack(split(line, ':'))
    -- TODO: doczep ikonkę z theme (w powerarrow masz net i net_wired)
    if devtype ~= 'loopback' then
      local tick = " "
      if devstatus == 'connected' then tick = "✓" end
      menuitems[#menuitems + 1] = { tick .. ' ' .. devname .. '(' .. devtype .. ')', function() toggle_connect(devname) end }
    end
  end
  return menuitems
end

function list_ssids()
  local lines = split(shell("nmcli --terse --fields active,ssid,signal,bars,security dev wifi list | sort -t: -k3 -gr"), "\n")
  local menuitems = {}
  for i, line in ipairs(lines) do
    local active, ssid, signal, bars, security, tick 
    active, ssid, signal, bars, security = unpack(split(line, ':'))
    if active == 'yes' then tick = "✓" else tick = " " end
    if security == nil then security = 'OPEN' end
    -- naughty.notify({text =  tick .. ' ' .. ssid .. ' ' .. bars .. security}) 
    menuitems[#menuitems + 1] = { tick .. ' ' .. bars .. ' ' .. ' ' .. ssid .. ' ' .. security, function() connect_ssid(ssid, security) end } 
  end
  return menuitems
end

function list_ssids_with_submenu(start)
  -- list, sort as usual, limit to 10, present rest in a submenu
  -- by calling itself
  local start = start or 0
  local lines = split(shell("nmcli --terse --fields active,ssid,bssid,signal,bars,security dev wifi list | sed -e 's/\\\\:/-/g' | sort -t: -k4 -gr | tail -n +" .. start .. " | head -10"), "\n")
  local menuitems = {}
  if #lines == 10 then
    menuitems[#menuitems + 1] = { "More", list_ssids_with_submenu(start + 10) }
    -- separators?
  end
  for i, line in ipairs(lines) do
    local active, ssid, bssid, signal, bars, security, tick 
    active, ssid, bssid, signal, bars, security = unpack(split(line, ':'))
    if active == 'yes' then tick = "✓" else tick = " " end
    if security == nil then security = 'OPEN' end
    -- naughty.notify({text =  tick .. ' ' .. ssid .. ' ' .. bars .. security}) 
    menuitems[#menuitems + 1] = { tick .. ' ' .. bars .. ' ' .. ' ' .. ssid .. ' ' .. security, function() connect_ssid(ssid, bssid, security) end } 
  end
  return menuitems
end

function netmenu()
  local menu = awful.menu.new({
    items = array_join( 
      dev_status(), 
      { { 'Networks', list_ssids_with_submenu() } }
    ),
    theme = {
      width = 250
    },
  })
  return menu
end

local menu = netmenu()
menu:toggle()

