Rebuild and retag alloy v1.16.0 container images from the main-branch SHA
following the squash-merge of #345, per the build-container-image
squash-merge convention. Both images (`registry.ops.eblu.me/blumeops/alloy`)
now reference `9564435` rather than the branch SHA `26a3ab5`, restoring
source traceability after branch cleanup.
