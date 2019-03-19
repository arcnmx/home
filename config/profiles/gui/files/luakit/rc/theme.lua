local lousy = require "lousy"

lousy.theme.init(lousy.util.find_config("theme.lua"))
local theme = lousy.theme.get()
theme.font = "9pt monospace"
assert(theme, "failed to load theme")

local follow = require "follow"
follow.pattern_maker = follow.pattern_styles.match_label
follow.selectors.focus = 'select, textarea, input:not([type=hidden]), applet, object'
follow.stylesheet = [=[
#luakit_select_overlay {
    position: absolute;
    left: 0;
    top: 0;
    z-index: 2147483647; /* Maximum allowable on WebKit */
}

#luakit_select_overlay .hint_overlay {
    display: block;
    position: absolute;
    background-color: #ffff99;
    border: 1px dotted #000;
    opacity: 0.3;
}

#luakit_select_overlay .hint_label {
    display: block;
    position: absolute;
    background-color: #000088;
    border: 1px dashed #000;
    padding: 1px;
    margin-top: 8px;
    margin-left: -8px;
    color: #fff;
    font-size: 12px;
    font-family: monospace, courier, sans-serif;
    opacity: 0.9;
}

#luakit_select_overlay .hint_overlay_body {
    background-color: #ff0000;
}

#luakit_select_overlay .hint_selected {
    background-color: #00ff00 !important;
}
]=]

-- vim: et:sw=4:ts=8:sts=4:tw=80
