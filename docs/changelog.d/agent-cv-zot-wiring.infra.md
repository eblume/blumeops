cv's release pipeline moves off the Forgejo packages registry: the horkos
publisher fetches the cv release-asset tarball, pushes it as the zot OCI
artifact `blumeops/cv:<version>` on a dedicated push-only `zot-cv` identity,
and opens the ansible pin PR; the cv role now pulls the layer from zot,
cv-deploy.yaml is deleted, and cv joins the fork pool (eblume/horkos#17).
