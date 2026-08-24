Add `TALOS_ADMINS` (Erich's operator identity) to the talos deployment so the
emergency stop (eblume/talos#38) can be released after being armed — the
release path is admin-gated and fails closed without this.
