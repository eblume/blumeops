Document why an agent PR's checks sit `pending` until a human clicks *Approve
and run*, and why that click is kept. It is not only friction: it decides which
workflow files execute — the target branch's for an untrusted author, the pull
request's own once that author is trusted — so permanently trusting the agents
bot would let an agent PR run its own workflow definitions on the `indri`
runner before anyone read the diff. Records that `pull_request_target` is the
tempting way to skip the click and should not be used here, since it is the one
trigger that receives secrets and a write-capable token.
