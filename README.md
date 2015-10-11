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

    ./hotspot.lua login|logout|status <gateway-ip> [<username> <password>]

* e.g. logging in:

        ./hotspot.lua login 10.10.1.254 user pw
