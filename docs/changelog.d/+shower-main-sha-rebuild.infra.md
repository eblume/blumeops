Rebuild shower from the post-merge commit on main so the container's
SHA tag points at a commit that will still exist after the 30-day
branch-cleanup window. Functionally identical to the branch-tag image
already deployed, just preserves source traceability per
[[build-container-image#Squash-merge and container tags]].
