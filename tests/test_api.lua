local new_set, eq = MiniTest.new_set, MiniTest.expect.equality
local h = dofile "tests/helpers.lua"

local T, child = h.child_vault {
  pre_case = [[M = require"obsidian.api"]],
}

T["toggle_checkbox"] = new_set()

T["toggle_checkbox"]["should toggle between default states with - lists"] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { "- [ ] dummy" })
  eq("- [ ] dummy", child.api.nvim_get_current_line())
  child.lua [[M.toggle_checkbox()]]
  eq("- [x] dummy", child.api.nvim_get_current_line())
end

T["toggle_checkbox"]["should toggle between default states with * lists"] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { "* [ ] dummy" })
  child.lua [[M.toggle_checkbox()]]
  eq("* [x] dummy", child.api.nvim_get_current_line())
  child.lua [[M.toggle_checkbox()]]
  eq("* [ ] dummy", child.api.nvim_get_current_line())
end

T["toggle_checkbox"]["should toggle between default states with numbered lists with ."] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { "1. [ ] dummy" })
  child.lua [[M.toggle_checkbox()]]
  eq("1. [x] dummy", child.api.nvim_get_current_line())
  child.lua [[M.toggle_checkbox()]]
  eq("1. [ ] dummy", child.api.nvim_get_current_line())
end

T["toggle_checkbox"]["should toggle between default states with numbered lists with )"] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { "1) [ ] dummy" })
  child.lua [[M.toggle_checkbox()]]
  eq("1) [x] dummy", child.api.nvim_get_current_line())
  child.lua [[M.toggle_checkbox()]]
  eq("1) [ ] dummy", child.api.nvim_get_current_line())
end

T["toggle_checkbox"]["should use custom states if provided"] = function()
  local custom_states = { " ", "!", "x" }
  local toggle_expr = string.format([[M.toggle_checkbox(%s)]], vim.inspect(custom_states))
  child.api.nvim_buf_set_lines(0, 0, -1, false, { "- [ ] dummy" })
  child.lua(toggle_expr)
  eq("- [!] dummy", child.api.nvim_get_current_line())
  child.lua(toggle_expr)
  eq("- [x] dummy", child.api.nvim_get_current_line())
  child.lua(toggle_expr)
  eq("- [ ] dummy", child.api.nvim_get_current_line())
  child.lua(toggle_expr)
  eq("- [!] dummy", child.api.nvim_get_current_line())
end

T["cursor_link"] = function()
  --                                               0    5    10   15   20   25   30   35   40    45  50   55
  --                                               |    |    |    |    |    |    |    |    |    |    |    |
  child.api.nvim_buf_set_lines(0, 0, -1, false, { "The [other](link/file.md) plus [[another/file.md|yet]] there" })

  local link1 = "[other](link/file.md)"
  local link2 = "[[another/file.md|yet]]"

  local tests = {
    { cur_col = 4, link = link1, t = "Markdown" },
    { cur_col = 6, link = link1, t = "Markdown" },
    { cur_col = 24, link = link1, t = "Markdown" },
    { cur_col = 31, link = link2, t = "WikiWithAlias" },
    { cur_col = 39, link = link2, t = "WikiWithAlias" },
    { cur_col = 53, link = link2, t = "WikiWithAlias" },
  }
  for _, test in ipairs(tests) do
    child.api.nvim_win_set_cursor(0, { 1, test.cur_col })
    local link, t = unpack(child.lua_get [[{ M.cursor_link() }]])
    eq(test.link, link)
    eq(test.t, t)
  end
end

T["cursor_tag"] = function()
  --                                               0    5    10   15   20   25
  --                                               |    |    |    |    |    |
  child.api.nvim_buf_set_lines(0, 0, -1, false, { "- [ ] Do the dishes #TODO " })

  local tests = {
    { cur_col = 0, res = vim.NIL },
    { cur_col = 19, res = vim.NIL },
    { cur_col = 20, res = "TODO" },
    { cur_col = 24, res = "TODO" },
    { cur_col = 25, res = vim.NIL },
  }

  for _, test in ipairs(tests) do
    child.api.nvim_win_set_cursor(0, { 1, test.cur_col })
    local tag = child.lua [[return M.cursor_tag()]]
    eq(test.res, tag)
  end
end

T["cursor_heading"] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, false, { "# Hello", "world" })
  child.api.nvim_win_set_cursor(0, { 1, 0 })
  eq("Hello", child.lua([[return M.cursor_heading()]]).header)
  eq("#hello", child.lua([[return M.cursor_heading()]]).anchor)
  eq(1, child.lua([[return M.cursor_heading()]]).level)
  child.api.nvim_win_set_cursor(0, { 2, 0 })
  eq(vim.NIL, child.lua [[return M.cursor_heading()]])
end

T["open_note"] = new_set()

T["open_note"]["should not change buffer in current window when opening in float"] = function()
  -- initial windows
  local initial_wins = child.api.nvim_list_wins()
  eq(1, #initial_wins)
  local orig_win_id = initial_wins[1]

  -- Get current buffer
  local orig_bufnr = child.api.nvim_win_get_buf(orig_win_id)

  -- Create a dummy file in the vault
  local note_path = child.Obsidian.dir / "my-new-note.md"
  h.write("hello world", note_path)

  -- Open note in floating window
  child.lua(string.format([[M.open_note("%s", "float")]], tostring(note_path)))

  -- Check that buffer in original window hasn't changed
  local new_bufnr_in_orig_win = child.api.nvim_win_get_buf(orig_win_id)
  eq(orig_bufnr, new_bufnr_in_orig_win)

  -- Check that a new window was opened
  local final_wins = child.api.nvim_list_wins()
  eq(2, #final_wins)

  -- And that the new window is a float
  local new_win_id
  for _, win_id in ipairs(final_wins) do
    if win_id ~= orig_win_id then
      new_win_id = win_id
      break
    end
  end

  local win_config = child.api.nvim_win_get_config(new_win_id)
  eq("editor", win_config.relative)
end

T["open_note"]["should focus existing float window instead of creating a new one"] = function()
  local orig_win_id = child.api.nvim_get_current_win()

  -- Create a dummy file in the vault
  local note_path = child.Obsidian.dir / "my-new-note.md"
  h.write("hello world", note_path)

  -- Open note in floating window
  child.lua(string.format([[M.open_note("%s", "float")]], tostring(note_path)))

  -- Check that a new window was opened
  local wins_after_first_open = child.api.nvim_list_wins()
  eq(2, #wins_after_first_open)
  local float_win_id = child.api.nvim_get_current_win() -- it should be focused

  -- go back to original window to lose focus on the float
  child.api.nvim_set_current_win(orig_win_id)
  eq(orig_win_id, child.api.nvim_get_current_win()) -- make sure focus changed

  -- Open note in floating window AGAIN
  child.lua(string.format([[M.open_note("%s", "float")]], tostring(note_path)))

  -- Check that NO new window was opened
  local wins_after_second_open = child.api.nvim_list_wins()
  eq(2, #wins_after_second_open)

  -- Check that the previously created float window is now the current one
  local final_current_win = child.api.nvim_get_current_win()
  eq(float_win_id, final_current_win)
end

return T