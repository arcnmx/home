local vars = require "rc.vars"
local window = require "window"
local webview = require "webview"
local lousy = require "lousy"
local log_chrome = require "log_chrome"

if vars.tab_windows then
    window.add_signal("init", function (w)
        w.new_tab_backup = w.new_tab
        w.new_tab = function (w, arg, opts)
            if type(arg) == "table" and arg.newtab_hack then
                arg.tab = w:new_tab_backup(arg.arg, arg.opts)
                return arg.tab
            elseif w.tabs ~= nil and w.tabs:count() > 0 then
                local args = { newtab_hack = true, arg = arg, opts = opts }
                local new_w = window.new({args})
                return args.tab
            else
                return w:new_tab_backup(arg, opts)
            end
        end
    end)
end

local theme = lousy.theme.get()
window.add_signal("build", function (w)
    local widgets, l, r = require "lousy.widget", w.sbar.l, w.sbar.r

    if vars.profile_name then
        local profile = widget{type="label"}
        profile.font = theme.buf_sbar_font
        profile.fg = theme.buf_sbar_fg
        profile.text = "[" .. vars.profile_name .. "]"
        l.layout:pack(profile)
    end

    -- Left-aligned status bar widgets
    l.layout:pack(widgets.uri())
    l.layout:pack(widgets.hist())
    l.layout:pack(widgets.progress())

    -- Right-aligned status bar widgets
    r.layout:pack(widgets.buf())
    r.layout:pack(log_chrome.widget())
    r.layout:pack(widgets.ssl())
    if not tab_windows then
        r.layout:pack(widgets.tabi())
    end
    r.layout:pack(widgets.scroll())
end)

-- local plugins = require "plugins"
-- require "plugins.uaswitch"
require "plugins.tabmenu"
require "plugins.yanksel"

require "session"
require "downloads"
require "select"

require "pass"
require "paste"

require "webinspector"

require "formfiller"

require "proxy"

require "quickmarks"

require "undoclose"

require "tabhistory"

require "userscripts"

require "bookmarks"
require "bookmarks_chrome"

require "cmdhist"

require "search"

require "taborder"

require "history"
require "history_chrome"

-- require "help_chrome"
-- require "binds_chrome"

require "completion"

require "open_editor"
local editor = require "editor"
editor.editor_cmd = editor.builtin.urxvt

require "noscript"

require "follow_selected"
require "go_input"
require "go_next_prev"
require "go_up"

require_web_module("referer_control_wm")

require "error_page"

require "styles"

-- require "hide_scrollbars"

require "image_css"

-- vim: et:sw=4:ts=8:sts=4:tw=80
