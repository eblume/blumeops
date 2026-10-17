"""forge-bot-pat-rotate: which bot-user tokens the rotation touches.

The bot user also holds credentials minted for other purposes (their own
owners, storage, lifecycle). The rotation must neither hand those over
(nor does it — they are not the vault's incumbent) nor revoke them (that
would break their consumers). The failure mode this pins is the one that
took down the first shakedown: the pre-mint "exactly one unprefixed
incumbent" check counted an external token and refused to run (eblume/
blumeops#1656, run 9754).
"""

import importlib.machinery
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "forge_bot_pat_rotate", str(ROOT / "mise-tasks" / "forge-bot-pat-rotate")
    )
    spec = importlib.util.spec_from_loader("forge_bot_pat_rotate", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


fbr = _load()


def test_retained_external_tokens():
    # The set is a decision, not a default — pin it so a rename or scope
    # change is a visible, reviewed edit.
    assert fbr.RETAINED_EXTERNAL_TOKENS == frozenset({"horkos-forge-read"})


def _tok(i, name, last_eight="x"):
    return {"id": i, "name": name, "token_last_eight": last_eight}


# --- external-token recognition --------------------------------------------


def test_horkos_forge_read_is_external():
    assert fbr.is_external_token("horkos-forge-read")
    assert not fbr.is_external_token("forge-bot-pat-2026")
    assert not fbr.is_external_token("talos-2026-10")


# --- the pre-mint predecessor set (the shakedown failure mode) --------------


def test_incumbent_plus_external_is_a_single_predecessor():
    """The first run sees the vault's incumbent and the horkos read token:
    that must count as ONE predecessor (the incumbent), not two — this is
    exactly the case that made run 9754 die before minting."""
    existing = [
        _tok(24, "talos-2026-10", "abc12345"),  # the vault's incumbent
        _tok(20, "horkos-forge-read"),  # external, retained
    ]
    assert [t["id"] for t in fbr.unprefixed_predecessors(existing)] == [24]
    assert [t["id"] for t in fbr.external_tokens(existing)] == [20]


def test_two_real_unprefixed_tokens_yield_two_predecessors():
    """Two unprefixed tokens that are NOT the known external one means
    something unknown is holding tokens — the guard (len > 1) must die."""
    existing = [
        _tok(24, "talos-2026-10"),
        _tok(25, "some-other-token"),
    ]
    assert len(fbr.unprefixed_predecessors(existing)) == 2


# --- the revoke set ----------------------------------------------------------


def test_revocation_targets_exclude_new_and_external():
    """Every live token is a revocation target EXCEPT the new one and the
    retained external credential — the prefixed predecessors and the
    unprefixed incumbent are all superseded by this run."""
    existing = [
        _tok(30, "forge-bot-pat-111"),  # a previous rotation's token
        _tok(31, "forge-bot-pat-222"),  # the new one
        _tok(24, "talos-2026-10"),  # the incumbent predecessor
        _tok(20, "horkos-forge-read"),  # external, retained
    ]
    targets = {t["id"] for t in fbr.revocation_targets(existing, 31)}
    assert targets == {24, 30}  # the new one and the external are left


def test_revocation_targets_no_regression_without_external():
    """The original case: only prefixed tokens and one incumbent — behavior
    unchanged (revokes the old prefixed one and the incumbent, keeps the new)."""
    existing = [
        _tok(1, "forge-bot-pat-old"),
        _tok(2, "forge-bot-pat-new"),  # the new one
        _tok(3, "incumbent"),
    ]
    targets = {t["id"] for t in fbr.revocation_targets(existing, 2)}
    assert targets == {1, 3}
