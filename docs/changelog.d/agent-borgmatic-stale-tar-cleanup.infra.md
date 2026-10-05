Remove the stale pre-#1428 `k8s-dumps/talos-data.tar` from indri's
staging dir on provision so it stops riding into main `indri-*`
archives, and note in the backup docs that talos sessions are restored
from `talos-data-*` archives only.

Part of eblume/blumeops#1409.
