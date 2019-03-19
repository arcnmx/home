local session = require "session"
local window = require "window"

-- Restore last saved session
local w = (not luakit.nounique) and (session and session.restore())
if w then
    for i, uri in ipairs(uris) do
        w:new_tab(uri, { switch = i == 1 })
    end
else
    -- Or open new window
    window.new(uris)
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
