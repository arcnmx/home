require "lfs"

-- allow ~/.config to override system libraries
package.path = os.getenv("HOME") .. "/.config/luakit/?.lua;" .. os.getenv("HOME") .. "/.config/luakit/?/init.lua;" .. package.path

local vars = require "rc.vars"

vars.profile_name = os.getenv("LUAKIT_PROFILE")
vars.tab_windows = os.getenv("SWAYSOCK") ~= nil or (os.getenv("XDG_CURRENT_DESKTOP") or "") == "i3"

local unique_instance = require "unique_instance"
unique_instance.open_links_in_new_window = vars.tab_windows
unique_instance.exec("org.luakit." .. (vars.profile_name or "default"))

local lousy = require "lousy"

if vars.profile_name then
    vars.profile_dir = luakit.data_dir .. "/profiles/" .. vars.profile_name
    lousy.util.mkdir(vars.profile_dir)
else
    vars.profile_dir = luakit.data_dir
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
