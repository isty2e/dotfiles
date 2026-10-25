local script = assert(vim.env.KEYMAP_TEST_SCRIPT)
local stderr = {}
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE" }, {
  rpc = true,
  on_stderr = function(_, lines)
    for _, line in ipairs(lines) do if line ~= "" then stderr[#stderr + 1] = line end end
  end,
})
assert(child > 0, "native test child did not start")

local function remote(code, ...)
  return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
end

local function input(keys) vim.rpcrequest(child, "nvim_input", keys) end

local function wait_for(code, message)
  if not vim.wait(2000, function() return remote(code) end, 10) then
    error(message .. ": " .. vim.inspect(remote([[
      return { mode = vim.api.nvim_get_mode().mode, lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
    ]])))
  end
end

local result
local ok, problem = pcall(function()
  result = remote("return dofile(...)", script)
  assert(#result.failures == 0, table.concat(result.failures, "\n"))

  local completion_buffer = remote([[
    local path = vim.env.KEYMAP_TEST_FILES .. "/completion.txt"
    vim.fn.writefile({}, path)
    vim.cmd.tabnew { path }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alphabet", "" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    require("cmp").setup.buffer { sources = { { name = "buffer" } } }
    return vim.api.nvim_get_current_buf()
  ]])
  input("ualp")
  wait_for([[
    return vim.api.nvim_get_mode().mode == "i" and vim.api.nvim_get_current_line() == "alp"
  ]], "native insert input did not arrive")
  remote([[require("cmp").complete()]])
  wait_for([[return require("cmp").visible()]], "completion did not open")
  input("<C-j>")
  wait_for([[
    local entry = require("cmp").get_selected_entry()
    return entry and entry:get_word() == "alphabet"
  ]], "next completion was not selected")
  wait_for(([[
    return vim.api.nvim_get_current_buf() == %d and vim.api.nvim_get_mode().mode == 'i'
  ]]):format(completion_buffer), "completion lost the editor buffer")
  input("<CR>")
  wait_for([[return vim.api.nvim_get_current_line() == "alphabet"]], "completion was not committed")
  input("<Esc>")
  wait_for([[return vim.api.nvim_get_mode().mode == "n"]], "completion did not return to Normal mode")
  result.passed = result.passed + 1
end)

pcall(vim.rpcrequest, child, "nvim_command", "qa!")
vim.fn.jobwait({ child }, 2000)
vim.fn.jobstop(child)

if not ok then
  print("FAIL: " .. tostring(problem))
  for _, line in ipairs(stderr) do print(line) end
  vim.cmd "cquit"
end
for _, failure in ipairs(result.failures) do print("FAIL: " .. failure) end
print(("RESULT: %d passed, %d failed"):format(result.passed, #result.failures))
if #result.failures > 0 then vim.cmd "cquit" end
vim.fn.writefile({ tostring(result.passed) }, assert(vim.env.KEYMAP_TEST_RESULT))
vim.cmd "qa!"
