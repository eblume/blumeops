Add `mise-tasks/_require`, a guard that refuses to start a task whose tools the
machine does not have, and wire it into the four tasks whose blocker really is a
missing binary: `validate-workflows`, `frigate-export-model` and `docs-preview`
(docker, for Dagger's engine) and `services-check`,
`ensure-k3s-ringtail-kubectl-config` (kubectl). It names what is missing, that
you are in the agent pod, and what to do instead — a `[human]` description tag
is invisible at the moment of failure and does nothing about a task that runs,
half-works and exits 0.

Also marks `[human]` on eleven tasks that cannot run from the pod but were not
labelled, and corrects that label's definition: it means "needs something the
pod does not have", of which the blumeops vault is only one case — a missing
tool or an ssh route to indri/ringtail are the others.
