---
name: docs: correct /share/bogus expectation in the photos.eblu.me verification matrix
---

The matrix said the bogus share id returns the app with a 200 "invalid link" page; immich v3.0.2 answers with its own 404 shell. The row now records the observed behavior and how to tell it apart from the nginx 403 deny.
