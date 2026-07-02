local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("fn", {
    t("func "),
    i(1, "name"),
    t("("),
    i(2),
    t(") "),
    i(3),
    t({ " {", "\t" }),
    i(4),
    t({ "", "}" }),
  }),

  s("main", {
    t({ "func main() {", "\t" }),
    i(1),
    t({ "", "}" }),
  }),

  s("iferr", {
    t({ "if err != nil {", "\t" }),
    i(1, "return err"),
    t({ "", "}" }),
  }),

  s("for", {
    t("for "),
    i(1, "i := 0"),
    t("; "),
    i(2, "i < 10"),
    t("; "),
    i(3, "i++"),
    t({ " {", "\t" }),
    i(4),
    t({ "", "}" }),
  }),

  s("struct", {
    t("type "),
    i(1, "Name"),
    t({ " struct {", "\t" }),
    i(2),
    t({ "", "}" }),
  }),
}
