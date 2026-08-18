Add an hourly `skagit-cce-watch` user timer on ringtail that polls the Skagit
CCE course-catalog category and files a **red** heph task (under the new
**Ceramics** project) the first time a new ceramics class is listed, keyed on
the catalog's Item Number. State lives in `~/.local/state/skagit-cce-watch/`;
first run baselines silently and a zero-course parse fails loudly without
touching state.

On a new ceramics class it also fires a **best-effort** ntfy push to
`ntfy.ops.eblu.me/ceramics` (tapping opens the course page) so the alert
reaches Erich's phone; a push failure never fails the tick.
