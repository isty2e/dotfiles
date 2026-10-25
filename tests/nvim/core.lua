local source = assert(vim.env.KEYMAP_TEST_CONFIG, "Select the configuration root explicitly")
vim.env.LAZY = nil
vim.opt.rtp:prepend(source)
dofile(source .. "/init.lua")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one two", "second", "third" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("j", "xt", false)
assert(vim.fn.col "." == 3, "core word movement requires no plugin")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("dn", "xt", false)
assert(vim.deep_equal({ "third" }, vim.api.nvim_buf_get_lines(0, 0, -1, false)), "native logical operator failed")
print "PASS: core editing without lazy.nvim or plugins"
vim.cmd "qa!"
