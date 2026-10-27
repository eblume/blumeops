OpenRouter exporter: the pod sets `enableServiceLinks: false`, so the kubelet no longer injects a `tcp://` value for `OPENROUTER_EXPORTER_PORT` from the same-named Service (eblume/blumeops#1981).
