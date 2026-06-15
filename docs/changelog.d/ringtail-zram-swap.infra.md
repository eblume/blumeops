ringtail: add zram swap (zstd, swappiness=10) as an OOM pressure valve and
set k3s `--kubelet-arg=fail-swap-on=false`. Scale ollama to 0 replicas
(on-demand) to drop its GPU contention and large memory tail. Relieves
host-level OOM kills of k3s pods when gaming pushes memory over the top.
