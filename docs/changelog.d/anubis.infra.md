Deployed Anubis v1.25.0 (proof-of-work anti-scraper gateway) on the Fly.io
proxy in front of forge.eblu.me, after an AWS-hosted crawler with no declared
bot UA DoS'd Forgejo by walking the `/eblume/*` commit-history surface at
~5.7 req/s. Browsers clear one JS challenge per week; git and API clients
pass through untouched; declared AI crawlers are denied. The tailnet path
(forge.ops.eblu.me) is unaffected. Tier 2b of the AI scraper mitigation plan.
