local M = {}

local function executable(name)
  local path = vim.fn.exepath(name)
  if path ~= "" then return path end
  local cached = vim.fn.stdpath("data") .. "/mason/bin/" .. name
  if vim.fn.executable(cached) == 1 then return cached end
end

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("PersonalLsp", { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if not client then return end
      if client.name == "ruff" then client.server_capabilities.hoverProvider = false end

      local function map(lhs, rhs, description)
        vim.keymap.set("n", lhs, rhs, { buffer = event.buf, desc = description })
      end
      map("K", "N", "Previous search match")
      if client:supports_method("textDocument/hover") then
        map("E", vim.lsp.buf.hover, "Hover symbol details")
      end
      map("gd", vim.lsp.buf.definition, "Definition")
      map("gD", vim.lsp.buf.declaration, "Declaration")
      map("gr", vim.lsp.buf.references, "References")
      map("gy", vim.lsp.buf.type_definition, "Type definition")
      map("<Leader>lr", vim.lsp.buf.rename, "Rename symbol")
      map("<Leader>la", vim.lsp.buf.code_action, "Code action")
      map("<Leader>lf", function()
        vim.lsp.buf.format {
          async = true,
          bufnr = event.buf,
          filter = function(provider)
            return vim.bo[event.buf].filetype ~= "python" or provider.name == "ruff"
          end,
        }
      end, "Format buffer")
    end,
  })

  local servers = {
    zuban = {
      cmd = { "zuban", "server" }, filetypes = { "python" },
      root_markers = { "pyproject.toml", "setup.cfg", ".git" },
    },
    ruff = {
      cmd = { "ruff", "server" }, filetypes = { "python" },
      root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
    },
    lua_ls = {
      cmd = { "lua-language-server" }, filetypes = { "lua" },
      root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
      settings = { Lua = {
        runtime = { version = "LuaJIT" }, diagnostics = { globals = { "vim" } },
        format = { enable = false },
        workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
        telemetry = { enable = false },
      } },
    },
    bashls = {
      cmd = { "bash-language-server", "start" }, filetypes = { "sh", "bash" }, root_markers = { ".git" },
    },
    clangd = {
      cmd = { "clangd" }, filetypes = { "c", "cpp", "objc", "objcpp" },
      root_markers = { "compile_commands.json", ".clangd", ".git" },
    },
    rust_analyzer = {
      cmd = { "rust-analyzer" }, filetypes = { "rust" }, root_markers = { "Cargo.toml", ".git" },
    },
    taplo = {
      cmd = { "taplo", "lsp", "stdio" }, filetypes = { "toml" },
      root_markers = { "taplo.toml", ".taplo.toml", ".git" },
    },
    marksman = {
      cmd = { "marksman", "server" }, filetypes = { "markdown", "markdown.mdx" },
      root_markers = { ".marksman.toml", ".git" },
    },
  }

  for name, server in pairs(servers) do
    local command = executable(server.cmd[1])
    server.capabilities = vim.lsp.protocol.make_client_capabilities()
    server.capabilities.textDocument.completion.completionItem.snippetSupport = true
    if command then server.cmd[1] = command end
    vim.lsp.config(name, server)
    if command then vim.lsp.enable(name) end
  end
end

return M
