`ringtail-rebuild` warrant: replace the NOPASSWD sudo grant, which could never
work (the priv runner is a systemd `DynamicUser` service, so `NoNewPrivileges`
is implied and sudo refuses), with a root `ringtail-apply@<sha>.service`
template unit that polkit lets `gitea-runner` start — and nothing else. The
runner's sandbox stays intact; the job reads the verdict from
`/var/log/ringtail-apply/<sha>.log`.
