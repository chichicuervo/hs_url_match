hs_url_match.lua
================

A simple url matcher for [Nginx-Lua](https://github.com/openresty/lua-nginx-module),
using [Intel's Hyperscan](https://01.org/hyperscan) (via
[luahs](https://github.com/starius/luahs)) for fast, bulk route matching, and
complies with [FastRoute](https://github.com/nikic/FastRoute) syntax.

Use this to build your own custom URL router.

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

path = "/hello/jason75/11/8/2016"

match = compiled:match(path)

--[[ Output Representation:
match = {
  ["path"] = "/hello/jason75/11/8/2016",
  ["matches"] = {
    [0] = "/hello/jason75/11/8/2016",
    [1] = "jason75",
    [2] = "11/8/2016",
    ["name"] = "jason75",
    ["today"] = "11/8/2016",
  },
  ["id"] = "1",
  ["pattern"] = "^/hello/(?P<name>[^/]+)/(?P<today>\d{1,2}/\d{1,2}/\d{2,4})(?:/\{lang: \(\?:en\|fr\|zh\))?",
}
--]]
```
