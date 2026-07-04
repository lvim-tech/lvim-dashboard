-- lvim-dashboard.health: `:checkhealth lvim-dashboard` — reports that the dashboard is loadable, its deps
-- (lvim-utils base, lvim-picker for the `pick` actions) are present, and the effective state (enabled /
-- auto-open / whether a preset menu is defined). Delegates the state checks to the dashboard's own reporter.
--
---@module "lvim-dashboard.health"

local M = {}

---@param mod string
---@return boolean
local function has(mod)
    return (pcall(require, mod))
end

function M.check()
    local h = vim.health
    h.start("lvim-dashboard")

    if vim.fn.has("nvim-0.12") == 1 then
        h.ok("Neovim >= 0.12")
    else
        h.error("Neovim >= 0.12 required")
    end
    if has("lvim-utils.utils") then
        h.ok("lvim-utils (base) is available")
    else
        h.error("lvim-utils not found — lvim-dashboard requires it")
    end
    if has("lvim-picker") then
        h.ok("lvim-picker is available (the built-in `pick` actions open its finders)")
    else
        h.warn("lvim-picker not found — the built-in `pick` actions won't work (set your own preset.pick)")
    end

    -- Effective state + preset sanity, from the dashboard's own reporter.
    require("lvim-dashboard").health(h)
end

return M
