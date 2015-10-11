#!/usr/bin/env lua
--[[
	MikroTik HotSpot Gateway (Captive Portal) CHAP login script
	Dependencies: lua, lua-md5, luasocket
--]]

md5 = require "md5"
http = require "socket.http"

function usage()
  print("Usage: " .. arg[0] .. " login|logout|status <gateway-ip> [<username> <password>]")
  print()
  print("MikroTik HotSpot Gateway login script")
end

function status()
  b,c = http.request(gateway .. "/status")
  if not b then
    print("Gateway error: " .. c)
    os.exit(1)
  end

  user = string.match(b, "Welcome ([^!]+)!")
  if c == 200 and user then
    print("User:      " .. user)
    print("IP:        " .. string.match(b, "IP address:</td><td>([%d%.]+)"))
    print("Up/Down:   " .. string.match(b, "bytes up/down:</td><td>([%w/%. ]+)"))
    print("Conn/Left: " .. string.match(b, "connected / left:</td><td>([%w/%. ]+)"))
    return true
  elseif string.find(b, "document.redirect.submit()", 1, true) then
    print("Not logged in (redirected to portal).")
    return false
  end

  print("Login state unknown (" .. c .. ").")
  os.exit(1)
end

function login(user, pw)
  -- logout to renew
  if status() then
    logout()
  end

  -- fetch chap challenge (converting octal escaped characters)
  b = http.request(gateway .. "/login")
  b = string.gsub(b, "\\([0-7]+)", function (o) return string.char(tonumber(o, 8)) end)
  chap_id = string.match(b, 'name="chap%-id" value="([^"]+)"')
  chap_challenge = string.match(b, 'name="chap%-challenge" value="([^"]+)"')

  -- submit login
  user = "1012_" .. user
  pw = md5.sumhexa(chap_id .. pw .. chap_challenge)
  print("Logging in " .. user .. " / " .. pw)
  http.request(gateway .. "/login", string.format("username=%s&password=%s", user, pw))
  return status()
end

function logout()
  print ("Logging out.")
  b,c = http.request(gateway .. "/logout", "")
  return b and c == 200
end

if #arg < 2 then
  usage()
  os.exit(1)
end

cmd = arg[1]
gateway = "http://" .. arg[2]

if cmd == "status" then
  loggedin = status()
  os.exit(loggedin and 0 or 1)
elseif cmd == "login" then
  if #arg < 4 then
    print("Login: user or password parameter missing!")
    os.exit(1)
  end
  loggedin = login(arg[3], arg[4])
  os.exit(loggedin and 0 or 1)
elseif cmd == "logout" then
  logout()
else
  print("Unknown command: " .. cmd)
  usage()
  os.exit(1)
end
