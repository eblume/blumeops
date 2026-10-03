#!/bin/sh
# Create or adopt the static mirror state on the Fly volume: read the
# allowlist (baked into the image at build), create a bare repo per entry
# (or adopt an existing one), and generate the initial static site.
# Runs in start.sh's post-start phase — needs no tailnet, and the repo
# list stays a single source of truth in fly/git-mirror/repos.
# Idempotent: re-runs adopt existing repos and regenerate without
# touching repo objects.
set -eu

reposdir="/volume/git-mirror/repos"
sitedir="/volume/git-mirror/site"
baseurl="https://forge.eblu.me"

mkdir -p "$reposdir" "$sitedir"

# Shared assets — the volume may be fresh or recycled.
for a in style.css logo.png favicon.png; do
    [ -e "$sitedir/$a" ] || cp "/usr/share/git-mirror/assets/$a" "$sitedir/$a"
done

fix_head() {
    # Point an unborn HEAD at main (or the first existing branch) so
    # stagit and dumb HTTP resolve the default branch.
    r="$1"
    if ! git --git-dir="$r" rev-parse --verify -q HEAD >/dev/null 2>&1; then
        b=$(git --git-dir="$r" for-each-ref --format='%(refname)' refs/heads/ | sed -n '1p')
        if [ "$(git --git-dir="$r" for-each-ref --format='%(refname)' refs/heads/main)" = "refs/heads/main" ]; then
            b="refs/heads/main"
        fi
        if [ -n "$b" ]; then
            git --git-dir="$r" symbolic-ref HEAD "$b"
        fi
    fi
}

# Prune bare repos that dropped out of the allowlist: a drop is a file
# edit + redeploy, and the site/info-refs loops below iterate the volume
# dir, so a stale repo would otherwise keep being served.
for repo in "$reposdir"/*/*.git; do
    [ -d "$repo" ] || continue
    rel="${repo#"$reposdir"/}"; rel="${rel%.git}"
    [ -n "$rel" ] || continue
    if ! grep -qxF "$rel" /usr/share/git-mirror/repos; then
        rm -rf "$repo" "$sitedir/${rel:?}"
        echo "pruned dropped repo: $rel"
    fi
done

n=0
while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    owner=${entry%%/*}
    name=${entry##*/}
    mkdir -p "$reposdir/$owner"
    if [ ! -d "$reposdir/$owner/$name.git" ]; then
        git init --bare --quiet "$reposdir/$owner/$name.git"
    fi
    repo="$reposdir/$owner/$name.git"
    # stagit reads these top-level files for the page header (clone URL),
    # and every bare repo needs the post-receive hook installed.
    printf '%s\n' "$baseurl/$owner/$name.git" > "$repo/url"
    cp /usr/local/share/git-mirror/post-receive "$repo/hooks/post-receive"
    chmod +x "$repo/hooks/post-receive"
    fix_head "$repo"
    # See post-receive: keep clones on packs; skip empty repos — repacking those fails.
    if git --git-dir="$repo" rev-parse -q --verify HEAD >/dev/null 2>&1; then
        git --git-dir="$repo" repack -a -d
    fi
    n=$((n+1))
done < /usr/share/git-mirror/repos

# Regenerate the static site. stagit only renders commits newer than the
# HEAD recorded in .htmlcache, and post-receive leaves a fresh cache
# after every push, so boot is incremental: a repo whose HEAD matches
# its cache is skipped (its symlinks are re-touched regardless). First
# run per repo (fresh volume, allowlist change) has no cache and builds
# the whole history — the slow path, taken once per repo.
for repo in "$reposdir"/*/*.git; do
    [ -d "$repo" ] || continue
    o=$(basename "$(dirname "$repo")")
    n2=${repo##*/}; n2=${n2%.git}
    mkdir -p "$sitedir/$o/$n2"
    (
        cd "$sitedir/$o/$n2"
        head=$(git --git-dir="$repo" rev-parse -q --verify HEAD 2>/dev/null || true)
        cached=$(head -1 .htmlcache 2>/dev/null || true)
        # The .baseurl marker forces a one-time rebuild whenever the clone
        # baseurl the HTML embeds changes (the cutover, staging ->
        # forge.eblu.me): stagit only renders newer commits, so a HEAD match
        # would skip it and the pages would keep the old hostname. post-receive
        # regenerates the whole thing per push, so this only matters at boot.
        if [ -n "$head" ] && [ "$head" = "$cached" ] && [ -f log.html ] && [ "$(cat .baseurl 2>/dev/null)" = "$baseurl" ]; then
            exit 0
        fi
        rm -f .htmlcache
        rm -rf commit file
        stagit -c .htmlcache -u "$baseurl" "$repo" >/dev/null
        printf '%s\n' "$baseurl" > .baseurl
    )
    cd "$sitedir/$o/$n2"
    ln -sf log.html index.html
    ln -sf ../../style.css style.css
    ln -sf ../../logo.png logo.png
    ln -sf ../../favicon.png favicon.png
done

sh /usr/local/share/git-mirror/gen-index.sh "$reposdir" "$sitedir"

# Dumb HTTP: refresh info/refs for every mirrored repo.
for repo in "$reposdir"/*/*.git; do
    [ -d "$repo" ] || continue
    ( cd "$repo" && git update-server-info )
done

# The mirror user owns everything under the mirror dir: SSH pushes land
# as `mirror` (git refuses ref updates under root-owned directories) and
# the hook regenerates the site. Every boot re-runs this as root, so the
# chown must cover the site, not just the repos.
chown -R mirror:mirror /volume/git-mirror

echo "git-mirror ready: $n repositories under $reposdir"
