return function(install_missing)
  require("lazy").setup({ { import = "plugins" } }, {
    install = { missing = install_missing, colorscheme = { "habamax" } },
    checker = { enabled = false },
    change_detection = { notify = false },
    local_spec = false,
    rocks = { enabled = false },
    pkg = { enabled = false },
    ui = { backdrop = 100 },
  })
end
