return {
  {
    "yorik1984/newpaper.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("newpaper").setup { style = "light" }
      vim.cmd.colorscheme "newpaper"
    end,
  },
  {
    "projekt0n/github-nvim-theme",
    lazy = true,
    config = function() require("github-theme").setup {} end,
  },
}
