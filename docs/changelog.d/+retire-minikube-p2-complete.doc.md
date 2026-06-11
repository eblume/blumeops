[[retire-minikube]] phase 2 cutover complete: authentik now reads its
database from ringtail `blumeops-pg` in-cluster (row-exact restore, SSO
verified). Minikube `blumeops-pg` soaks idle until ~2026-06-18, then
retires with cnpg, the Caddy L4 `:5432` route, and its `.pgpass` line.
