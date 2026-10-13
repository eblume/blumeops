# Fixtures for the authentik blueprint-state exporter

`recorded-2026-10-13-page-1.json` is the one **genuine recording**: one
real page of `GET /api/v3/managed/blueprints/?page_size=20` captured
2026-10-13 with the `ci-authentik-blueprints` token (42 instances, 3
pages; `next` is a page number, per authentik's own `Pagination` class).
Its `results` is truncated to the page's first entry — it records the
shape, not a full poll — so it is not a valid `load_snapshot` input
(the API-count check rejects 1 instance against `pagination.count` 42).

The `poll-*.json` files are **synthetic**, built to authentik's real
list-response shape. The shape's source: authentik's public OpenAPI
schema (`GET /api/v3/schema/?format=json`, no auth:
`PaginatedBlueprintInstanceList` = `{"pagination": Pagination,
"results": [BlueprintInstance], "autocomplete": {…}}`, and `Pagination`
= `{"next": <next page number, 0 on the last page>, "previous": …,
"count": <total>, "current": …, "total_pages": …, "start_index": …,
"end_index": …}`), verified live on 2026-10-05 with the
`ci-authentik-blueprints` token; eblume/blumeops#1444 cycle 2. The
`results` bodies carry no secrets (instance `pk`/`path`/`status`
only), and the counts (28 healthy + 1 error) match the live deployment
observed that day.

Each `poll-*.json` file is `{"pages": […]}` — one poll, in page order, as
`fetch_all` would collect it. The two-page 20+9 split models a list
larger than `PAGE_SIZE`: with `page_size=500` the live deployment's
instances fit on one page, so the split exists purely to exercise
`fetch_all`'s follow-up (`?page=N&page_size=500`) path.
