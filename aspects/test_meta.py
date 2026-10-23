"""The fixture meta-test: a guard that can't fail can't be added.

Every aspect needs non-empty fixtures/red/ (each immediate subdirectory is a
case its check must reject) and non-empty fixtures/green/ (each case its
check must accept). Ratchets use ratchet semantics against the aspect's own
baseline: a red case must have at least one violation not in baseline.json,
a green case is accepted when every violation is baselined.
"""

from aspects.runner import fixture_cases, violations_for


def _unexpected(aspect, violations):
    return [v for v in violations if v not in set(aspect.baseline)]


def test_red_fixture_rejected(aspect):
    cases = fixture_cases(aspect, "red")
    assert cases, (
        f"{aspect.slug}: fixtures/red/ has no case directory — a guard that can't fail can't be added"
    )
    for case in cases:
        violations = violations_for(aspect, case)
        if aspect.kind == "ratchet":
            unexpected = _unexpected(aspect, violations)
            assert unexpected, (
                f"{aspect.slug}: red fixture {case.name} was accepted — every "
                "violation is in baseline.json"
            )
        else:
            assert violations, f"{aspect.slug}: red fixture {case.name} was accepted"


def test_green_fixture_accepted(aspect):
    cases = fixture_cases(aspect, "green")
    assert cases, f"{aspect.slug}: fixtures/green/ has no case directory"
    for case in cases:
        violations = violations_for(aspect, case)
        if aspect.kind == "ratchet":
            unexpected = _unexpected(aspect, violations)
            assert not unexpected, (
                f"{aspect.slug}: green fixture {case.name} was rejected:\n"
                + "\n".join(unexpected)
            )
        else:
            assert not violations, (
                f"{aspect.slug}: green fixture {case.name} was rejected:\n"
                + "\n".join(violations)
            )
