hotspot.lua
===========

MikroTik HotSpot Gateway (Captive Portal) CHAP login script

See http://wiki.mikrotik.com/wiki/Manual:Hotspot\_Introduction

Dependencies
------------

* [lua](http://www.lua.org)
* [lua-md5](https://github.com/keplerproject/md5)
* [luasocket](http://w3.impa.br/~diego/software/luasocket/)

Usage
-----

    MikroTik HotSpot Gateway login script
    Usage: ./hotspot.lua login|logout|status [Options]

    Options:
      -g <gateway-ip>  IP-Address/Hostname of hotspot gateway (always required)
      -u <username>    Username for login
      -p <password>    Password for login
      -c <condition>   Condition when to renew an existing session

e.g. to log in:

    $ ./hotspot.lua login -g 10.10.1.254 -u 1012_XXX -p pw

as a cronjob (e.g. check status every 30 mins, renew at 7:30 or when remaining session time < 30 mins):

    0,30 * * * * /etc/hotspot.lua login -g 10.10.1.254 -u 1012_XXX -p pw -c "(date.hour == 7 and date.min == 30) or status.left < 30*m" 2>&1 | logger -t hotspot

or print the current status:

    $ ./hotspot.lua status -g 10.10.1.254
    User:      1012_XXX
    IP:        192.168.48.160
    Up/Down:   63.7 MiB / 892.8 MiB
    Conn/Left: 2h7m14s / 21h52m46s
