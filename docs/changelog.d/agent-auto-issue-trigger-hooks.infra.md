talos webhook hooks on every pooled repo now subscribe to the `issues`
umbrella event (issue creation/assign/label/milestone/comment deliveries, not
just assign/label/comment) and the `agent-repo-access` reconcile now also
creates a `no-agents` suppression label alongside the `agents` engagement
label — the hook + label half of auto-kicking talos cycles off issues I create
([eblume/blumeops#725](https://forge.eblu.me/eblume/blumeops/issues/725);
the receiver half ships in [eblume/talos#63](https://forge.eblu.me/eblume/talos/pulls/63)).
