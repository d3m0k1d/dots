#if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- AstroUI provides the basis for configuring the AstroNvim User Interface
-- Configuration documentation can be found with `:h astroui`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    -- change colorscheme
    colorscheme = "astrodark",
    
    -- AstroUI allows you to easily modify highlight groups easily for any and all colorschemes
    highlights = {
      init = { -- this table overrides highlights in all themes
        StatusLine = { bg = "NONE" },
        StatusLineNC = { bg = "NONE" },
        TabLine = { bg = "NONE" },
        TabLineFill = { bg = "NONE" },
        TabLineSel = { bg = "NONE" },
        BufferLine = { bg = "NONE" },
        BufferLineFill = { bg = "NONE" },
        HeirlineActive = { bg = "NONE" },
        HeirlineInactive = { bg = "NONE" },
        NeoTreeGitAdded = { bg = "NONE" },
        NeoTreeGitModified = { bg = "NONE" },
        NeoTreeGitDeleted = { bg = "NONE" },
        BufferLineGitAdded = { bg = "NONE" },
        BufferLineGitModified = { bg = "NONE" },
        BufferLineGitDeleted = { bg = "NONE" },
        HeirlineGit = { bg = "NONE" },
      },
      astrodark = { -- a table of overrides/changes when applying the astrotheme theme
        -- Normal = { bg = "#000000" },
      },
    },
    -- Icons can be configured throughout the interface
    icons = {
      -- configure the loading of the lsp in the status line
      LSPLoading1 = "⠋",
      LSPLoading2 = "⠙",
      LSPLoading3 = "⠹",
      LSPLoading4 = "⠸",
      LSPLoading5 = "⠼",
      LSPLoading6 = "⠴",
      LSPLoading7 = "⠦",
      LSPLoading8 = "⠧",
      LSPLoading9 = "⠇",
      LSPLoading10 = "⠏",
    },
  },
}
