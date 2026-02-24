Fix TeslaMate dashboards showing "No Data": Grafana 12.x's `grafana-postgresql-datasource` plugin requires the database name in `jsonData`, not just the top-level `database` field.
