local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("d-multi", {
    t "FROM ",
    i(1, "golang"),
    t " as builder",
    t { "", "", "FROM alpine:" },
    i(2, "3.23.0"),
    t { "", "", "COPY --from=builder " },
    i(3, "/app"),
    t " ",
    i(4, "/app"),
  }),

  s("go-cache", {
    t "FROM golang:",
    i(1, "1.23-alpine"),
    t { " as builder", "", "WORKDIR " },
    i(2, "/app"),
    t { "", "", "COPY go.mod go.sum .", "" },
    t "RUN --mount=type=cache,target=/go/pkg/mod go mod download",
    t { "", "", "COPY . .", "", "ENV CGO_ENABLED=0", "" },
    t "RUN --mount=type=cache,target=/go/pkg/mod \\",
    t { "    --mount=type=cache,target=/root/.cache/go-build \\", "    go build -ldflags='-s -w' -o /app", "" },
    t "FROM alpine:",
    i(3, "3.23.0"),
    t { "", "", "COPY --from=builder " },
    i(4, "/app"),
    t " ",
    i(5, "/app"),
    t { "", "", 'ENTRYPOINT ["' },
    i(6, "/app"),
    t '"]',
  }),

  s("d-node", {
    t "FROM node:",
    i(1, "20-alpine"),
    t { "", "", "WORKDIR " },
    i(2, "/app"),
    t { "", "", "COPY package*.json .", "" },
    t "RUN npm ci",
    t { "", "", "COPY . .", "" },
    t "RUN npm run build",
    t { "", "", "FROM nginx:alpine", "", "COPY --from=0 " },
    i(3, "/app/dist"),
    t " ",
    i(4, "/usr/share/nginx/html"),
  }),

  s("d-python", {
    t "FROM python:",
    i(1, "3.12-slim"),
    t { "", "", "WORKDIR " },
    i(2, "/app"),
    t { "", "", "COPY requirements.txt .", "" },
    t "RUN pip install --no-cache-dir -r requirements.txt",
    t { "", "", "COPY . .", "", 'CMD ["python", "' },
    i(3, "main.py"),
    t '"]',
  }),
}
