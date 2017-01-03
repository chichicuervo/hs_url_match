local hs_url_match = {
    _VERSION = 'hs_url_match v0.5.0',
    _DESCRIPTION = [[
    A simple url matcher for Nginx-Lua, using Intel's Hyperscan for fast, bulk
    route matching, and complies with FastRoute syntax. Use this to build your
    own custom URL router.
    ]],
    _LICENSE = [[
    MIT License

    Copyright (c) 2017 Jason E Belich

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    ]]
}

------------------------------- INSTANCE METHODS -------------------------------

local hs = require "luahs"

local HSUrlMatch = {}

local HSCompiled = {}

local function match_all(route, urlmatch)
    local matches = {}
    local hsdb = urlmatch._hsdb
    local parsed = urlmatch._regexes

    for i, match in ipairs(hsdb:scan(route, urlmatch._scratch) or {}) do
        matches[#matches + 1] = { path = route, pattern = parsed[match.id], id = match.id }
    end

    table.sort(matches, function (a,b)
        return a.id < b.id
    end)

    return matches
end

function HSCompiled.extract(route, regex)
    if ngx.re.match ~= nil then
        local cap, err = ngx.re.match(route, regex, "iujo")
        if cap and not err then
            return cap
        end
    else
        -- some other pcre should go here
    end
end

function HSUrlMatch.parse(t_routes, t_regexes)
    t_regexes = t_regexes and t_regexes or {}

    local db = hs.compile {
        expression = "\\{\\s*([a-zA-Z_][a-zA-Z0-9_-]*)\\s*(?::(?:[^{}]*|[^{}]*\\{[^{}]*\\})*\\s*)?\\}",
        flags = {
            hs.pattern_flags.HS_FLAG_CASELESS,
            hs.pattern_flags.HS_FLAG_UTF8,
            hs.pattern_flags.HS_FLAG_UCP,
            hs.pattern_flags.HS_FLAG_SOM_LEFTMOST
        },
        mode = hs.compile_mode.HS_MODE_BLOCK
    }

    local db_scratch = db:makeScratch()
    for i, route in ipairs(t_routes) do
        local matches = db:scan(route, db_scratch)

        table.sort(matches, function (a,b)
            return (a.from < b.from) or ( a.from == b.from and  (a.to - a.from > b.to - b.from))
        end)

        local regexes = {"^"}
        local cur = 0
        for ii, match in ipairs(matches) do
            regexes[#regexes + 1] = route:sub(cur, match.from)
                :gsub("([%.%^%$%*%-%?%(%)%{%}\\|])","\\%1")
                :gsub("%[", "(?:")
                :gsub("%]", ")?")

            if match.to > cur then
                cur = match.to + 1

                local field, f_regex = string.match (
                    route:sub(match.from + 1, match.to),
                    "{%s*([^:]+)%s*:?%s*(.*)%s*}" )
                regexes[#regexes + 1] = "(?P<" .. field .. ">" ..
                    (f_regex and type(f_regex) == "string" and f_regex:len() > 0
                    and f_regex:gsub("%s+$", "") or "[^/]+") .. ")"
            end
        end

        regexes[#regexes + 1] = route:sub(cur)
            :gsub("([%.%^%%$*%-%?%(%)%{%}\\|])","\\%1")
            :gsub("%[", "(?:")
            :gsub("%]", ")?")
--            :gsub("([^\\$])$","%1$")
            :gsub("\\$$","$")

        t_regexes[#t_regexes + 1] = table.concat(regexes)
    end

    return t_regexes
end

function HSCompiled:match_all(route)
    return match_all(route, self)
end

function HSCompiled:match(route)
    local matches = self:match_all(route)
    local parsed = self._regexes

    for i, match in ipairs(matches) do
        local cap = self.extract(route, parsed[match.id])
        if cap then
            match.matches = cap
            return match
        end
    end

    return nil
end

function HSUrlMatch:compile(t_regexes)
    local flags = {
        hs.pattern_flags.HS_FLAG_CASELESS,
        hs.pattern_flags.HS_FLAG_UTF8,
        hs.pattern_flags.HS_FLAG_UCP,
    }

    local expressions = {}

    for i, regex in ipairs(t_regexes) do
        expressions[#expressions + 1] = {
            expression = regex,
            flags = flags,
            id = #expressions + 1
        }
    end

    local db = hs.compile {
        expressions = expressions,
        mode = hs.compile_mode.HS_MODE_BLOCK
    }

    return setmetatable({
        _hsdb = db,
        _scratch = db:makeScratch(),
        _regexes = t_regexes
    }, {
        __index = HSCompiled
    })
end

local hs_url_match_mt = {
    __index = HSUrlMatch
}

------------------------------- PUBLIC INTERFACE -------------------------------

hs_url_match.new = function ()
    return setmetatable({}, hs_url_match_mt)
end

return hs_url_match
