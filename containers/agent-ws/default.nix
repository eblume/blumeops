# Nix-built image for the containerized ringtail-agent workspace.
#
# This carries the agent's *toolchain* only. `claude` itself is NOT baked in —
# Remote Control moves fast and is self-updating, so (per the decision in
# [[agent-containerization]]) it installs at pod-start onto the persistent PVC
# via Anthropic's official installer, exactly as the host model installs it into
# ~agent/.local/bin today. The image rebuilds only when the toolchain changes,
# not on every claude release.
#
# Two things make this different from a normal app container, both handled
# below and flagged for the on-box smoke test:
#   1. `claude` (and mise's prebuilt rust) are dynamically-linked ELF binaries;
#      a pure dockerTools image is non-FHS, so we symlink the glibc loader and
#      expose a runtime LD_LIBRARY_PATH — the container analogue of nix-ld.
#   2. Remote Control needs a PTY; the entrypoint runs it under `script`.
#
# Built by the standard `Build Container` workflow on nix-container-builder,
# pushed to registry.ops.eblu.me — same as every other container here.
#
# Self-pins nixos-unstable (navidrome/mealie precedent); reuses the shared
# pinned rev+hash so no new hash fetch is needed.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/241313f4e8e508cb9b13278c2b0fa25b9ca27163.tar.gz";
    sha256 = "09d83cyl9dlfkkbspkgkk7bfydj3mvw6r1x98kvc2v8wl2xd8ldy";
  };
  # allowUnfree: the 1Password CLI (_1password-cli) is unfree.
  pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
  lib = pkgs.lib;

  # Toolchain-schema version for the image tag (the Build Container workflow
  # requires a `version = "…"` to form v<version>-<sha>-nix). There is no
  # upstream version to track — claude self-installs at pod-start — so bump this
  # by hand when the baked toolchain changes meaningfully.
  version = "0.18.0";

  # ── the repo pool, from ../../repos.json ──────────────────────────────────
  # That file is the single source of truth for BOTH halves of "share a repo
  # with the agent": the forge collaborator grant (reconciled by
  # `mise run agent-repo-access`) and the clone loop below. Keeping them in one
  # file is the point — they used to drift, and a missing grant is invisible
  # (Forgejo 404s rather than 403s on a private repo the bot cannot see).
  repoPolicy = builtins.fromJSON (builtins.readFile ../../repos.json);
  poolOf = p: builtins.filter (r: r.pool == p) repoPolicy.repos;
  forkRepos = map (r: r.name) (poolOf "fork");
  canonicalRepos = map (r: r.name) (poolOf "canonical");
  # `<name>:<pool>` pairs for agent-ws-workspace, which needs the pool kind to
  # know which remote is canonical (fork → upstream, canonical → origin).
  repoPairs = lib.concatMapStringsSep " " (r: "${r.name}:${r.pool}")
    (builtins.filter (r: r.pool != "none") repoPolicy.repos);

  # ── the curated toolchain (mirrors nixos/ringtail/agent-workspaces.nix) ──────
  # op: real 1Password CLI. In a pod the service-account token arrives as
  #   OP_SERVICE_ACCOUNT_TOKEN from a k8s Secret, so plain `op` works — the host
  #   op-shim (which injected the token from a file) is unnecessary here.
  # report toolchain: mise + uv drive research's `uv run --script` tasks; pandoc/
  #   typst/weasyprint for document conversion (weasyprint's native libs go on
  #   LD_LIBRARY_PATH via reportLibs in the entrypoint).
  # cli toolbox: the staples a shell agent reaches for (awk/jq/curl/python3).
  # build toolchain: gcc/binutils/pkg-config/make so `cargo build` links; rust
  #   itself still comes from mise (nixpkgs rustc lags), same as the host.
  reportTools = with pkgs; [ mise uv pandoc typst python3Packages.weasyprint ];
  reportLibs = with pkgs; [ pango glib harfbuzz fontconfig freetype gdk-pixbuf cairo libffi ];
  cliTools = with pkgs; [ gawk jq curl python3 ];
  buildTools = with pkgs; [ gcc binutils pkg-config gnumake ];
  # Bevy's Linux native deps, for the `gamedev` workspace (added to the pool in
  # the same change). Containerization dropped these — the retired host launcher
  # had them and `containers/agent-ws/` was never given the equivalent — so a
  # mise-provided rust toolchain linked an ordinary crate fine while `cargo
  # check` on gamedev died in a -sys build script.
  #
  # Unlike WeasyPrint's Pango stack (pure run-time dlopen), this set needs BOTH
  # paths, and the split is not the one the host file's comment implied. Two
  # crates in gamedev's lockfile pkg-config-probe at BUILD time — `alsa-sys`
  # (alsa) and `wayland-sys` (wayland-client) — the second of which the host
  # file did NOT cover, having assumed every windowing lib was dlopen'd. So
  # PKG_CONFIG_PATH gets the dev output of the whole set rather than a
  # hand-picked subset: a .pc file that no build script asks for costs nothing,
  # whereas a missing one is a hard build failure, and the probe set is a
  # property of Bevy's feature flags that will drift.
  gameLibs = with pkgs; [
    alsa-lib wayland libxkbcommon udev vulkan-loader libGL
    xorg.libX11 xorg.libXcursor xorg.libXi xorg.libXrandr
  ];
  baseTools = with pkgs; [
    _1password-cli git openssh coreutils bash cacert tzdata
    gnused gnugrep gnutar gzip which findutils
  ];

  # ── nix, deliberately eval-only ───────────────────────────────────────────
  # The pod cannot run a real nix build and is not meant to. Two independent
  # reasons, both measured from inside it: uid 1500 cannot write the image's
  # root-owned /nix/store (and there is no /nix/var at all), and the
  # RuntimeDefault seccomp profile refuses CLONE_NEWUSER — so there is no build
  # sandbox, and no local chroot store either (`--store /path` needs
  # CAP_SYS_CHROOT, and every capability is dropped).
  #
  # What does work is a store relocated into $HOME, which needs none of that:
  # evaluation, plus the evaluator-side fetchers (builtins.fetchTarball /
  # fetchGit, nix-prefetch-url), none of which runs a builder. That is exactly
  # the capability containerization dropped — on the shared host the agent
  # reached nix at /run/current-system/sw/bin and used it to prove a change
  # evaluates and to discover a real hash, instead of committing lib.fakeSha256
  # and burning Build Container rounds to find one.
  #
  # Relocating store-dir rewrites every store path's hash, so cache.nixos.org
  # can never answer for this store: a `nix-build` here would compile the world
  # from source inside the agent's cgroup. max-jobs = 0 turns that into an
  # immediate error instead of an hours-long surprise. It is a foot-gun guard,
  # not a boundary — the boundary is that nothing this store produces can reach
  # ringtail: the host's /nix is not mounted into the pod (the only hostPath is
  # the heph socket dir), and there is no remote builder to push to.
  #
  # Nothing here ever creates a GC root, so the store is pure cache: it is swept
  # on size by `agent-ws-workspace gc` (pod boot, and every session start).
  nixStateDir = "/home/agent/.local/state/nix";
  nixConfDir = pkgs.writeTextDir "nix.conf" ''
    experimental-features = nix-command flakes
    # Nothing in a relocated store can be substituted; asking is pure latency.
    substituters =
    # Eval and fetch, never build. Override per-invocation if you truly mean it.
    max-jobs = 0
    # No CLONE_NEWUSER in this pod — nix could not set the sandbox up anyway.
    sandbox = false
    warn-dirty = false
  '';

  # tea, wrapped to route through the tag:agent SOCKS sidecar. tea only ever
  # contacts the forge (forge.ops.eblu.me), which the pod can reach ONLY via the
  # proxy, and tea (unlike git) has no per-URL proxy config — so send all of
  # tea's traffic through the proxy. A GLOBAL proxy would be wrong (it'd break
  # claude↔Anthropic and op↔1Password, which must egress directly), hence a
  # tea-specific wrapper. Shadows pkgs.tea on PATH.
  teaWrapper = pkgs.writeShellScriptBin "tea" ''
    export HTTPS_PROXY="socks5h://localhost:1055"
    export HTTP_PROXY="socks5h://localhost:1055"
    exec ${pkgs.tea}/bin/tea "$@"
  '';

  # Prebuilt-binary runtime libs (claude, mise's rust): glibc provides the loader
  # we symlink below; libstdc++ + zlib cover the common dynamic deps. Exposed on
  # LD_LIBRARY_PATH in the entrypoint.
  ldLibs = with pkgs; [ glibc stdenv.cc.cc.lib zlib ];

  # heph CLI, baked in and built against THIS image's nixpkgs so it runs natively
  # (the host's cargo binary won't — its ELF interpreter is a host nix-store glibc
  # path absent here). The pod runs NO hephd; it shares the host agent-heph-spoke
  # daemon via a hostPath-mounted socket (see the Deployment). Build only the
  # `heph` crate — hephd + the GUI crate aren't needed. Pinned to hephTag v1.7.0
  # (matches nixos/ringtail/heph-common.nix). nixpkgs rustc (1.96) clears heph's
  # 1.89 floor, and the lockfile has no git deps, so nix vendors cleanly.
  hephSrc = pkgs.fetchgit {
    url = "https://forge.eblu.me/eblume/hephaestus.git";
    rev = "refs/tags/v1.7.0";
    hash = "sha256-M/wjIWX9Vg4YyItCf18UFgLjzEC6TGlbPJn26iRv7mw=";
  };
  heph = pkgs.rustPlatform.buildRustPackage {
    pname = "heph";
    version = "1.7.0";
    src = hephSrc;
    cargoLock.lockFile = hephSrc + "/Cargo.lock";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.dbus pkgs.openssl pkgs.sqlite pkgs.zlib ];
    cargoBuildFlags = [ "-p" "heph" ];
    doCheck = false;
  };

  # Liveness check for the Deployment's exec probe. The failure mode it catches
  # is a ZOMBIE, not a crash (observed 2026-08-01): remote-control survives a
  # WAN blip as a process but never re-dials Anthropic, so k8s sees a healthy
  # container while every Claude client sees a dead server. Crashes already
  # self-heal (claude exits → script exits → container restarts).
  #
  # Signal: some claude process holds ≥1 ESTABLISHED TCP connection. A healthy
  # remote-control keeps a persistent gateway websocket even when idle; the
  # zombie held only unix sockets. /proc/net/tcp* is netns-WIDE (shared with
  # the ts sidecar, whose control-plane conns are always up), so we must match
  # per-process socket-fd inodes against ESTABLISHED (state 01) rows rather
  # than testing the table globally. arg0-matching skips pid 1 (`script`, whose
  # argv merely *mentions* claude) but covers both the launcher
  # (~/.local/bin/claude) and version binaries (~/.local/share/claude/versions/…).
  healthCheck = pkgs.writeShellScriptBin "agent-ws-health" ''
    est=" $(${pkgs.gawk}/bin/awk '$4=="01" {print $10}' /proc/net/tcp /proc/net/tcp6 2>/dev/null | tr '\n' ' ') "
    for p in /proc/[0-9]*; do
      arg0=$(tr '\0' '\n' < "$p/cmdline" 2>/dev/null | head -n1)
      case "$arg0" in *claude*) ;; *) continue ;; esac
      for f in "$p"/fd/*; do
        s=$(readlink "$f" 2>/dev/null) || continue
        case "$s" in "socket:["*) i="''${s#socket:[}"; i="''${i%]}" ;; *) continue ;; esac
        case "$est" in *" $i "*) exit 0 ;; esac
      done
    done
    echo "agent-ws-health: no claude process holds an established TCP connection" >&2
    exit 1
  '';

  # ── per-session workspace isolation ──────────────────────────────────────
  # Only the `agents` repo gets per-session isolation for free: Remote Control's
  # `--spawn worktree` operates on its own cwd repo and nothing else. Every other
  # pooled repo is ONE shared checkout, so two concurrent sessions editing e.g.
  # blumeops contend for one HEAD and one index — today that is prevented only by
  # a paragraph of prose in the agents repo's AGENTS.md.
  #
  # This gives each session a linked worktree of every pooled repo, detached at
  # canonical main, and reaps them when the session is gone. Worktrees (not
  # clones) because they share the object store and, more importantly, enforce
  # one-branch-one-checkout at the git level rather than by convention.
  #
  #   agent-ws-workspace sync   fetch + fast-forward the pool onto canonical main
  #   agent-ws-workspace init   per-repo sync, then this session's worktrees
  #   agent-ws-workspace gc     reap worktrees whose session has ended, and
  #                             sweep the nix eval store if it has grown
  #
  # `init` is the SessionStart hook (seeded into ~/.claude/settings.json by the
  # entrypoint); the entrypoint also runs `sync` then `gc` once at pod boot.
  # `init` re-runs gc, but syncs each repo inline via sync_repo rather than
  # calling the sync verb — `worktree add` needs that repo's fetch first.
  workspace = pkgs.writeShellScriptBin "agent-ws-workspace" ''
    set -eu

    # Hooks inherit whatever PATH the session has; don't depend on it.
    export PATH="${lib.makeBinPath (with pkgs; [ git jq gawk coreutils findutils ])}:$PATH"

    # `<name>:<pool>` pairs generated from repos.json — deliberately word-split.
    REPOS="${repoPairs}"
    POOL="$HOME/code/personal"
    SESSIONS="$HOME/code/sessions"
    GC_AGE_DAYS="''${AGENT_WS_GC_AGE_DAYS:-7}"
    GC_LOCK_MAX_DAYS="''${AGENT_WS_GC_LOCK_MAX_DAYS:-30}"
    # Sweep the eval store above this. Sized to hold a working set of two or
    # three unpacked nixpkgs trees (~600MiB each — every container's self-pinned
    # fetchTarball is another one) while keeping $HOME inside the PVC's declared
    # 20Gi, which the local-path provisioner does not enforce for us.
    NIX_STORE_MAX_MB="''${AGENT_WS_NIX_STORE_MAX_MB:-6144}"

    warn() { echo "agent-ws-workspace: $*" >&2; }

    # A fork pool reads canonical through `upstream` and pushes the bot's fork as
    # `origin`; a canonical pool has origin == canonical. Getting this backwards
    # is the "up to date with origin/main" trap — on a fork that sentence is
    # about the fork, which may be arbitrarily far behind eblume/<repo>.
    canon_remote() {
      case "$1" in
        fork) echo upstream ;;
        *) echo origin ;;
      esac
    }

    sync_repo() {
      name="$1"; kind="$2"
      repo="$POOL/$name"
      if [ ! -d "$repo/.git" ]; then
        warn "$name: no pool checkout — skipped"
        return 0
      fi
      remote="$(canon_remote "$kind")"

      git -C "$repo" fetch --quiet --prune --all 2>/dev/null || {
        warn "$name: fetch failed — using the refs already on disk"
        return 0
      }

      # Pin the pool's own main to canonical main. Fast-forward only, and only
      # when the checkout is clean: a diverged or dirty pool tree is somebody's
      # in-flight work, not ours to move.
      head="$(git -C "$repo" symbolic-ref --quiet --short HEAD || true)"
      if [ "$head" = main ] && [ -z "$(git -C "$repo" status --porcelain)" ]; then
        git -C "$repo" merge --quiet --ff-only "$remote/main" 2>/dev/null \
          || warn "$name: pool main is not a fast-forward of $remote/main — left alone"
      fi

      # A fork whose main lags canonical makes every cross-repo PR diff look
      # wrong and makes `git status` read as fresh when it is not. The bot owns
      # the fork, so keep its main honest. Non-fast-forward means the fork has
      # commits of its own; that is a human's problem, not a boot-time one.
      if [ "$kind" = fork ]; then
        git -C "$repo" push --quiet origin \
          "refs/remotes/upstream/main:refs/heads/main" 2>/dev/null \
          || warn "$name: could not fast-forward the fork's main"
      fi
    }

    # The session id is the directory Remote Control spawned us into, which is
    # also how gc correlates a session's sibling worktrees with its liveness.
    session_id() {
      dir="''${CLAUDE_PROJECT_DIR:-$PWD}"
      rest="''${dir#"$POOL/agents/.claude/worktrees/"}"
      if [ "$rest" = "$dir" ]; then echo ""; else echo "''${rest%%/*}"; fi
    }

    # Unpushed work is worth more than the disk it sits on: dirty tree, or any
    # commit canonical main does not already contain, means hands off.
    has_work() {
      wt="$1"; base="$2"
      [ -d "$wt" ] || return 1
      [ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ] || return 0
      [ "$(git -C "$wt" rev-list --count "$base..HEAD" 2>/dev/null || echo 0)" = 0 ] || return 0
      return 1
    }

    reap_session() {
      sid="$1"; dir="$2"; root="$SESSIONS/$sid"
      if has_work "$dir" upstream/main; then
        warn "$sid: agents worktree carries unmerged work — kept"
        return 0
      fi
      for entry in $REPOS; do
        name="''${entry%%:*}"; kind="''${entry##*:}"
        if [ "$name" = agents ]; then continue; fi
        if has_work "$root/$name" "$(canon_remote "$kind")/main"; then
          warn "$sid/$name: unmerged work — session kept"
          return 0
        fi
      done
      for entry in $REPOS; do
        name="''${entry%%:*}"
        if [ "$name" = agents ]; then continue; fi
        if [ -e "$root/$name" ]; then
          git -C "$POOL/$name" worktree remove --force "$root/$name" 2>/dev/null || true
        fi
      done
      rm -rf "$root"
      git -C "$POOL/agents" worktree remove --force "$dir" 2>/dev/null || rm -rf "$dir"
      git -C "$POOL/agents" branch -D "worktree-$sid" 2>/dev/null || true
      echo "agent-ws-workspace: reaped session $sid" >&2
    }

    cmd_gc() {
      nix_store_gc

      agents="$POOL/agents"
      [ -d "$agents/.git" ] || return 0

      # Remote Control locks a worktree for the life of its session, so `locked`
      # is the liveness signal. A crashed session leaves the lock behind
      # forever, hence the much longer lock-override age.
      locked="$(git -C "$agents" worktree list --porcelain 2>/dev/null \
        | awk '/^worktree /{p=$2} /^locked/{print p}')"

      for dir in "$agents"/.claude/worktrees/*; do
        [ -d "$dir" ] || continue
        sid="$(basename "$dir")"
        case " $locked " in
          *" $dir "*)
            [ -n "$(find "$dir" -maxdepth 0 -mtime +"$GC_LOCK_MAX_DAYS" 2>/dev/null)" ] || continue
            warn "$sid: lock is >''${GC_LOCK_MAX_DAYS}d old — treating as dead"
            ;;
        esac
        [ -n "$(find "$dir" -maxdepth 0 -mtime +"$GC_AGE_DAYS" 2>/dev/null)" ] || continue
        reap_session "$sid" "$dir"
      done

      for entry in $REPOS; do
        git -C "$POOL/''${entry%%:*}" worktree prune 2>/dev/null || true
      done
    }

    # The eval store has no GC roots to age out: nothing here runs `nix-build -o
    # result`, and an instantiate's temp roots die with the process. So a sweep
    # is all-or-nothing — it empties the store and the next eval re-fetches
    # nixpkgs (a minute or two). Size is therefore the only sane trigger: sweep
    # when it has grown enough to matter, rather than on a clock that keeps
    # throwing away a warm store somebody is still using.
    nix_store_gc() {
      store="''${NIX_STORE_DIR:-$HOME/.local/state/nix/store}"
      [ -d "$store" ] || return 0
      size_mb="$(du -sm "$store" 2>/dev/null | cut -f1)" || return 0
      [ "''${size_mb:-0}" -gt "$NIX_STORE_MAX_MB" ] 2>/dev/null || return 0

      warn "nix eval store is ''${size_mb}MiB (>''${NIX_STORE_MAX_MB}) — collecting"
      ${pkgs.nix}/bin/nix-collect-garbage >/dev/null 2>&1 \
        || warn "nix-collect-garbage failed (continuing)"
      # Not covered by nix-collect-garbage: the fetcher caches, where flake
      # inputs land as a bare git repo that only ever grows.
      rm -rf "$HOME/.cache/nix"
    }

    cmd_sync() {
      for entry in $REPOS; do sync_repo "''${entry%%:*}" "''${entry##*:}"; done
    }

    cmd_init() {
      sid="$(session_id)"
      if [ -z "$sid" ]; then
        warn "not inside a session worktree ($PWD) — nothing to do"
        return 0
      fi
      root="$SESSIONS/$sid"
      mkdir -p "$root"
      cmd_gc || true

      made=""
      for entry in $REPOS; do
        name="''${entry%%:*}"; kind="''${entry##*:}"
        sync_repo "$name" "$kind" || true

        # `agents` already has this session's worktree — Remote Control made it,
        # off whatever the pool's main was at spawn. On a long-lived pod that is
        # stale by however long the pod has been up, and the staleness is in the
        # session's own instructions, so fast-forward it too.
        if [ "$name" = agents ]; then
          wt="$POOL/agents/.claude/worktrees/$sid"
          if [ -d "$wt" ] && [ -z "$(git -C "$wt" status --porcelain)" ]; then
            git -C "$wt" merge --quiet --ff-only upstream/main 2>/dev/null || true
          fi
          continue
        fi

        if [ ! -e "$root/$name" ]; then
          git -C "$POOL/$name" worktree add --quiet --detach "$root/$name" \
            "$(canon_remote "$kind")/main" 2>/dev/null || {
              warn "$name: worktree add failed — fall back to the shared pool checkout"
              continue
            }
        fi
        made="$made $name"
      done

      list=""
      for name in $made; do list="$list
      $root/$name"; done
      jq -n --arg c "Per-session checkouts (this session only, detached at canonical main):$list

Work in those, NOT in ~/code/personal/<repo> — the pool is shared with any
concurrent session and is kept pinned to canonical main. Branch before you
commit: git -C $root/<repo> switch -c agent/<slug>. Push goes to 'origin'
(the bot's fork for agents/blumeops, canonical for the rest)." \
        '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
    }

    case "''${1:-init}" in
      init) cmd_init ;;
      sync) cmd_sync ;;
      gc) cmd_gc ;;
      *) warn "usage: agent-ws-workspace {init|sync|gc}"; exit 2 ;;
    esac
  '';

  allTools = baseTools ++ reportTools ++ cliTools ++ buildTools
    ++ [ pkgs.nix heph teaWrapper healthCheck workspace ];

  # ── entrypoint ───────────────────────────────────────────────────────────
  # Fuses the host's reposInit + wsRunner + claude-install into one pod entry.
  # Path/secret assumptions are env-overridable so the Deployment owns the
  # concrete mount points:
  #   HOME                        persistent PVC (claude, OAuth cred, repo pool)
  #   OP_SERVICE_ACCOUNT_TOKEN    agents-vault token (k8s Secret, envFrom)
  # Git talks to the forge over HTTPS+token through the SOCKS sidecar (no ssh
  # key needed — see the git config in the entrypoint body).
  # forge/fork bases match the host launcher (canonical read via upstream, push
  # to the agents/ fork).
  entrypoint = pkgs.writeShellScriptBin "agent-ws-entrypoint" ''
    set -eu
    export HOME="''${HOME:-/home/agent}"
    export PATH="${lib.makeBinPath allTools}:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export TZDIR="${pkgs.tzdata}/share/zoneinfo"

    # Dynamic-loader shim for prebuilt binaries (claude, mise rust). See ldLibs.
    # Also carries WeasyPrint's Pango stack and the Bevy libs gamedev dlopen's.
    export LD_LIBRARY_PATH="${lib.makeLibraryPath (ldLibs ++ reportLibs ++ gameLibs)}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # Native build env (cargo linker + weasyprint render path already covered by
    # LD_LIBRARY_PATH above). PKG_CONFIG_PATH carries the dev outputs of gameLibs
    # so -sys build scripts (alsa-sys, wayland-sys) can probe them.
    export CC=gcc
    export PKG_CONFIG_PATH="${lib.makeSearchPath "lib/pkgconfig" (map lib.getDev gameLibs)}''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export MISE_TRUSTED_CONFIG_PATHS="$HOME/code/personal:$HOME/code/sessions"

    # One cargo target dir for every checkout. Per-session worktrees otherwise
    # each build from cold — minutes for Bevy — and a `target/` per worktree per
    # session fills a 20Gi PVC fast. Cargo takes a lock on the directory, so
    # concurrent builds serialize rather than corrupt each other.
    export CARGO_TARGET_DIR="$HOME/.cache/cargo-target"
    mkdir -p "$CARGO_TARGET_DIR"

    # 1Password CLI in a pod (learned the hard way): beyond the /etc/passwd entry
    # baked into the image, op needs a TMPDIR it owns (the container /tmp is
    # root-owned, which op's SingleUserEnvironment check rejects) and all of its
    # state at 0600/0700. fsGroup makes new files group-accessible, and op
    # refuses any group-readable config OR session file. Both dirs persist on the
    # PVC, so a stale 0660 file from a prior pod breaks op on the next boot —
    # patching perms piecemeal is unreliable (op has config + daemon + session
    # files). Reset op's state entirely each boot and let umask 077 recreate it
    # 0600/0700. op is a stateless service-account client, so this is free.
    umask 077
    export TMPDIR="$HOME/.optmp"
    rm -rf "$HOME/.config/op" "$TMPDIR"
    mkdir -p "$TMPDIR"

    # Git identity for the bot's commits.
    export GIT_AUTHOR_NAME=agents GIT_AUTHOR_EMAIL=blume.erich+agents@gmail.com
    export GIT_COMMITTER_NAME=agents GIT_COMMITTER_EMAIL=blume.erich+agents@gmail.com

    # Git over HTTPS+token through the tag:agent SOCKS sidecar — NOT ssh. The
    # forge bot SSH key lives in the agents vault, which external-secrets can't
    # reach; the FORGEJO_TOKEN (op-read below) authenticates over HTTPS instead,
    # and HTTPS-via-SOCKS avoids the ssh-over-SOCKS ProxyCommand dance entirely.
    # Only forge.ops.eblu.me routes through the proxy (tag:agent can reach ONLY
    # indri); public hosts (claude.ai, 1Password, forge.eblu.me) go direct.
    git config --global "http.https://forge.ops.eblu.me/.proxy" "socks5h://localhost:1055"
    git config --global "credential.https://forge.ops.eblu.me.username" "agents"
    askpass="$HOME/.git-askpass"
    printf '#!/bin/sh\nexec printf "%%s" "$FORGEJO_TOKEN"\n' > "$askpass"
    chmod 700 "$askpass"
    export GIT_ASKPASS="$askpass"

    forge="https://forge.ops.eblu.me/eblume"
    fork="https://forge.ops.eblu.me/agents"
    code="$HOME/code/personal"
    mkdir -p "$code"

    # ── install/update claude onto the PVC (self-updating installer) ──────────
    if [ ! -x "$HOME/.local/bin/claude" ]; then
      echo "agent-ws: installing claude via official installer…" >&2
      curl -fsSL https://claude.ai/install.sh | bash
    fi

    # ── Anthropic auth: the PVC OAuth login, rotated on a 5-day cadence ───────
    # Do NOT export CLAUDE_CODE_OAUTH_TOKEN here. Remote Control refuses
    # long-lived `claude setup-token` credentials outright — claude exits at
    # startup with "Remote Control requires a full-scope login token.
    # Long-lived tokens … are limited to inference-only for security reasons."
    # v0.16.0 exported exactly such a token and crash-looped on the startup
    # probe (2026-08-07); an inference call succeeding with the token proves
    # nothing about Remote Control, which is how that regression got shipped.
    #
    # Auth is therefore the interactive `claude auth login` credential at
    # ~/.claude/.credentials.json on the PVC. Its refresh token hard-expires ~7
    # days after login and refresh tokens are single-use (upstream #24317), so
    # a 5-day recurring heph chore re-runs the login before it dies — the
    # runbook is docs/how-to/ringtail/rotate-agent-ws-claude-login.md. An
    # expired credential is still invisible to agent-ws-health (websocket stays
    # ESTABLISHED); detection remains a Known wart in [[agent-workspaces]].

    # ── FORGEJO_TOKEN + tea config (op reads the agents-vault PAT) ────────────
    FORGEJO_TOKEN="$(op read "op://agents/agents-forgejo-token/api-token" </dev/null 2>/dev/null || true)"
    export FORGEJO_TOKEN
    install -d -m 700 "$HOME/.config/tea"
    printf 'logins:\n  - name: forge\n    url: https://forge.ops.eblu.me\n    token: %s\n    default: true\n' \
      "$FORGEJO_TOKEN" > "$HOME/.config/tea/config.yml"
    chmod 600 "$HOME/.config/tea/config.yml"

    # ── repo pool: primary + siblings (canonical), blumeops via fork ──────────
    clone_repo() {
      dest="$code/$1"
      if [ -d "$dest/.git" ]; then git -C "$dest" fetch --quiet --all --prune || true
      else git clone --quiet "$forge/$1.git" "$dest"; fi
    }
    clone_fork() {
      dest="$code/$1"
      [ -d "$dest/.git" ] || git clone --quiet "$fork/$1.git" "$dest"
      git -C "$dest" remote set-url origin "$fork/$1.git" 2>/dev/null || git -C "$dest" remote add origin "$fork/$1.git"
      if git -C "$dest" remote | grep -qx upstream; then git -C "$dest" remote set-url upstream "$forge/$1.git"
      else git -C "$dest" remote add upstream "$forge/$1.git"; fi
      git -C "$dest" fetch --quiet --all --prune || true
    }
    # Non-fatal: a clone failure (proxy not ready, etc.) must not abort the
    # entrypoint before Remote Control starts — otherwise the pod crashloops
    # with no way to seed the OAuth login. Warn and continue.
    #
    # Wait for the tag:agent sidecar's SOCKS proxy to route before any git op:
    # the userspace tailscale sidecar takes ~15s to authenticate + establish
    # WireGuard, and git otherwise fails "cannot complete SOCKS5 connection to
    # forge.ops.eblu.me". Bounded (~90s) so a broken sidecar can't hang boot.
    echo "agent-ws: waiting for the tag:agent SOCKS proxy…" >&2
    for _ in $(seq 1 45); do
      curl -sf --max-time 4 -x socks5h://localhost:1055 https://forge.ops.eblu.me/ -o /dev/null 2>/dev/null && break
      sleep 2
    done

    # agents (the home-base instruction substrate) and blumeops both use the
    # FORK model: origin = agents/<repo> (the bot owns it → token push works),
    # upstream = eblume/<repo> (canonical, fetched read-only). Edits go via
    # cross-repo PR — a human gate on changes to the agent's own instructions.
    # The siblings are ordinary author repos cloned canonically.
    #
    # Both lists are GENERATED from ../../repos.json — edit that, not this. Most of
    # these are PRIVATE forge repos; they clone over HTTPS with the bot's token
    # only while `agents` is a collaborator, which the same file drives.
    for r in ${lib.escapeShellArgs forkRepos}; do
      clone_fork "$r" || echo "agent-ws: clone $r fork failed (continuing)" >&2
    done
    for r in ${lib.escapeShellArgs canonicalRepos}; do
      clone_repo "$r" || echo "agent-ws: clone $r failed (continuing)" >&2
    done

    # ── per-session workspace isolation ──────────────────────────────────────
    # The SessionStart hook goes in USER settings on the PVC, not in the agents
    # repo as project settings: project-scoped hooks prompt for trust on first
    # use and there is nobody at a terminal in this pod. jq-merged so the rest of
    # the file survives, and re-seeded every boot so the image stays the source
    # of truth for it (per the "changing your own environment is a blumeops PR"
    # rule in the agents repo).
    install -d -m 700 "$HOME/.claude"
    settings="$HOME/.claude/settings.json"
    [ -s "$settings" ] || echo '{}' > "$settings"
    if jq '.hooks.SessionStart = [{"hooks":[{"type":"command","command":"agent-ws-workspace init","timeout":180}]}]' \
         "$settings" > "$settings.tmp" 2>/dev/null; then
      mv "$settings.tmp" "$settings"
      chmod 600 "$settings"
    else
      rm -f "$settings.tmp"
      echo "agent-ws: could not seed the SessionStart hook (continuing)" >&2
    fi

    # Pin the pool to canonical main, then reap worktrees left behind by sessions
    # that ended — nothing else does, and they accumulate for the life of the PVC.
    agent-ws-workspace sync || echo "agent-ws: pool sync failed (continuing)" >&2
    agent-ws-workspace gc || echo "agent-ws: worktree gc failed (continuing)" >&2

    # ── launch Remote Control under a PTY (no --headless flag yet) ────────────
    # AGENT_WS_RC_FLAGS is a Deployment-settable escape hatch (e.g. "--verbose"
    # for detailed connection/session logs) so diagnostics can be toggled
    # without an image rebuild — post-2026-08-01-zombie observability lever.
    cd "$code/agents" 2>/dev/null || cd "$HOME"
    export CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=ringtail
    exec ${pkgs.util-linux}/bin/script -qfc \
      "$HOME/.local/bin/claude remote-control --spawn worktree --name ringtail-agent ''${AGENT_WS_RC_FLAGS:-}" /dev/null
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/agent-ws";
  tag = "v${version}";

  contents = allTools ++ [ entrypoint pkgs.util-linux ];

  # Non-FHS fixups: the dynamic loader at its conventional path (so prebuilt
  # ELF binaries run), /usr/bin/env (the kernel resolves shebang interpreters
  # literally, so `#!/usr/bin/env …` needs the file to exist at that path —
  # every mise-task script in blumeops uses that form), a /tmp, and —
  # critically — /etc/passwd + group + nsswitch so uid 1500 resolves to a
  # username. Without a passwd entry, glibc getpwuid fails and the 1Password
  # CLI's ownership checks ("not owned by the current user") reject every op
  # call, breaking op read entirely in the pod.
  extraCommands = ''
    mkdir -p lib64 tmp etc usr/bin
    ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 lib64/ld-linux-x86-64.so.2
    ln -s ${pkgs.coreutils}/bin/env usr/bin/env
    chmod 1777 tmp
    printf 'root:x:0:0:root:/root:/bin/bash\nagent:x:1500:1500:agent:/home/agent:/bin/bash\n' > etc/passwd
    printf 'root:x:0:\nagent:x:1500:\n' > etc/group
    printf 'passwd: files\ngroup: files\nshadow: files\nhosts: files dns\n' > etc/nsswitch.conf
  '';

  config = {
    Entrypoint = [ "${entrypoint}/bin/agent-ws-entrypoint" ];
    Env = [
      # A default PATH so the toolchain is reachable WITHOUT the entrypoint's own
      # PATH setup — for `kubectl exec` sessions (which the pod-agent reaches into
      # for tools) and for the PVC-chown initContainer, which overrides the
      # entrypoint. The entrypoint still sets its own richer PATH at runtime.
      "PATH=${lib.makeBinPath allTools}:/home/agent/.local/bin:/home/agent/.cargo/bin:/bin"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      # nix's store relocated onto the PVC — the whole of what makes nix usable
      # here (see the eval-only block above). Set in the image rather than the
      # entrypoint on purpose: these must hold for every way into the container,
      # and unlike PATH there is no richer runtime version to layer on top. nix
      # creates the directories itself on first use.
      "NIX_STORE_DIR=${nixStateDir}/store"
      "NIX_STATE_DIR=${nixStateDir}/var/nix"
      "NIX_LOG_DIR=${nixStateDir}/var/log/nix"
      "NIX_CONF_DIR=${nixConfDir}"
    ];
    # Matches the agent uid/gid pinned on the host (users.users.agent.uid = 1500).
    User = "1500:1500";
    WorkingDir = "/home/agent";
  };
}
