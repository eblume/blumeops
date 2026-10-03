#!/bin/sh
# Regenerate the static mirror's root index: one row per mirrored repo,
# linking to its stagit log page, with the last commit date + subject.
# Owner-scoped: repos live at <owner>/<name>.git and pages at
# <owner>/<name>/ (stagit-index links flat, so this replaces it).
# Usage: gen-index.sh <reposdir> <sitedir>
set -eu

reposdir="${1:?reposdir}"
sitedir="${2:?sitedir}"

html_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

{
    echo '<!DOCTYPE html>'
    echo '<html><head><meta charset="utf-8">'
    echo '<title>forge.eblu.me — public repositories</title>'
    echo '<link rel="icon" type="image/png" href="favicon.png" />'
    echo '<link rel="stylesheet" type="text/css" href="style.css" />'
    echo '</head><body>'
    echo '<h1>public repositories</h1>'
    echo '<p>Read-only mirror. Source and issues live at <a href="https://forge.ops.eblu.me/">forge.ops.eblu.me</a> (tailnet).</p>'
    echo '<table id="log"><thead><tr><td><b>Repository</b></td><td><b>Last commit</b></td></tr></thead><tbody>'
    for r in "$reposdir"/*/*.git; do
        [ -d "$r" ] || continue
        owner=$(basename "$(dirname "$r")")
        name=$(basename "$r" .git)
        last=$(git --git-dir="$r" log -1 --date=short --format='%ad %s' 2>/dev/null || true)
        printf '<tr><td><a href="%s/%s/log.html">%s/%s</a></td><td>%s</td></tr>\n' \
            "$owner" "$name" "$owner" "$name" "$(html_escape "$last")"
    done
    echo '</tbody></table></body></html>'
} > "$sitedir/index.html"
