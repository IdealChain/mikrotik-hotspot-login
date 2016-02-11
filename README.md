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

    $ ./hotspot.lua login|logout|status <gateway-ip> [<username> <password>]

e.g. to log in:

    $ ./hotspot.lua login 10.10.1.254 user pw

as a cronjob (0:00, 8:00 and 16:00):

    0 */8 * * * /etc/hotspot.lua login 10.10.1.254 user pw 2>&1 | logger -t hotspot

or print the current status:

    $ ./hotspot.lua status 10.10.1.254
    User:      1012_XXX
    IP:        192.168.48.160
    Up/Down:   63.7 MiB / 892.8 MiB
    Conn/Left: 2h7m14s / 21h52m46s
