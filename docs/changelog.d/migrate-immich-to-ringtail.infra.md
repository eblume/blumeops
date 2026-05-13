Move the entire Immich stack — server, machine-learning, valkey,
and the PostgreSQL+VectorChord cluster — off `minikube-indri` and
onto `k3s-ringtail`. Postgres data migrated zero-loss via CNPG
`pg_basebackup` (replica catch-up then promote); row counts on
`asset`, `user`, `album`, `smart_search`, `activity`, `asset_face`
verified equal between source and replica before cutover. The ML
pod now uses ringtail's RTX 4080 via the nvidia-device-plugin
(time-slicing bumped 2 → 4 to share with frigate + ollama). Caddy
routing at `photos.ops.eblu.me` is unchanged (still
`photos.tail8d86e.ts.net`, the device just lives on ringtail now).
Borgmatic backups continue against the same `immich-pg` tailnet
hostname. First concrete chain in the broader indri-k8s
decommission effort.
