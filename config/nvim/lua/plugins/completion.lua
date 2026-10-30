return {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path" },
  opts = function()
    local cmp = require "cmp"
    return {
      enabled = function() return vim.bo.buftype ~= "prompt" end,
      preselect = cmp.PreselectMode.None,
      snippet = { expand = function(args) vim.snippet.expand(args.body) end },
      mapping = {
        ["<C-n>"] = cmp.mapping(function()
          if cmp.visible() then cmp.select_next_item() else cmp.complete() end
        end, { "i", "c" }),
        ["<C-p>"] = cmp.mapping(function()
          if cmp.visible() then cmp.select_prev_item() else cmp.complete() end
        end, { "i", "c" }),
        ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
        ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
        ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
        ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
        ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
        ["<C-e>"] = cmp.mapping(cmp.mapping.abort(), { "i", "c" }),
        ["<C-y>"] = cmp.config.disable,
        ["<CR>"] = cmp.mapping(cmp.mapping.confirm { select = false }, { "i", "c" }),
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then cmp.select_next_item()
          elseif vim.snippet.active { direction = 1 } then vim.snippet.jump(1)
          else fallback() end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then cmp.select_prev_item()
          elseif vim.snippet.active { direction = -1 } then vim.snippet.jump(-1)
          else fallback() end
        end, { "i", "s" }),
      },
      sources = cmp.config.sources { { name = "nvim_lsp" }, { name = "path" }, { name = "buffer" } },
    }
  end,
}
