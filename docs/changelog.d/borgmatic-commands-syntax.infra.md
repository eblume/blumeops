Migrated the [[borgmatic]] role's pre-backup database snapshot hooks from the
deprecated `before_backup:` key to borgmatic 2.x's `commands:` syntax, clearing
the `before_backup is deprecated` warning logged since borgmatic 2.1.4. Using
`before: configuration` also stages the heph/mealie/shower/navidrome dumps
**once per run** instead of once per repository — previously the two repos
(sifaka + BorgBase) each re-ran every dump, harmless but redundant. The
abort-on-failure guarantee (a non-zero hook aborts the whole backup, so a failed
snapshot is never silent) is preserved.
