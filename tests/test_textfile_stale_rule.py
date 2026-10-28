"""Guards the TextfileStale per-writer interval rule.

Evaluates the refId A expression and refId C threshold of the textfile-stale
rule in argocd/manifests/grafana-ringtail/alerting.yaml with `promtool test
rules`, so green/red cases exercise the manifest itself rather than a copy.
"""

import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[1]
ALERTING = REPO / "argocd/manifests/grafana-ringtail/alerting.yaml"

EVAL_TIME = 400000
CLUSTER = "indri"
# 1m sample interval: index 6666 is t=399960s, inside the 5m lookback before EVAL_TIME.
SAMPLE_INDEX = 6666
NODE_DIR = "/opt/homebrew/var/node_exporter/textfile"

# (file basename, declared interval or None, age seconds, should fire)
CASES = [
    (
        "forgejo-action-trust.prom",
        86400,
        378 * 60,
        False,
    ),  # (a) daily writer, within 2x
    ("borgmatic.prom", 3600, 60 * 60, False),  # (b) hourly writer, within 2x
    ("forgejo-action-trust.prom", 86400, 30 * 3600, False),  # (g) past 1x, within 2x
    ("borgmatic.prom", 3600, 90 * 60, False),  # (h) past 1x, within 2x
    ("undeclared-green.prom", None, 60 * 60, False),  # (c) fallback 2h, within
    ("forgejo-action-trust.prom", 86400, 49 * 3600, True),  # (d) daily writer past 2x
    ("borgmatic.prom", 3600, 3 * 3600, True),  # (e) hourly writer past 2x
    ("undeclared-red.prom", None, 3 * 3600, True),  # (f) fallback 2h, past
]


def _textfile_stale_rule():
    doc = yaml.safe_load(ALERTING.read_text())
    for group in doc["groups"]:
        for rule in group.get("rules", []):
            if rule.get("uid") == "textfile-stale":
                return rule
    raise AssertionError(f"textfile-stale rule not found in {ALERTING}")


def _refid(rule, ref_id):
    for data in rule["data"]:
        if data["refId"] == ref_id:
            return data["model"]
    raise AssertionError(f"refId {ref_id} not found in textfile-stale")


def _threshold_expr(rule):
    params = _refid(rule, "C")["conditions"][0]["evaluator"]
    op = {"gt": ">", "lt": "<"}[params["type"]]
    return f"{op} {params['params'][0]}"


def _series(instance, file_label):
    return f'cluster="{CLUSTER}",instance="{instance}",job="node",file="{file_label}"'


def test_textfile_stale_per_writer_interval(tmp_path):
    rule = _textfile_stale_rule()
    expr_a = _refid(rule, "A")["expr"]
    rules_expr = f"({expr_a}) {_threshold_expr(rule)}"

    rules_file = tmp_path / "rules.yml"
    rules_file.write_text(
        yaml.safe_dump(
            {
                "groups": [
                    {
                        "name": "textfile-freshness",
                        "rules": [
                            {
                                "alert": "TextfileStale",
                                "expr": rules_expr,
                                "labels": {
                                    "severity": "warning",
                                    "service": "indri-metrics",
                                },
                            }
                        ],
                    }
                ]
            },
            sort_keys=False,
        )
    )

    input_series = []
    exp_alerts = []
    for i, (name, interval, age, fires) in enumerate(CASES):
        # One instance per case: the same file name in two cases would otherwise
        # be one series, and promtool keeps only one of the colliding samples.
        instance = f"case{i}:9100"
        full_path = f"{NODE_DIR}/{name}"
        mtime_value = EVAL_TIME - age
        input_series.append(
            {
                "series": f"node_textfile_mtime_seconds{{{_series(instance, full_path)}}}",
                "values": f"_x{SAMPLE_INDEX} {mtime_value}",
            }
        )
        if interval is not None:
            input_series.append(
                {
                    "series": f"textfile_expected_interval_seconds{{{_series(instance, name)}}}",
                    "values": f"_x{SAMPLE_INDEX} {interval}",
                }
            )
        if fires:
            exp_alerts.append(
                {
                    # on(instance, file) matching keeps only those labels in the result.
                    "exp_labels": {
                        "instance": instance,
                        "file": name,
                        "severity": "warning",
                        "service": "indri-metrics",
                    }
                }
            )

    test_file = tmp_path / "test.yml"
    test_file.write_text(
        yaml.safe_dump(
            {
                "rule_files": [str(rules_file)],
                "evaluation_interval": "1m",
                "tests": [
                    {
                        "interval": "1m",
                        "input_series": input_series,
                        "alert_rule_test": [
                            {
                                "eval_time": f"{EVAL_TIME}s",
                                "alertname": "TextfileStale",
                                "exp_alerts": exp_alerts,
                            }
                        ],
                    }
                ],
            },
            sort_keys=False,
        )
    )

    promtool = shutil.which("promtool")
    if promtool is None:
        pytest.fail(
            "promtool is not on PATH — mise.toml pins it; run via mise run horkos-test"
        )

    result = subprocess.run(
        [promtool, "test", "rules", str(test_file)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, (
        f"promtool test rules failed (rc={result.returncode}):\n"
        f"{result.stdout}\n{result.stderr}"
    )
