Fix zot registry outage: the Trivy stderr progress-bar filter (awk,
line-oriented) buffered the newline-less CR-stream of a DB download
indefinitely, wedging zot's stderr pipe — zot froze at "updating cve-db"
before binding HTTP, leaving the registry dark for ~12h. Replaced with an
unbuffered byte-stream filter (`tr -u` + line-buffered grep).
