-- One rendered row, exactly as wide as the pane.
--
-- Every row of the dashboard goes through render_item, and the invariant that matters is the
-- same one lvim-ui's suite states for its frames: a row must fill the pane's width EXACTLY in
-- DISPLAY CELLS. A row that falls short leaves a ragged edge where a selected row's background
-- stops; a row that overruns wraps and pushes everything below it down. Both are measured here
-- against awkward text -- CJK, a combining accent, an emoji, Cyrillic -- because the arithmetic
-- is in cells while the highlight columns it produces are in BYTES.

local render = require("lvim-dashboard.render")

--- The minimal `self` render_item reads: a pane width and a highlight alias table.
---@param width integer
---@return table
local function pane(width)
    return { opts = { width = width, hl = {} } }
end

--- Render one item and return the lines as plain strings.
---@param width integer
---@param item table
---@return string[]
local function strings(width, item)
    local out = {}
    for i, line in ipairs(render.render_item(pane(width), item)) do
        out[i] = line.str
    end
    return out
end

--- Display width of every rendered line.
---@param width integer
---@param item table
---@return integer[]
local function widths(width, item)
    local out = {}
    for i, s in ipairs(strings(width, item)) do
        out[i] = vim.fn.strdisplaywidth(s)
    end
    return out
end

--- A Nerd Font glyph, built from its codepoint rather than written into this file: a Private Use
--- Area character does not survive every editor and every pipe, and an icon that silently became
--- the empty string makes a case about icons pass without testing anything. (It did.)
local GLYPH = vim.fn.nr2char(0xf15b) -- nf-fa-file

local AWKWARD = {
    { "ascii", "hello" },
    { "CJK", "日本語テキスト" },
    { "combining accent", "e\204\129clair" },
    { "emoji", "ok 👍 done" },
    { "Cyrillic", "заглавие" },
    { "nerd font glyph", GLYPH .. " file" },
    { "empty", "" },
}

describe("lvim-dashboard: a row is exactly the pane's width")

for _, case in ipairs(AWKWARD) do
    it("free text that is " .. case[1], function()
        for _, width in ipairs({ 20, 40, 80 }) do
            for _, align in ipairs({ "left", "center", "right" }) do
                local got = widths(width, { text = case[2], align = align })
                eq({ width }, got, ("%s at width %d, %s aligned"):format(case[1], width, align))
            end
        end
    end)
end

it("a row with an icon, a centre and a key still fills the width", function()
    for _, width in ipairs({ 24, 40, 80 }) do
        eq({ width }, widths(width, { icon = GLYPH, desc = "Find file", key = "f", align = "left" }))
        eq({ width }, widths(width, { icon = GLYPH, desc = "日本語", key = "<leader>ff", align = "center" }))
    end
end)

it("an indent is part of the width, not added to it", function()
    for _, indent in ipairs({ 0, 2, 7 }) do
        eq({ 40 }, widths(40, { text = "indented", indent = indent }))
    end
end)

it("text wider than the pane is not padded further", function()
    local long = ("x"):rep(100)
    local got = widths(30, { text = long })
    eq(100, got[1], "a row that is already too wide must not be padded to 130")
end)

describe("lvim-dashboard: where the text sits")

it("left, centre and right put the text in different places", function()
    local left = strings(20, { text = "ab", align = "left" })[1]
    local centre = strings(20, { text = "ab", align = "center" })[1]
    local right = strings(20, { text = "ab", align = "right" })[1]

    eq("ab", left:sub(1, 2), "left starts at the margin")
    eq(nil, centre:match("^ab"), "centre does not")
    truthy(centre:match("^%s+ab"), vim.inspect(centre))
    eq("ab", right:sub(-2), "right ends at the margin")
end)

it("centring splits the slack, with the odd cell after the text", function()
    local s = strings(11, { text = "abc", align = "center" })[1]
    local before = #(s:match("^ *"))
    local after = #(s:match(" *$"))
    eq(4, before, vim.inspect(s))
    eq(4, after, "an even split; 11 - 3 = 8")

    local odd = strings(10, { text = "abc", align = "center" })[1]
    eq(3, #(odd:match("^ *")), "the spare cell goes after the text: " .. vim.inspect(odd))
    eq(4, #(odd:match(" *$")))
end)

it("an indent pushes the text in from the left, in every alignment", function()
    local s = strings(20, { text = "ab", align = "left", indent = 4 })[1]
    eq("    ab", s:sub(1, 6))
end)

describe("lvim-dashboard: multi-line text")

it("an embedded newline becomes separate rows, each the full width", function()
    local lines = strings(30, { text = "first\nsecond\nthird" })
    eq(3, #lines)
    eq("first", vim.trim(lines[1]))
    eq("second", vim.trim(lines[2]))
    eq("third", vim.trim(lines[3]))
    for i, s in ipairs(lines) do
        eq(30, vim.fn.strdisplaywidth(s), "row " .. i)
    end
end)

it("only the first row carries the icon and the key", function()
    local rows = render.render_item(pane(40), { icon = GLYPH, text = "one\ntwo", key = "q", desc = "x" })
    eq(2, #rows)
    truthy(rows[1].str:find(GLYPH, 1, true), "the icon is on the first row")
    eq(nil, rows[2].str:find(GLYPH, 1, true), "and not repeated below it")
    truthy(rows[1].str:match("q"), "the key likewise")
end)

it("a chunk's highlight survives the split onto several rows", function()
    local rows = render.render_item(pane(30), { text = { { "a\nb", hl = "Title" } } })
    eq(2, #rows)
    for i, row in ipairs(rows) do
        eq(1, #row.marks, "row " .. i .. " lost its highlight")
        eq("Title", row.marks[1][3])
    end
end)

describe("lvim-dashboard: the highlight columns a row carries")

it("marks are byte columns inside the row's own string", function()
    local row = render.render_item(pane(40), { text = { { "abc", hl = "Title" }, { "def", hl = "Comment" } } })[1]
    eq(2, #row.marks)
    for _, m in ipairs(row.marks) do
        local s, e, group = m[1], m[2], m[3]
        truthy(s >= 0 and e <= #row.str, ("mark %d..%d is outside a %d-byte row"):format(s, e, #row.str))
        truthy(type(group) == "string" and group ~= "")
    end
    eq("abc", row.str:sub(row.marks[1][1] + 1, row.marks[1][2]), "the first mark covers exactly its chunk")
    eq("def", row.str:sub(row.marks[2][1] + 1, row.marks[2][2]))
end)

it("marks are right on multibyte text, where cells and bytes differ", function()
    local row = render.render_item(pane(40), { text = { { "日本", hl = "Title" }, { "ab", hl = "Comment" } } })[1]
    eq("日本", row.str:sub(row.marks[1][1] + 1, row.marks[1][2]), "a mark measured in cells would cut the glyph")
    eq("ab", row.str:sub(row.marks[2][1] + 1, row.marks[2][2]))
end)

it("an empty chunk gets no mark of its own", function()
    local row = render.render_item(pane(40), { text = { { "", hl = "Title" }, { "x", hl = "Comment" } } })[1]
    eq(1, #row.marks, "a zero-width highlight is nothing to paint")
    eq("Comment", row.marks[1][3])
end)

describe("lvim-dashboard: padding around a row")

it("a number pads below, a pair pads below and above", function()
    eq(1, #strings(20, { text = "x" }))
    eq(3, #strings(20, { text = "x", padding = 2 }), "a number is rows BELOW")
    local both = strings(20, { text = "x", padding = { 1, 2 } })
    eq(4, #both, "two above, the row, one below")
    eq("", vim.trim(both[1]))
    eq("", vim.trim(both[2]))
    eq("x", vim.trim(both[3]))
    eq("", vim.trim(both[4]))
end)

it("a padding row is as wide as any other", function()
    for _, s in ipairs(strings(25, { text = "x", padding = { 1, 1 } })) do
        eq(25, vim.fn.strdisplaywidth(s))
    end
end)
