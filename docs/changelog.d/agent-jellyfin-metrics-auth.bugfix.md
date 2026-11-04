Jellyfin metrics script now authenticates with `Authorization: MediaBrowser Token=` — Jellyfin 12.4 rejects `X-Emby-Token`, so the metrics collector was failing.
