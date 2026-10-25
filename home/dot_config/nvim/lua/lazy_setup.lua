require("lazy").setup({ { import = "plugins" } }, {
  install = { missing = false, colorscheme = { "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  local_spec = false,
  rocks = { enabled = false },
  pkg = { enabled = false },
  ui = { backdrop = 100 },
})
