#!/usr/bin/env lua
--[[
	MikroTik HotSpot Gateway (Captive Portal) CHAP login script
	Dependencies: lua, lua-md5, luasocket
--]]

md5 = require "md5"
socket = require "socket"
http = require "socket.http"

function usage()
  print("Usage: " .. arg[0] .. " login|logout|status <gateway-ip> [<username> <password>]")
  print()
  print("MikroTik HotSpot Gateway login script")
end

function status()
  local b,c = http.request(gateway .. "/status")
  assert(b, "Gateway error: " .. c)

  local status = {}
  status.user = string.match(b, "Welcome ([^!]+)!")

  if c == 200 and status.user then
    status.ip = string.match(b, "IP address:</td><td>([%d%.]+)")
    status.up_t, status.down_t = string.match(b, "bytes up/down:</td><td>([%w%. ]+) / ([%w%. ]+)")
    status.connected_t, status.left_t = string.match(b, "connected / left:</td><td>([%w ]+) / ([%w ]+)")

    print("User:      " .. status.user)
    print("IP:        " .. status.ip)
    print("Up/Down:   " .. status.up_t .. " / " .. status.down_t)
    print("Conn/Left: " .. status.connected_t .. " / " .. status.left_t)
    return status

  elseif string.find(b, "document.redirect.submit()", 1, true) then
    print("Not logged in (redirected to portal).")
    return false
  end

  error("Login state unknown (" .. c .. ").")
end

function login(user, pw)
  -- logout to renew
  if status() then
    logout()
  end

  -- fetch chap challenge (converting octal escaped characters)
  local b,c = http.request(gateway .. "/login")
  if not b or c ~= 200 then
    return false, "Challenge fetching: " .. c
  end

  b = string.gsub(b, "\\([0-7]+)", function (o) return string.char(tonumber(o, 8)) end)
  local chap_id = string.match(b, 'name="chap%-id" value="([^"]+)"')
  local chap_challenge = string.match(b, 'name="chap%-challenge" value="([^"]+)"')
  if not chap_id or not chap_challenge then
    return false, "Challenge fetching: no chap-id / chap-challenge"
  end

  -- submit login
  user = "1012_" .. user
  pw = md5.sumhexa(chap_id .. pw .. chap_challenge)
  print("Logging in " .. user .. " / " .. pw)
  local b,c = http.request(gateway .. "/login", string.format("username=%s&password=%s", user, pw))
  local error = string.match(b, 'name="error" value="([^"]+)"')

  if not b or c ~= 200 then
    return false, "Login: " .. c
  elseif error then
    return false, "Login (credentials invalid?): " .. error
  end

  return status()
end

function logout()
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

if #arg < 2 then
  usage()
  os.exit(1)
end

cmd = arg[1]
gateway = "http://" .. arg[2]

if cmd == "status" then
  local loggedin = status()
  os.exit(loggedin and 0 or 1)
elseif cmd == "login" then
  if #arg < 4 then
    print("Login: user or password parameter missing!")
    os.exit(1)
  end
  local loggedin = retry(3, login, arg[3], arg[4])
  os.exit(loggedin and 0 or 1)
elseif cmd == "logout" then
  logout()
else
  print("Unknown command: " .. cmd)
  usage()
  os.exit(1)
end
