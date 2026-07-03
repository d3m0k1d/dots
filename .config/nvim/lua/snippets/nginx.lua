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
    t { "    server_tokens off;" },
    t { "", "}" },
  }),
  s("nginx-tls", {
    t { "listen 443 ssl;" },
    t { "", "ssl_certificate /etc/ssl/cert.pem;" },
    t { "", "ssl_certificate_key /etc/ssl/key.pem;" },
    t { "", "ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;" },
    t { "", "ssl_ciphers HIGH:!aNULL:!MD5:!3DES;" },
  }),
  s("nginx-cache", {
    t { "location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {", "" },
    t { "    expires 30d;", "", "    add_header Cache-Control public, immutable;", "", "    access_log off;", "", "}" },
  }),
}
