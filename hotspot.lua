#!/usr/bin/env lua
--[[
	MikroTik HotSpot Gateway (Captive Portal) CHAP login script
	Dependencies: lua, lua-md5, luasocket
--]]

md5 = require "md5"
socket = require "socket"
http = require "socket.http"

function usage(msg)
  print([[
MikroTik HotSpot Gateway login script (]] .. _VERSION .. [[)
Usage: ]] .. arg[0] .. [[ login|logout|status [Options]

Options:
  -g <gateway-ip>  IP-Address/Hostname of hotspot gateway (always required)
  -u <username>    Username for login
  -p <password>    Password for login
  -c <condition>   Condition when to renew an existing session
]])
  if msg then print("Usage error: " .. msg) end
  os.exit(1)
end

function main()
  local cmd
  if arg[1] and string.sub(arg[1], 1, 1) ~= "-" then
    cmd = table.remove(arg,1)
  end

  local opts = getopt(arg,  "gupc")
  if not opts.g then
    usage("Gateway parameter is required")
  elseif not string.find(opts.g, "^https?://") then
    opts.g = "http://" .. opts.g
  end

  if cmd == "login" or (not cmd and opts.u and opts.p) then
    if not opts.u or not opts.p then
      usage("User and password parameters are required for login")
    end
    local loggedin = retry(3, login, opts.g, opts.u, opts.p, opts.c)
    os.exit(loggedin and 0 or 1)
  elseif cmd == "status" or not cmd then
    local loggedin = status(opts.g)
    os.exit(loggedin and 0 or 1)
  elseif cmd == "logout" then
    logout(opts.g)
  else
    usage("Unknown command: " .. cmd)
  end
end

function parse_numbers(text, units)
  local result = 0
  local m,v,u
  repeat
    m,v,u = string.match(text, "(([%d%.]+) ?([%l%u]+))")
    if m then
      assert(units[u], "Unknown unit: " .. u)
      result = result + tonumber(v) * units[u]
      text = string.sub(text, string.len(m)+1)
    end
  until not m
  return result
end

local traffic_units = {
  ["PiB"] = 2^50,
  ["TiB"] = 2^40,
  ["GiB"] = 2^30,
  ["MiB"] = 2^20,
  ["KiB"] = 2^10,
    ["B"] = 1
}

local interval_units = {
  ["d"] = 3600 * 24,
  ["h"] = 3600,
  ["m"] = 60,
  ["s"] = 1
}

function status(gateway)
  local b,c = http.request(gateway .. "/status")
  assert(b, "Gateway error: " .. c)

  local status = {}
  status.user = string.match(b, "Welcome ([^!]+)!")

  if c == 200 and status.user then
    status.ip = string.match(b, "IP address:</td><td>([%d%.]+)")
    status.up_t, status.down_t = string.match(b, "bytes up/down:</td><td>([%w%. ]+) / ([%w%. ]+)")
    status.connected_t, status.left_t = string.match(b, "connected / left:</td><td>([%w ]+) / ([%w ]+)")

    if not status.connected_t or not status.left_t then
      status.connected_t = string.match(b, "connected:</td><td>([%w ]+)") or 0
      status.left_t = 0
    end

    if not status.user or not status.ip or not status.up_t or not status.down_t then
      print("Logged in, but status parsing failed.")
      if b then print("=== Status: ===\n" .. b .. "\n=== /Status ===") end
      return false
    end

    print("User:      " .. status.user)
    print("IP:        " .. status.ip)
    print("Up/Down:   " .. status.up_t .. " / " .. status.down_t)
    print("Conn/Left: " .. status.connected_t .. " / " .. status.left_t)

    status.up = parse_numbers(status.up_t, traffic_units)
    status.down = parse_numbers(status.down_t, traffic_units)
    status.connected = parse_numbers(status.connected_t, interval_units)
    status.left = parse_numbers(status.left_t, interval_units)
    return status

  elseif string.find(b, "document.redirect.submit()", 1, true) then
    print("Not logged in (redirected to portal).")
    return false
  end

  error("Login state unknown (" .. c .. ").")
end

function load_code(code, env)
  -- lua 5.1: loadstring, >=5.2: load
  if setfenv and loadstring then
    local f = assert(loadstring(code))
    setfenv(f, env)
    return f
  else
    return assert(load(code, nil, "t", env))
  end
end

function login(gateway, user, pw, cond)
  local loggedin = status(gateway)

  if loggedin and cond then
    -- provide status parameters, date and unit values in condition context
    local env = { status = loggedin, date = os.date("*t") }
    for u,v in pairs(interval_units) do env[u] = v end
    for u,v in pairs(traffic_units)  do env[u] = v end

    if not load_code(string.format("return (%s)", cond), env)() then
      print("Session exists, condition not met => not renewing.")
      return loggedin
    end
  end

  -- logout first to renew
  if loggedin then logout(gateway) end

  -- fetch chap id and challenge (converting octal escaped characters)
  local b,c = http.request(gateway .. "/login")
  if not b or c ~= 200 then
    return false, "Challenge fetching: " .. c
  end

  local function unescape_octal(escaped)
    if not escaped then return nil end
    return string.gsub(escaped, "\\([0-7]+)", function (o) return string.char(tonumber(o, 8)) end)
  end

  local chap_id = unescape_octal(string.match(b, 'name="chap%-id" value="([^"]+)"'))
  local chap_challenge = unescape_octal(string.match(b, 'name="chap%-challenge" value="([^"]+)"'))
  if not chap_id or not chap_challenge then
    return false, "Challenge fetching: no chap-id / chap-challenge"
  end

  -- submit login
  pw = md5.sumhexa(chap_id .. pw .. chap_challenge)
  print("Logging in " .. user .. " / " .. pw)
  local b,c = http.request(gateway .. "/login", string.format("username=%s&password=%s", user, pw))
  local error = string.match(b, 'name="error" value="([^"]+)"')

  if not b or c ~= 200 then
    return false, "Login: " .. c
  elseif error then
    return false, "Login (credentials invalid?): " .. error
  end

  return status(gateway) and true or false
end

function logout(gateway)
  print ("Logging out.")
  local b,c = http.request(gateway .. "/logout", "")
  return b and c == 200
end

function retry(retries, func, ...)
  local try = 0
  repeat
    if try > 0 then
      print(string.format("Retry %d / %d...", try, retries))
      socket.sleep(1)
    end
    local result, error = func(...)
    if result then
      return result
    elseif error then
      print("Error: " .. error)
    end
    try = try + 1
  until try > retries
end

-- getopt, POSIX style command line argument parser
-- from http://lua-users.org/wiki/AlternativeGetOpt
--
-- param arg contains the command line arguments in a standard table.
-- param options is a string with the letters that expect string values.
-- returns a table where associated keys are true, nil, or a string value.
-- The following example styles are supported
--   -a one  ==> opts["a"]=="one"
--   -bone   ==> opts["b"]=="one"
--   -c      ==> opts["c"]==true
--   --c=one ==> opts["c"]=="one"
--   -cdaone ==> opts["c"]==true opts["d"]==true opts["a"]=="one"
-- note POSIX demands the parser ends at the first non option
--      this behavior isn't implemented.
function getopt( arg, options )
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub( v, 1, 2) == "--" then
      local x = string.find( v, "=", 1, true )
      if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
      else      tab[ string.sub( v, 3 ) ] = true
      end
    elseif string.sub( v, 1, 1 ) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while ( y <= l ) do
        jopt = string.sub( v, y, y )
        if string.find( options, jopt, 1, true ) then
          if y < l then
            tab[ jopt ] = string.sub( v, y+1 )
            y = l
          else
            tab[ jopt ] = arg[ k + 1 ]
          end
        else
          tab[ jopt ] = true
        end
        y = y + 1
      end
    end
  end
  return tab
end

main()
