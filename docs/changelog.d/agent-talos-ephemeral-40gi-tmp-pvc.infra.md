Raise the talos pod's `ephemeral-storage` limit from 10Gi to 40Gi — the watermark gc in eblume/talos#250 is the actual bound, the limit is the backstop — and mount `/tmp` from the `talos-home` PVC (`subPath: .tmp`) so throwaway writes leave the writable layer.
Corrects the stale eval-only nix description in `docs/reference/services/talos.md`.
