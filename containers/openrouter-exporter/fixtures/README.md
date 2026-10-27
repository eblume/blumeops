# Fixtures for the OpenRouter exporter

These files are **SYNTHETIC**. They are not recordings of live OpenRouter
responses. Their shape follows the example payloads in OpenRouter's public
OpenAPI spec (https://openrouter.ai/openapi.json) for `GET /activity` and
`GET /credits`. The live response shape is assumed to match this as of
2026-10-26.

- `activity.json` — `{"data": [...]}` rows keyed by date, model, and
  endpoint. Two rows share a date and model with different `endpoint_id`
  values, so the aggregation path is exercised.
- `credits.json` — `{"data": {"total_credits", "total_usage"}}`.

Numbers and identifiers are made up. Nothing here comes from a real account.
