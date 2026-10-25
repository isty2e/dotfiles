local mappings = {
  n = {
    n = { "gj", desc = "Down display line" },
    e = { "gk", desc = "Up display line" },
    j = { "e", desc = "Word end" },
    k = { "n", desc = "Next search match" },
    gj = { "j", desc = "Down logical line" },
    gk = { "k", desc = "Up logical line" },
    u = { "i", desc = "Insert" },
    l = { "u", desc = "Undo" },
    i = { "l", desc = "Right" },
    J = { "E", desc = "WORD end" },
    N = { "J", desc = "Join lines" },
    K = { "N", desc = "Previous search match" },
    E = { "K", desc = "Keyword lookup" },
    U = { "I", desc = "Insert at first nonblank" },
    ["<C-r>"] = { "U", desc = "Undo line" },
    L = { "<C-r>", desc = "Redo" },
    I = { "L", desc = "Bottom screen line" },
    ["<Leader>k"] = { ":tabe ", desc = "New tab" },
    ["<Leader>m"] = { "<Cmd>tabprevious<CR>", desc = "Previous tab" },
    ["<Leader>."] = { "<Cmd>tabnext<CR>", desc = "Next tab" },
  },
  x = {
    n = { "gj", desc = "Down display line" },
    e = { "gk", desc = "Up display line" },
    j = { "e", desc = "Word end" },
    k = { "n", desc = "Next search match" },
    gj = { "j", desc = "Down logical line" },
    gk = { "k", desc = "Up logical line" },
    u = { "i", desc = "Inner text object" },
    l = { "u", desc = "Lowercase" },
    i = { "l", desc = "Right" },
    J = { "E", desc = "WORD end" },
    N = { "J", desc = "Join lines" },
    K = { "N", desc = "Previous search match" },
    E = { "K", desc = "Keyword lookup" },
    U = { "I", desc = "Insert at block start" },
    L = { "U", desc = "Uppercase" },
    I = { "L", desc = "Bottom screen line" },
  },
  o = {
    n = { "j", desc = "Down logical line" },
    e = { "k", desc = "Up logical line" },
    j = { "e", desc = "Word end" },
    k = { "n", desc = "Next search match" },
    i = { "l", desc = "Right" },
    u = { "i", desc = "Inner text object" },
    l = { "<Esc>", desc = "Cancel operator" },
    J = { "E", desc = "WORD end" },
    N = { "<Esc>", desc = "Cancel operator" },
    K = { "N", desc = "Previous search match" },
    E = { "<Esc>", desc = "Cancel operator" },
    I = { "L", desc = "Bottom screen line" },
    U = { "<Esc>", desc = "Cancel operator" },
    L = { "<Esc>", desc = "Cancel operator" },
  },
}
local windows = {
  j = "<Nop>", n = "<C-w>j", k = "<C-w>n", e = "<C-w>k",
  i = "<C-w>l", l = "<C-w>i",
  J = "<Nop>", N = "<C-w>J", K = "<Nop>", E = "<C-w>K",
  I = "<C-w>L", L = "<C-w>I",
}
for _, mode in ipairs { "n", "x" } do
  for key, command in pairs(windows) do
    mappings[mode]["<C-w>" .. key] = { command, desc = "Window operation" }
    if key:match "^[a-z]$" then
      mappings[mode]["<C-w><C-" .. key .. ">"] = { command, desc = "Window operation" }
    end
  end
end

for mode, bindings in pairs(mappings) do
  for lhs, binding in pairs(bindings) do
    vim.keymap.set(mode, lhs, binding[1], { desc = binding.desc, silent = true })
  end
end
for lhs, rhs in pairs {
  ["<C-h>"] = "<C-w>h", ["<C-j>"] = "<C-w>j",
  ["<C-k>"] = "<C-w>k", ["<C-l>"] = "<C-w>l",
} do
  vim.keymap.set("n", lhs, rhs, { desc = "Window focus" })
  vim.keymap.set("t", lhs, "<C-\\><C-n>" .. rhs, { desc = "Window focus" })
end
