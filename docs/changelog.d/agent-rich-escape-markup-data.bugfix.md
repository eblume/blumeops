mise-tasks: stop interpolating untrusted data into rich markup, so bracket-bearing
values can't crash or garble output. `service-review` (and every other rich-based
task) now runs every data-derived value (notes, names, types, versions, upstreams,
paths, tags, API/CLI output) through `rich.markup.escape` before it reaches a
`Console.print`/`Panel`/`Table`. Previously a `notes` value like `see [[hephaestus]]`
was silently stripped and any `[/...]` sequence raised `rich.errors.MarkupError`,
killing the whole task; bracketed strings now render literally everywhere.
