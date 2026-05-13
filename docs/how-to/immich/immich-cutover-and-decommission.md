---
title: Immich Cutover and Decommission
modified: 2026-05-13
last-reviewed: 2026-05-13
tags:
  - how-to
  - operations
  - immich
  - migration
---

# Immich Cutover and Decommission

The user-visible flip. By the time this card opens, the ringtail
stack has been proven against a copy of the data. This card does the
real cutover.

## Pre-cutover checklist

- [[immich-pg-data-migration]] dry-run succeeded; method is chosen.
- Ringtail immich stack has been brought up against the test pg,
  pods healthy, UI loaded ([[immich-app-on-ringtail#Verification]]).
- Borgmatic just ran successfully (a fresh nightly archive is a
  belt-and-suspenders fallback, on top of the live source pg).
- User has been told to stop uploading from the iOS app for the
  cutover window.

## Cutover sequence

1. **Quiesce source.** `kubectl --context=minikube-indri -n immich
   scale deploy/immich-server --replicas=0` and same for ML. Leave
   valkey + pg running. Confirm no client traffic on the source pg
   via `pg_stat_activity`.
2. **Tear down the minikube Tailscale ingress.** The `photos`
   Tailscale device name must be freed before ringtail's ingress can
   claim it (Tailscale enforces uniqueness across the tailnet).
   `kubectl --context=minikube-indri -n immich delete ingress
   immich-tailscale` and wait for the corresponding `tailscale`-LB
   StatefulSet pod to terminate. Verify the `photos` device is gone:
   `tailscale status | grep -i photos` from any tailnet host.
3. **Final sync.** Per chosen method in
   [[immich-pg-data-migration]]:
   - Option A: promote the ringtail replica.
   - Option B: take final `pg_dump`, restore to ringtail
     `immich-pg`.
4. **Verify.** Run the row-count and schema-diff checks from
   [[immich-pg-data-migration#Verification on the real run]].
5. **Flip the ringtail ingress to `photos`.** Update
   `argocd/manifests/immich-ringtail/ingress-tailscale.yaml`:
   `tls.hosts: [photos]` (was `[photos-ringtail]` during staging per
   [[immich-app-on-ringtail]]). Commit, `argocd app sync
   immich-ringtail`. Wait for the `photos` device to register on the
   tailnet again.
6. **Bring up ringtail immich** against the now-promoted pg
   (`argocd app sync immich-ringtail`). Wait for Ready.
7. **Flip routing.** Update Caddy on indri
   (`ansible/roles/caddy/defaults/main.yml`): `photos.ops.eblu.me`
   upstream changes to the ringtail Tailscale ingress hostname
   (`photos` — same MagicDNS name, now pointing to the ringtail
   proxy). `mise run provision-indri -- --tags caddy`.
8. **Smoke test.** Open `photos.ops.eblu.me` in a browser. Sign in.
   Scroll the timeline. Open an album. Trigger an ML search.
9. **Update borgmatic.** If the Tailscale hostname for pg changed,
   update `borgmatic.cfg` on indri to point at the ringtail
   `immich-pg-tailscale` service. Run a manual backup to verify.

## After cutover

- `argocd app set immich --revision <branch>` is no longer relevant;
  the minikube `immich` app gets deleted entirely.
- Delete `argocd/apps/immich.yaml`, `argocd/manifests/immich/`, and
  the minikube `argocd/manifests/databases/immich-pg.yaml` +
  `external-secret-immich-borgmatic.yaml` +
  `service-immich-pg-tailscale.yaml`.
- Rename `immich-ringtail` back to `immich` (the `-ringtail` suffix
  was scaffolding for the dual-cluster window; once minikube is
  empty of immich, the unsuffixed name is clean).
- Confirm the minikube `immich-pg` PVC is no longer used, then
  delete it (the PV with `Retain` policy will persist — clean that
  up too).

## Verification (definition of done)

- `photos.ops.eblu.me` works for a real session, including ML search.
- Source minikube has no `immich` pods, no `immich-pg`, no PVCs.
- Memory pressure on minikube has dropped (≥1.5 GiB reclaimed). Check
  `docker stats minikube` on indri.
- Nightly borgmatic run after the cutover completes successfully,
  with the immich-pg archive showing the new source.

## Rollback (within the cutover window)

If smoke test fails: flip Caddy back, scale ringtail immich to 0,
scale source immich back up. Source pg was never destroyed. File a
plan reset on the relevant prerequisite card and try again next
session.

## Out of scope

- Decommissioning all of minikube. This chain just removes immich.
  Other tenants migrate in their own chains as part of the broader
  indri-k8s decommission. See [[migrate-immich-to-ringtail]] for
  context.
