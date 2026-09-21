"""origin_issue: the request's POST body names the issue its PR references.

Horkos comments the settlement outcome on that issue (eblume/horkos#40), so
request-run must resolve it at filing time from the attached PR — the same
first-ref rule talos uses in matchMergeTrigger. Pure functions only: no
network, no cli.
"""

import re

import pytest

BLUMEOPS = "eblume/blumeops"
TALOS = "eblume/talos"


def test_keyword_ref_with_cross_repo_prefix(request_run):
    assert request_run.extract_issue_refs("Part of eblume/talos#91") == [
        {"repo": "eblume/talos", "number": 91}
    ]


def test_unprefixed_keyword_ref_has_no_repo_key(request_run):
    assert request_run.extract_issue_refs("Fixes #91") == [{"number": 91}]


def test_keyword_ref_blumeops(request_run):
    assert request_run.extract_issue_refs("Part of eblume/blumeops#707") == [
        {"repo": "eblume/blumeops", "number": 707}
    ]


def test_issue_url_ref(request_run):
    assert request_run.extract_issue_refs(
        "see https://forge.eblu.me/eblume/talos/issues/91"
    ) == [{"repo": "eblume/talos", "number": 91}]


def test_fix_and_closes_forms(request_run):
    assert request_run.extract_issue_refs("Fix #91") == [{"number": 91}]
    assert request_run.extract_issue_refs("closes #91") == [{"number": 91}]


def test_word_boundary_rejects_midword_keyword(request_run):
    """The \"fixes\" inside \"prefixes\" is not a boundary match."""
    assert request_run.extract_issue_refs("prefixes #91 are gone") == []


def test_digit_run_consumes_whole_number(request_run):
    assert request_run.extract_issue_refs("Fixes #911 — not the 91 issue") == [
        {"number": 911}
    ]


def test_mixed_refs_in_first_match_order(request_run):
    assert request_run.extract_issue_refs(
        "Part of eblume/talos#91, see https://forge.eblu.me/eblume/blumeops/issues/707, refs #12"
    ) == [
        {"repo": "eblume/talos", "number": 91},
        {"repo": "eblume/blumeops", "number": 707},
        {"number": 12},
    ]


def test_title_ref_beats_body_ref_with_explicit_repo(request_run):
    """First ref wins by position: the title's unprefixed #2 outranks the
    body's explicit-repo ref, and defaults to the --repo argument."""
    pr = {"title": "Fixes #2", "body": "Part of eblume/talos#1"}
    assert request_run.resolve_origin_issue(pr, BLUMEOPS) == "eblume/blumeops#2"


def test_unprefixed_ref_defaults_to_base_repo(request_run):
    pr = {
        "title": "t",
        "body": "Part of #40",
        "base": {"repo": {"full_name": TALOS}},
    }
    assert request_run.resolve_origin_issue(pr, BLUMEOPS) == "eblume/talos#40"


def test_cross_repo_prefix_beats_base_repo(request_run):
    pr = {
        "title": "t",
        "body": "Part of eblume/other#5",
        "base": {"repo": {"full_name": TALOS}},
    }
    assert request_run.resolve_origin_issue(pr, BLUMEOPS) == "eblume/other#5"


def test_no_refs_means_no_origin_issue(request_run):
    pr = {"title": "t", "body": "nothing about issues here"}
    assert request_run.resolve_origin_issue(pr, BLUMEOPS) is None


def test_warrant_payload_carries_origin_issue(request_run):
    payload = request_run.warrant_payload(
        "deploy-fly.yaml",
        "a" * 40,
        {"revision": "a" * 40},
        "why",
        12,
        TALOS,
        "eblume/talos#91",
    )
    assert payload["origin_issue"] == "eblume/talos#91"
    assert payload["pr"] == 12
    assert payload["pr_repo"] == TALOS


def test_warrant_payload_origin_issue_may_be_none(request_run):
    payload = request_run.warrant_payload(
        "deploy-fly.yaml", "a" * 40, {}, "", 12, BLUMEOPS, None
    )
    assert payload["origin_issue"] is None
    assert "origin_issue" in payload


def test_resolve_tolerates_missing_or_none_title_and_body(request_run):
    # Forge PRs always carry both, but the resolver must not crash on a
    # partial record: missing keys and explicit None both mean "no text".
    assert request_run.resolve_origin_issue({}, BLUMEOPS) is None
    assert (
        request_run.resolve_origin_issue({"title": None, "body": None}, BLUMEOPS)
        is None
    )
    pr = {"body": "Part of eblume/talos#9"}  # no title key at all
    assert request_run.resolve_origin_issue(pr, BLUMEOPS) == "eblume/talos#9"


@pytest.mark.parametrize(
    ("pr", "expected"),
    [
        ({"title": "t", "body": "Part of eblume/talos#91"}, "eblume/talos#91"),
        (
            {
                "title": "Fixes #40",
                "body": "",
                "base": {"repo": {"full_name": "eblume/talos"}},
            },
            "eblume/talos#40",
        ),
        (
            {"title": "t", "body": "see https://forge.eblu.me/eblume/cv/issues/7"},
            "eblume/cv#7",
        ),
    ],
)
def test_resolved_values_match_horkos_origin_format(request_run, pr, expected):
    """The value is exactly what horkos validates as owner/repo#N — pin the
    cross-service contract so a resolution regression cannot 422 the filing."""
    resolved = request_run.resolve_origin_issue(pr, BLUMEOPS)
    assert resolved == expected
    assert re.fullmatch(r"[\w.\-]+/[\w.\-]+#\d+", resolved)
