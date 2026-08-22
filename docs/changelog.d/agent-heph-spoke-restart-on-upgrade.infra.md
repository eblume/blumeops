Ringtail heph install oneshots now restart their spoke daemon after the
pinned heph tag changes, so a spoke no longer runs a stale binary (and 400s
against a newer hub) until someone restarts it by hand.
