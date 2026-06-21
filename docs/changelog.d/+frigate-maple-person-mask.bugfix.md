Added a `person` object-filter mask to the `gablecam` Frigate camera to stop a
newly-planted Japanese maple (in the bottom-right planter) from being detected as
a person and spamming alerts. The false detections scored 0.57–0.84 — overlapping
real-person scores — so `min_score` couldn't filter them; the mask covers only the
front-deck-stairs corner by the building. Trade-off: a person actually on the
stairs no longer alerts, but should trip an alert as soon as they step off into
the driveway. Mask region derived from the actual false-positive bounding boxes
via the Frigate events API.
