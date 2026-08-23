borgmatic now backs up the talos data dir (all session transcripts + meta/crons/settings) via in-pod tar, and the horkos approval-queue SQLite DB via the k8s sqlite dump helper.
