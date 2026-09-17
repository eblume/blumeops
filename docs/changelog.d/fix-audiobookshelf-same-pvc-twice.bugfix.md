audiobookshelf: mount the data PVC once with `subPath` for `/config` and `/metadata` — referencing one PVC under two volume names left the pod stuck in ContainerCreating.
