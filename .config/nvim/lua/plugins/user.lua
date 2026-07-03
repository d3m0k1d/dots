-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {

  {
    "xiyaowong/transparent.nvim",
    event = "VeryLazy",
    config = function()
      require("transparent").setup {
        groups = {
          "Normal",
          "NormalNC",
          "Comment",
          "Constant",
          "Special",
          "Identifier",
          "Statement",
          "PreProc",
          "Type",
          "Underlined",
          "Todo",
          "String",
          "Function",
          "Conditional",
          "Repeat",
          "Operator",
          "Structure",
          "LineNr",
          "NonText",
          "SignColumn",
          "CursorColumn",
          "CursorLine",
          "CursorLineNr",
          "StatusLine",
          "StatusLineNC",
          "EndOfBuffer",
          "TabLine",
          "TabLineFill",
          "TabLineSel",
          "BufferLine",
          "BufferLineFill",
          "BufferLineTab",
          "BufferLineTabClose",
          "BufferLineTabSelected",
          "BufferLineTabSeparator",
          "BufferLineTabSeparatorSelected",
        },
        extra_groups = {
          "NormalFloat",
          "NeoTreeNormal",
          "NeoTreeNormalNC",
          "Pmenu",
          "PmenuSel",
          "TelescopeNormal",
          "TelescopeBorder",
          "WhichKeyFloat",
          "DashboardHeader",
          "DashboardFooter",
          "HeirlineInActive",
          "HeirlineActive",
          "HeirlineTerm",
          "HeirlineFile",
          "HeirlineGit",
          "HeirlineDiagnostic",
          "HeirlineLSP",
          "HeirlineVC",
          "HeirlineMode",
          "HeirlineNav",
          "HeirlineMisc",
        },
        exclude_groups = {},
      }
      -- Для bufferline и аналогичных плагинов
      require("transparent").clear_prefix "BufferLine"
      require("transparent").clear_prefix "NeoTree"
    end,
  },
  {
    "Exafunction/windsurf.vim",
    event = "BufEnter",
    config = function()
      -- Принять текущее предложение
      vim.keymap.set("i", "<C-g>", function() return vim.fn["codeium#Accept"]() end, { expr = true, silent = true })
      -- Перейти к следующему предложению
      vim.keymap.set(
        "i",
        "<C-;>",
        function() return vim.fn["codeium#CycleCompletions"](1) end,
        { expr = true, silent = true }
      )
      -- Перейти к предыдущему предложению
      vim.keymap.set(
        "i",
        "<C-,>",
        function() return vim.fn["codeium#CycleCompletions"](-1) end,
        { expr = true, silent = true }
      )
      -- Очистить текущее предложение
      vim.keymap.set("i", "<C-x>", function() return vim.fn["codeium#Clear"]() end, { expr = true, silent = true })
    end,
  },
  -- == Examples of Adding Plugins ==
  "andweeb/presence.nvim",
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- == Examples of Overriding Plugins ==

  -- customize dashboard options
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            "███    ██ ██    ██ ██ ███    ███",
            "████   ██ ██    ██ ██ ████  ████",
            "██ ██  ██ ██    ██ ██ ██ ████ ██",
            "██  ██ ██  ██  ██  ██ ██  ██  ██",
            "██   ████   ████   ██ ██      ██",
          }, "\n"),
        },
      },
    },
  },

  -- You can disable default plugins as follows:
  { "max397574/better-escape.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts)
      require("luasnip.loaders.from_lua").load { paths = vim.fn.stdpath "config" .. "/lua/snippets" }

      -- Attach ansible snippets to yaml and yaml.ansible filetypes
      local ls = require "luasnip"
      local ok, ansible_snippets = pcall(require, "snippets.ansible")
      local compose_snippets = require "snippets.compose"
      local nginx_snippets = require "snippets.nginx"
      if ok then
        ls.add_snippets("yaml", ansible_snippets)
        ls.add_snippets("yaml.ansible", ansible_snippets)
        ls.add_snippets("yaml", compose_snippets)
        ls.add_snippets("conf", nginx_snippets)
      end
    end,
  },

  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },
}
