Retire `minikube.prom`, which `TextfileStale` was still evaluating on indri two
months after the minikube cluster itself was retired. node_exporter exports
`node_textfile_mtime_seconds` for every `.prom` file it finds, so a collector's
series outlives the service it measured — and with `noDataState: Alerting`, a
retired thing ends up positioned to page about its own absence.

The alloy role grows an `alloy_retired_collectors` list: for each entry it
removes the `.prom` file and unloads/removes any `mcquack.eblume.*<name>*.plist`
still writing it — plist first, since removing the file while a writer is loaded
just gets it rewritten. Declaring the tombstone is the point; a hand `rm` on
indri doesn't survive whichever of the two is still live.

The runbook grows the matching instruction, since "the alert names a file that
isn't in this table" is exactly the symptom.
