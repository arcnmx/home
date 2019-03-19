local settings = require "settings"

settings.webview.enable_caret_browsing = true
settings.webview.enable_mediasource = true
settings.webview.enable_developer_extras = true
settings.window.max_title_len = 200
settings.window.close_with_last_tab = true
settings.webview.monospace_font_family = "Droid Sans Mono Dotted"
settings.webview.enable_webgl = true
settings.webview.javascript_can_open_windows_automatically = true
settings.window.home_page = "about:blank"
settings.webview.enable_accelerated_2d_canvas = true
settings.webview.media_playback_requires_gesture = true
settings.webview.enable_dns_prefetching = true
settings.webview.enable_webaudio = true
settings.window.scroll_step = 100
settings.window.search_engines = {
    g = "https://encrypted.google.com/search?q=%s",
    gh = "https://github.com/search?q=%s",
    w = "https://en.wikipedia.org/wiki/Special:Search?search=%s",
    ddg = "https://duckduckgo.com/?q=%s",
    r = "https://reddit.com/r/%s",
    rs = "https://doc.rust-lang.org/std/index.html?search=%s",
    crates = "https://crates.io/search?q=%s",
    docs = "https://docs.rs/%s/*",
    aur = "https://aur.archlinux.org/packages/?K=%s",
    yt = "https://www.youtube.com/results?search_query=%s",
}
settings.window.default_search_engine = "g"

-- vim: et:sw=4:ts=8:sts=4:tw=80
