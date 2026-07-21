Firefox on ringtail now runs under XWayland (`MOZ_ENABLE_WAYLAND=0`), working
around a hard deadlock that froze the whole browser. NVIDIA's Wayland EGL
explicit-sync path can leave a DRM timeline fence unsignaled inside
`eglSwapBuffers`, so the Renderer thread blocks forever in
`drmSyncobjTimelineWait`; the Compositor thread then blocks in
`WaitUntilPresentationFlushed`, and the main thread blocks behind a synchronous
`SendFlushRendering` IPC issued while painting a popup. Painting any doorhanger,
menu, or dropdown could trigger it, leaving Firefox wedged at 0% CPU until
killed — the trigger that surfaced it was clicking "enable notifications", which
is a repaint, not a network call. No Firefox pref or wlroots/sway toggle governs
this path, and nixpkgs production/latest/beta were all pinned to the affected
580.142 driver, so XWayland is the only lever until a newer driver ships.
