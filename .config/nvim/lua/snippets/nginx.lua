local ls = require "luasnip"
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("nginx-start", {
    t { "server{" },
    t { "", "    listen " },
    i(1, "80"),
    t { ";", "" },
    t { "    server_name " },
    i(2, "localhost.local"),
    t { ";", "", "    root " },
    i(3, "/var/www/html"),
    t { ";", "", "    location " },
    i(4, "/"),
    t { "{", "        try_files $uri $uri/index.html;", "    }", "" },
    t { "", "}" },
  }),
}
