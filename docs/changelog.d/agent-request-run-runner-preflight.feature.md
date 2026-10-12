request-run now refuses a request whose workflow runs-on label no online runner serves, so a warranted dispatch can no longer queue forever on an unserved label (eblume/blumeops#1515). The check reads the runner fleet through the Grafana datasource proxy with the same talos-m2m identity the warrant mirror uses, and fails closed when the metrics are unreachable.

Also honors the merged scope label format (#1530): `instance`, owner, and owner/repo runners all count as serving blumeops — previously only a scope-less or exactly-repo-scoped runner did.
