local vars = require "rc.vars"

luakit.process_limit = 4

soup.accept_policy = "always"
soup.cookies_storage = vars.profile_dir .. "/cookies.db"

local session = require "session"
session.session_file = vars.profile_dir .. "/session"
session.recovery_file = vars.profile_dir .. "/recovery_session"

local downloads = require "downloads"
downloads.default_dir = os.getenv("HOME") .. "/downloads/"
local downloads_chrome = require "downloads_chrome"

local select = require "select"
select.label_maker = function (s)
    return s.trim(s.sort(s.reverse(s.charset("jfkdlsawoeicmghqpz"))))
end

local editor = require "editor"
editor.editor_cmd = editor.builtin.urxvt

-- local noscript = require "noscript"
-- noscript.enable_scripts = false
-- noscript.enable_plugins = false

-- vim: et:sw=4:ts=8:sts=4:tw=80
