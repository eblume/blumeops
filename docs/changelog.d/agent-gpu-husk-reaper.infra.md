Add a GPU husk reaper CronJob to the nvidia-device-plugin app: after a hard
reboot, kubelet readmits GPU pods before the device plugin re-registers
`nvidia.com/gpu`, leaving permanent `UnexpectedAdmissionError` husks. The
CronJob (every 10 min, scoped to Failed pods requesting the GPU) deletes
them. Restart-ringtail runbook and ringtail reference updated.
