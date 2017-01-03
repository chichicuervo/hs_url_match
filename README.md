hs_url_match.lua
================

A simple url matcher for Nginx-Lua, using Intel's Hyperscan for fast, bulk
route matching, and complies with FastRoute syntax. Use this to build your
own custom URL router.

Basic Usage
===========

``` lua
local hum = require "hs_url_match"
local obj = hum.new()

routes = {
    "/hello/{name}/{today: \\d{1,2}/\\d{1,2}/\\d{2,4}}[/{lang: (?:en|fr|zh)]",
    "/hello/user-{user: \d+}[/]$'
}

regexes = obj.parse(routes, {})
compiled = obj:compile(regexes)

path = "/hello/steven62/12/1/2016"

match = compiled:match(path)

--[[ Output Representation:
match = {
  ["path"] = "/hello/steven62/12/1/2016",
  ["matches"] = { 
    [0] = "/hello/steven62/12/1/2016",
    [1] = "steven62",
    [2] = "12/1/2016",
    ["name"] = "steven62",
    ["today"] = "12/1/2016",
  },
  ["id"] = "1",
  ["pattern"] = "^/hello/(?P<name>[^/]+)/(?P<today>\d{1,2}/\d{1,2}/\d{2,4})(?:/\{lang: \(\?:en\|fr\|zh\))?",
}
--]]
```
