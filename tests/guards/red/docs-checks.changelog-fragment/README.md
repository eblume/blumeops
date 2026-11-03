Red case for the Docs Checks `changelog-fragment` job. Runner scratch repos have
no commit history, so this fixture proves only the nested-fragment rejection
(`tests/guards/red/changelog-fragment/docs/changelog.d/nested/entry.md`), which the
hook also enforces in `--branch` mode. Branch-presence logic is covered by
`tests/test_changelog_check.py`.
