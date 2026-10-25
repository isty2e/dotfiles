local source = assert(vim.env.KEYMAP_TEST_CONFIG, "Select the configuration root explicitly")
local plugins = assert(vim.env.KEYMAP_TEST_PLUGINS, "Pass an existing plugin cache; installation is never performed")
vim.o.loadplugins = true
vim.env.LAZY = plugins .. "/lazy.nvim"
vim.opt.rtp:prepend(source)
vim.opt.rtp:prepend(vim.env.LAZY)
local lazy = require "lazy"
local setup = lazy.setup
lazy.setup = function(spec, opts)
  opts.root = plugins
  opts.readme = { enabled = false }
  return setup(spec, opts)
end
dofile(source .. "/init.lua")
vim.api.nvim_exec_autocmds("VimEnter", {})
vim.cmd.cd(assert(vim.env.KEYMAP_TEST_FILES))

local failures, passed = {}, 0
local function check(name, action)
  print("CHECK: " .. name)
  local ok, err = pcall(action)
  if ok then passed = passed + 1 else table.insert(failures, name .. ": " .. tostring(err)) end
end
local function equal(expected, actual)
  assert(vim.deep_equal(expected, actual), "expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end
local function keys(input)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(input, true, false, true), "xt", false)
end
local buffer_number = 0
local function buffer(lines)
  keys "<Esc>"
  for _, window in ipairs(vim.api.nvim_list_wins()) do
    local candidate = vim.api.nvim_win_get_buf(window)
    if vim.api.nvim_win_get_config(window).relative == "" and vim.bo[candidate].buftype == "" then
      vim.api.nvim_set_current_win(window)
      break
    end
  end
  buffer_number = buffer_number + 1
  local path = assert(vim.env.KEYMAP_TEST_FILES) .. "/nvim-case-" .. buffer_number .. ".txt"
  vim.fn.writefile({}, path)
  vim.cmd.edit { path, bang = true }
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.o.columns, vim.o.lines = 40, 20
  vim.wo.wrap, vim.wo.number, vim.wo.relativenumber, vim.wo.signcolumn = true, false, false, "no"
end

check("word end", function()
  buffer { "one two three" }; keys "j<Esc>"; equal(2, vim.fn.col "." - 1)
end)
check("counted display and logical movement", function()
  buffer { string.rep("x", 180), "second", "third" }
  keys "2n"; equal(1, vim.fn.line "."); assert(vim.fn.col "." > 40)
  keys "gj"; equal(2, vim.fn.line ".")
end)
check("logical operator and native dd", function()
  buffer { "first", "second", "third" }; keys "dn"
  equal({ "third" }, vim.api.nvim_buf_get_lines(0, 0, -1, false)); equal("V", vim.fn.getregtype '"')
  buffer { "first", "second" }; keys "dd"; equal("second", vim.api.nvim_get_current_line())
end)
check("native object selector after inner prefix", function()
  buffer { "one two" }; keys "duw"; equal(" two", vim.api.nvim_get_current_line())
end)
check("visual case roles", function()
  buffer { "ABC" }; keys "vuwl"; equal("abc", vim.api.nvim_get_current_line())
  keys "vuwL"; equal("ABC", vim.api.nvim_get_current_line())
end)
check("literal find, mark and register", function()
  buffer { "abncd" }; keys "fn"; equal(3, vim.fn.col ".")
  keys "me"; keys "i"; keys "`e"; equal(3, vim.fn.col ".")
  keys '"nyy'; equal("abncd\n", vim.fn.getreg "n")
end)
check("insert and Select input", function()
  buffer { "tail" }; keys "unueijk<Esc>"; equal("nueijktail", vim.api.nvim_get_current_line())
  buffer { "ABC" }; keys "ghn<Esc>"; equal("nBC", vim.api.nvim_get_current_line())
end)
check("replace and insert-register arguments stay literal", function()
  buffer { "ABC" }; keys "ri"; equal("iBC", vim.api.nvim_get_current_line())
  buffer { "tail" }; vim.fn.setreg("n", "VALUE"); keys "u<C-r>n<Esc>"
  equal("VALUEtail", vim.api.nvim_get_current_line())
end)
check("undo redo", function()
  buffer { "one" }; keys "uX<Esc>"; keys "l"; equal("one", vim.api.nvim_get_current_line())
  keys "L"; equal("Xone", vim.api.nvim_get_current_line())
end)
check("join and search cycles", function()
  buffer { "one", "two", "one" }; vim.fn.setreg("/", "one")
  keys "k"; equal(3, vim.fn.line "."); keys "K"; equal(1, vim.fn.line ".")
  keys "N"; equal("one two", vim.api.nvim_get_current_line())
end)
check("keyword lookup displacement", function()
  buffer { "needle" }
  local received
  vim.api.nvim_create_user_command("KeymapLookup", function(args) received = args.args end, { nargs = 1 })
  vim.bo.keywordprg = ":KeymapLookup"
  keys "E"; equal("needle", received)
end)
check("vacant operator cancels", function()
  buffer { "first", "second" }; keys "dL"; keys "x"
  equal({ "irst", "second" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
end)
check("windows and displaced split", function()
  buffer { "first", "second" }; vim.cmd "vsplit"; vim.cmd "wincmd h"
  keys "<C-w>i"; equal(2, vim.fn.winnr())
  local count = vim.fn.winnr "$"; keys "<C-w>k"; equal(count + 1, vim.fn.winnr "$" )
  vim.cmd "only!"
end)

lazy.load { plugins = { "neo-tree.nvim", "telescope.nvim" } }
check("neo-tree native movement and file-details displacement", function()
  vim.cmd("Neotree filesystem dir=" .. vim.fn.fnameescape(assert(vim.env.KEYMAP_TEST_FILES)))
  vim.wait(1000, function() return vim.bo.filetype == "neo-tree" end)
  assert(vim.bo.filetype == "neo-tree", "tree buffer did not open")
  assert(vim.wait(2000, function()
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("alpha.txt", 1, true) ~= nil
  end), "tree entries did not load")
  vim.fn.search("alpha.txt", "w")
  local start = vim.fn.line "."; keys "n"; equal(start + 1, vim.fn.line ".")
  keys "e"; equal(start, vim.fn.line ".")
  keys "u"
  assert(vim.api.nvim_win_get_config(0).relative ~= "", "details did not open a floating window")
  assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("alpha.txt", 1, true))
  keys "<Esc>"
  keys "i"; equal("alpha.txt", vim.fn.expand "%:t")
end)
check("neo-tree fuzzy normal navigation and literal input", function()
  vim.cmd "Neotree focus filesystem"
  vim.fn.search("alpha.txt", "w")
  keys "/"
  assert(vim.wait(1500, function() return vim.bo.filetype == "neo-tree-popup" end), "filter did not open")
  vim.cmd.stopinsert()
  local state = require("neo-tree.sources.manager").get_state("filesystem")
  local before = state.tree:get_node():get_id()
  keys "n"; assert(state.tree:get_node():get_id() ~= before, "filter next did not move")
  keys "e"; equal(before, state.tree:get_node():get_id())
  keys "unueikXj"; assert(vim.api.nvim_get_current_line():find("nueikXj", 1, true), "filter text was transposed")
  keys "<Esc>"
end)
for _, name in ipairs { "buffers", "git_status" } do
  check("neo-tree " .. name .. " source-local detail and open", function()
    vim.cmd "Neotree close"
    vim.cmd("Neotree focus " .. name .. " dir=" .. vim.fn.fnameescape(vim.env.KEYMAP_TEST_FILES))
    local ready = vim.wait(2000, function()
      return vim.bo.filetype == "neo-tree"
        and table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("alpha.txt", 1, true) ~= nil
    end)
    if not ready then
      local state = require("neo-tree.sources.manager").get_state(name)
      local windows = {}
      for _, window in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(window)
        windows[#windows + 1] = { window, vim.bo[b].filetype, vim.api.nvim_buf_get_name(b) }
      end
      error(vim.inspect { source = name, path = state.path, loading = state.loading, winid = state.winid, windows = windows })
    end
    vim.fn.search("alpha.txt", "w")
    keys "u"
    assert(vim.api.nvim_win_get_config(0).relative ~= "", "details did not open")
    assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("alpha.txt", 1, true))
    keys "<Esc>"; keys "i"; equal("alpha.txt", vim.fn.expand "%:t")
  end)
end
check("Telescope selection and literal prompt input", function()
  local pickers, finders = require "telescope.pickers", require "telescope.finders"
  local conf = require("telescope.config").values
  pickers.new({ initial_mode = "normal" }, {
    finder = finders.new_table { results = { "alpha", "beta", "gamma" } },
    sorter = conf.generic_sorter {},
  }):find()
  vim.wait(500, function() return vim.bo.filetype == "TelescopePrompt" end)
  vim.wait(1000, function()
    local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
    return picker.manager and picker.manager:num_results() == 3
  end)
  local prompt = vim.api.nvim_get_current_buf()
  keys "n"; equal("beta", require("telescope.actions.state").get_selected_entry()[1])
  keys "e"; equal("alpha", require("telescope.actions.state").get_selected_entry()[1])
  keys "I"; equal("gamma", require("telescope.actions.state").get_selected_entry()[1])
  keys "unueikXj"; assert(vim.api.nvim_get_current_line():find("nueikXj", 1, true), "prompt text was transposed")
  require("telescope.actions").close(prompt)
end)

check("native LSP attach preserves hover and previous search", function()
  buffer { "needle", "other", "needle" }
  local hovered, closing, request_id = false, false, 0
  local id = vim.lsp.start {
    name = "keymap-fixture",
    root_dir = vim.env.KEYMAP_TEST_FILES,
    cmd = function(dispatchers)
      return {
        request = function(method, _, callback)
          request_id = request_id + 1
          local result
          if method == "initialize" then
            result = { capabilities = { hoverProvider = true, textDocumentSync = 1 } }
          elseif method == "textDocument/hover" then
            hovered = true
            result = { contents = { kind = "plaintext", value = "fixture hover" } }
          end
          vim.schedule(function() callback(nil, result, request_id) end)
          return true, request_id
        end,
        notify = function(method)
          if method == "exit" then closing = true; dispatchers.on_exit(0, 0) end
          return true
        end,
        is_closing = function() return closing end,
        terminate = function() closing = true; dispatchers.on_exit(0, 0) end,
      }
    end,
  }
  assert(id and vim.wait(1500, function()
    local client = vim.lsp.get_client_by_id(id)
    return client and client.initialized and vim.lsp.buf_is_attached(0, id)
  end), "native client did not attach")
  keys "E"; assert(vim.wait(1000, function() return hovered end), "hover request was not sent")
  vim.fn.setreg("/", "needle"); vim.api.nvim_win_set_cursor(0, { 3, 0 })
  keys "K"; equal(1, vim.fn.line ".")
  vim.lsp.stop_client(id, true)
end)

check("Light themes, comments and native statusline", function()
  for _, theme in ipairs { "github_light", "github_light_high_contrast", "newpaper" } do
    vim.cmd.colorscheme(theme)
    equal(theme, vim.g.colors_name)
  end
  buffer { "local answer = 42" }; vim.bo.filetype = "lua"
  keys " /"; assert(vim.api.nvim_get_current_line():find("--", 1, true))
  keys " /"; equal("local answer = 42", vim.api.nvim_get_current_line())
  local status = vim.api.nvim_eval_statusline(vim.o.statusline, { winid = 0, maxwidth = 200 })
  assert(status.str:find("nvim-case-", 1, true), "statusline did not render the buffer")
end)

check("local Git changes attach and expose a hunk preview", function()
  vim.cmd.edit { vim.env.KEYMAP_TEST_FILES .. "/alpha.txt", bang = true }
  assert(vim.wait(2000, function()
    local hunks = require("gitsigns").get_hunks()
    return hunks and #hunks > 0
  end), "Git changes did not attach")

  keys "<Leader>gp"
  assert(vim.wait(1000, function()
    for _, window in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(window).relative ~= "" then
        local content = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false)
        if table.concat(content, "\n"):find("changed", 1, true) then return true end
      end
    end
    return false
  end), "Git hunk preview did not contain the working-tree change")
  keys "<Esc>"
end)

check("LSP snippet expansion uses the native engine", function()
  buffer { "" }
  require("cmp").get_config().snippet.expand { body = "call(${1:argument})$0" }
  equal("call(argument)", vim.api.nvim_get_current_line())
  vim.snippet.stop()
  keys "<Esc>"
end)

check("missing parser leaves editing available and language indentation stays local", function()
  buffer { "tail" }; vim.bo.filetype = "keymap_fixture_without_parser"
  keys "uX<Esc>"; equal("Xtail", vim.api.nvim_get_current_line())
  vim.bo.filetype = "python"; equal(4, vim.bo.shiftwidth)
  buffer { "plain text" }; equal(2, vim.bo.shiftwidth)
end)

return { passed = passed, failures = failures }
