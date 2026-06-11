[[retire-minikube]] phase 2 groundwork: ringtail `blumeops-pg` gains a
managed `authentik` role (password sourced from the same 1Password item
the authentik app reads, so the cutover is only a `postgresql-host`
flip), and borgmatic's authentik entry moves from port 5432 (minikube)
to 5434 (ringtail). The authentik database itself is dump/restored at
the cutover window per the plan card.
