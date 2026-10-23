"""The red-fixture meta-test: a guard that can't fail can't be added.

Every aspect needs non-empty fixtures/red/ (each immediate subdirectory is a
case its own check() must reject) and non-empty fixtures/green/ (each case
check() must accept).
"""

from aspects.runner import fixture_cases, violations_for


def test_red_fixture_rejected(aspect):
    cases = fixture_cases(aspect, "red")
    assert cases, (
        f"{aspect.slug}: fixtures/red/ has no case directory — a guard that can't fail can't be added"
    )
    for case in cases:
        violations = violations_for(aspect, case)
        assert violations, f"{aspect.slug}: red fixture {case.name} was accepted"


def test_green_fixture_accepted(aspect):
    cases = fixture_cases(aspect, "green")
    assert cases, f"{aspect.slug}: fixtures/green/ has no case directory"
    for case in cases:
        violations = violations_for(aspect, case)
        assert not violations, (
            f"{aspect.slug}: green fixture {case.name} was rejected:\n"
            + "\n".join(violations)
        )
