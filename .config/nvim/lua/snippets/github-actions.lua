local ls = require "luasnip"
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("gha-start", {
    t { "name: " },
    i(1, "ci"),
    t { "" },
    t { "", "on: " },
    t { "", "  push: " },
    t { "", "  pull_request: " },
    t { "", "    branches: " },
    i(2, "master"),
    t { "", "", "jobs: ", "    " },
    i { 3, "build" },
    t { "", "      runs-on: ubuntu-latest" },
  }),
}

