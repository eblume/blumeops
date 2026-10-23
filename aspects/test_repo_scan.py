"""The repo scan: run every aspect whose repo filter admits the target repo
against it. Default target: this blumeops checkout; --repo PATH overrides."""

import pytest

from aspects.runner import applies_to_repo, assert_kind_holds


def test_aspect_on_target_repo(aspect, target):
    if not applies_to_repo(aspect, target.identity):
        pytest.skip(f"{aspect.slug} does not apply to {target.identity}")
    assert_kind_holds(aspect, target.root)
