return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  cmd = "Neotree",
  dependencies = {
    "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons",
    { "s1n7ax/nvim-window-picker", opts = {} },
  },
  opts = function()
    local fuzzy = vim.deepcopy(require("neo-tree.defaults").filesystem.window.fuzzy_finder_mappings)
    fuzzy["<C-J>"], fuzzy["<C-K>"] = "move_cursor_down", "move_cursor_up"
    fuzzy[1].n = vim.tbl_extend("force", fuzzy[1].n, {
      n = "move_cursor_down", e = "move_cursor_up",
      j = { "e", raw = true }, k = { "n", raw = true },
    })
    local details = { i = "child_or_open", u = "show_file_details" }
    return {
      close_if_last_window = true,
      sources = { "filesystem", "buffers", "git_status" },
      source_selector = { winbar = true },
      commands = {
        parent_or_close = function(state)
          local node = state.tree:get_node()
          if not node then return end
          if node.type == "directory" and node:is_expanded() then
            state.commands.close_node(state)
          elseif node:get_parent_id() then
            require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
          end
        end,
        child_or_open = function(state)
          local node = state.tree:get_node()
          if not node then return end
          if node.type == "directory" and node:is_expanded() and node:has_children() then
            require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
          else
            state.commands.open(state)
          end
        end,
        find_in_dir = function(state)
          local node = state.tree:get_node()
          if not node then return end
          local directory = node.type == "directory" and node.path or vim.fs.dirname(node.path)
          require("telescope.builtin").find_files { cwd = directory }
        end,
      },
      window = { width = 30, mappings = {
        h = "parent_or_close", i = "child_or_open",
        n = function() vim.cmd.normal { "j", bang = true } end,
        e = function() vim.cmd.normal { "k", bang = true } end,
        j = "toggle_auto_expand_width",
        k = function() vim.cmd.normal { "n", bang = true } end,
        l = function() vim.cmd.normal { "u", bang = true } end,
        ["<Space>"] = { "toggle_node", nowait = false },
        w = "open_with_window_picker", S = "split_with_window_picker", v = "vsplit_with_window_picker",
        ["[b"] = "prev_source", ["]b"] = "next_source",
      } },
      filesystem = {
        filtered_items = { hide_dotfiles = false, hide_gitignored = false, never_show = { ".git" } },
        window = { mappings = vim.tbl_extend("force", details, { f = "find_in_dir" }), fuzzy_finder_mappings = fuzzy },
      },
      buffers = { window = { mappings = details } },
      git_status = { window = { mappings = details } },
    }
  end,
  keys = { { "<Leader>e", "<Cmd>Neotree toggle<CR>", desc = "File explorer" } },
}
