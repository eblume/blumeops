# Nix-built TeslaMate for ringtail (amd64).
#
# Replaces the Dagger container.py (Elixir+Node builder -> Debian slim).
# TeslaMate is NOT in nixpkgs, so this is a from-scratch beamPackages
# mixRelease: an Elixir/Phoenix release with npm-built assets.
#
# Pinned to the same nixos-unstable rev as paperless/mealie for a
# consistent toolchain. The BEAM combo is pinned to erlang_28 + elixir_1_19
# (= 1.19.5), the build base of upstream's v4.0.0 line; mix.exs has
# required elixir ~> 1.19 since v4.1.0.
#
# Source comes from the forge mirror (supply-chain control), pinned by the
# v4.2.0 tag's sha so builtins.fetchGit needs no hash.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/331800de5053fcebacf6813adb5db9c9dca22a0c.tar.gz";
    sha256 = "1p54fm6dkbq62kpi55cr4wyx7b1nsajpsnjgs64cmp073fwi15f7";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  lib = pkgs.lib;

  version = "4.2.0";

  beamPackages = pkgs.beam.packages.erlang_28;
  elixir = beamPackages.elixir_1_19;

  src = builtins.fetchGit {
    url = "https://forge.ops.eblu.me/mirrors/teslamate.git";
    ref = "refs/tags/v${version}";
    rev = "68ac64623fc53c3603ff168f8f865d16f61f023b";
  };

  # Every hex dep in the v4.2.0 mix.lock: name -> (version, tarball sha256).
  # Regenerate on a version bump by parsing mix.lock; the lock entry
  # "name": {:hex, :atom, "version", "package-sha", builders, deps, "hexpm",
  # "tar-sha256"} carries the fetched tarball's sha256 in the LAST field.
  hexDeps = {
    bunt = { version = "1.0.0"; sha256 = "dc5f86aa08a5f6fa6b8096f0735c4e76d54ae5c9fa2c143e5a1fc7c1cd9bb6b5"; };
    castore = { version = "1.0.20"; sha256 = "940eafbfd8b14bee649f083bc11b3b54ec555b54c3e4ea8213351ff6fee39c10"; };
    cc_precompiler = { version = "0.1.11"; sha256 = "3427232caf0835f94680e5bcf082408a70b48ad68a5f5c0b02a3bea9f3a075b9"; };
    certifi = { version = "2.15.0"; sha256 = "b147ed22ce71d72eafdad94f055165c1c182f61a2ff49df28bcc71d1d5b94a60"; };
    cloak = { version = "1.1.4"; sha256 = "92b20527b9aba3d939fab0dd32ce592ff86361547cfdc87d74edce6f980eb3d7"; };
    cloak_ecto = { version = "1.3.0"; sha256 = "314beb0c123b8a800418ca1d51065b27ba3b15f085977e65c0f7b2adab2de1cc"; };
    combine = { version = "0.10.0"; sha256 = "1b1dbc1790073076580d0d1d64e42eae2366583e7aecd455d1215b0d16f2451b"; };
    cowboy = { version = "2.18.0"; sha256 = "62d0b26abcf455054972b0da242389c69d5982ce5914afb8c344517f667b9600"; };
    cowboy_telemetry = { version = "0.4.0"; sha256 = "7d98bac1ee4565d31b62d59f8823dfd8356a169e7fcbb83831b8a5397404c9de"; };
    cowlib = { version = "2.19.0"; sha256 = "6dc66e3135b229193ea4dcb14294e79520c923d391315c9c962ef0b4bea72356"; };
    credo = { version = "1.7.18"; sha256 = "a189d164685fd945809e862fe76a7420c4398fa288d76257662aecb909d6b3e5"; };
    db_connection = { version = "2.10.2"; sha256 = "510b14482330f1af6490a2fa0efd8d4f1435d1529b165647df22ac0f2df0fa93"; };
    decimal = { version = "2.4.1"; sha256 = "7e618897933a8455f19a727d7c5e50a2c071a544b700e5e724298ecb4340187f"; };
    dialyxir = { version = "1.4.7"; sha256 = "b34527202e6eb8cee198efec110996c25c5898f43a4094df157f8d28f27d9efe"; };
    ecto = { version = "3.13.5"; sha256 = "df9efebf70cf94142739ba357499661ef5dbb559ef902b68ea1f3c1fabce36de"; };
    ecto_sql = { version = "3.13.5"; sha256 = "aa36751f4e6a2b56ae79efb0e088042e010ff4935fc8684e74c23b1f49e25fdc"; };
    elixir_make = { version = "0.10.0"; sha256 = "dc1f09fb7fa68866b886abd5f0f3c83553b1a19a52359a899e92af1bb3b31982"; };
    erlex = { version = "0.2.8"; sha256 = "9d66ff9fedf69e49dc3fd12831e12a8a37b76f8651dd21cd45fcf5561a8a7590"; };
    excoveralls = { version = "0.18.5"; sha256 = "523fe8a15603f86d64852aab2abe8ddbd78e68579c8525ae765facc5eae01562"; };
    expo = { version = "1.1.1"; sha256 = "5fb308b9cb359ae200b7e23d37c76978673aa1b06e2b3075d814ce12c5811640"; };
    file_system = { version = "1.1.1"; sha256 = "7a15ff97dfe526aeefb090a7a9d3d03aa907e100e262a0f8f7746b78f8f87a5d"; };
    finch = { version = "0.23.0"; sha256 = "80e58d3f936f57e3fdf404f83a3642897ae6d9fb642934e46da4d8fe761b99d5"; };
    fine = { version = "0.1.6"; sha256 = "5638eb4495488e885ebec167fa57973e5c35e1a50c344eb7666c90ec1c4e3b12"; };
    floki = { version = "0.38.4"; sha256 = "bdb34645eee8e79845c7edaca2d4099a52804ee4d4a3ecc683a69451f0244973"; };
    fuse = { version = "2.5.0"; sha256 = "7f52a1c84571731ad3c91d569e03131cc220ebaa7e2a11034405f0bac46a4fef"; };
    gen_state_machine = { version = "3.0.0"; sha256 = "0a59652574bebceb7309f6b749d2a41b45fdeda8dbb4da0791e355dd19f0ed15"; };
    gettext = { version = "1.0.2"; sha256 = "eab805501886802071ad290714515c8c4a17196ea76e5afc9d06ca85fb1bfeb3"; };
    hackney = { version = "1.25.0"; sha256 = "7209bfd75fd1f42467211ff8f59ea74d6f2a9e81cbcee95a56711ee79fd6b1d4"; };
    hpax = { version = "1.0.3"; sha256 = "8eab6e1cfa8d5918c2ce4ba43588e894af35dbd8e91e6e55c817bca5847df34a"; };
    idna = { version = "6.1.1"; sha256 = "92376eb7894412ed19ac475e4a86f7b413c1b9fbb5bd16dccd57934157944cea"; };
    jason = { version = "1.4.5"; sha256 = "b0c823996102bcd0239b3c2444eb00409b72f6a140c1950bc8b457d836b30684"; };
    lazy_html = { version = "0.1.12"; sha256 = "8a0da594776caee58782c6f93b2abaa5bdb809daf8d43351a561f7de9dc2e2a8"; };
    localize = { version = "1.2.0"; sha256 = "3f2e79352357e2dc4b276848f781c025bbab391297109d872f497334fbfa6bab"; };
    localize_web = { version = "1.1.0"; sha256 = "7d423b37a7936b2f38f7d68605def7f0bbc4f0140888d3fe4581d483760b6ec4"; };
    meck = { version = "1.2.0"; sha256 = "a2cfd08306ef4992db7cd2aa3521b797456abec9f562f3f0341633052dee4af9"; };
    metrics = { version = "1.0.1"; sha256 = "69b09adddc4f74a40716ae54d140f93beb0fb8978d8636eaded0c31b6f099f16"; };
    mime = { version = "2.0.7"; sha256 = "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd"; };
    mimerl = { version = "1.5.0"; sha256 = "db648ce065bae14ea84ca8b5dd123f42f49417cef693541110bf6f9e9be9ecc4"; };
    mint = { version = "1.9.0"; sha256 = "007154c7d8c43916aed3c93afd1f11aebbaa9c5ff4b7ba55ebe0d17ee0296042"; };
    mock = { version = "0.3.9"; sha256 = "9e1b244c4ca2551bb17bb8415eed89e40ee1308e0fbaed0a4fdfe3ec8a4adbd3"; };
    nimble_csv = { version = "1.3.0"; sha256 = "41ccdc18f7c8f8bb06e84164fc51635321e80d5a3b450761c4997d620925d619"; };
    nimble_options = { version = "1.1.1"; sha256 = "821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44"; };
    nimble_parsec = { version = "1.4.2"; sha256 = "4b21398942dda052b403bbe1da991ccd03a053668d147d53fb8c4e0efe09c973"; };
    nimble_pool = { version = "1.1.0"; sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a"; };
    parse_trans = { version = "3.4.1"; sha256 = "620a406ce75dada827b82e453c19cf06776be266f5a67cff34e1ef2cbb60e49a"; };
    phoenix = { version = "1.8.9"; sha256 = "3477e2dd5a4f61820341169031bdfe21275f659923bea9c5c0ea2aa1c3fcc046"; };
    phoenix_bakery = { version = "1.0.0"; sha256 = "c369fd908cd794bebc8d7813ef44474b57b90344c22c47ec5e62331af3c66b25"; };
    phoenix_ecto = { version = "4.7.0"; sha256 = "1d75011e4254cb4ddf823e81823a9629559a1be93b4321a6a5f11a5306fbf4cc"; };
    phoenix_html = { version = "4.3.0"; sha256 = "3eaa290a78bab0f075f791a46a981bbe769d94bc776869f4f3063a14f30497ad"; };
    phoenix_html_helpers = { version = "1.0.1"; sha256 = "cffd2385d1fa4f78b04432df69ab8da63dc5cf63e07b713a4dcf36a3740e3090"; };
    phoenix_live_reload = { version = "1.6.2"; sha256 = "d1f89c18114c50d394721365ffb428cce24f1c13de0467ffa773e2ff4a30d5b9"; };
    phoenix_live_view = { version = "1.2.8"; sha256 = "b05ffe21f43c0ff219da62948b482c324aa5b8873e17b0c0cac58289a178af38"; };
    phoenix_pubsub = { version = "2.2.0"; sha256 = "adc313a5bf7136039f63cfd9668fde73bba0765e0614cba80c06ac9460ff3e96"; };
    phoenix_template = { version = "1.0.4"; sha256 = "2c0c81f0e5c6753faf5cca2f229c9709919aba34fab866d3bc05060c9c444206"; };
    phoenix_view = { version = "2.0.4"; sha256 = "4e992022ce14f31fe57335db27a28154afcc94e9983266835bb3040243eb620b"; };
    plug = { version = "1.20.3"; sha256 = "be266aee1b8536ef6409d58cf39a3121319f0ec47cfa1b24024485aa0e76ad76"; };
    plug_cowboy = { version = "2.9.0"; sha256 = "2002bafba4f3a45b55a58e68d70211b153a7ed18d37edb1ceb6e96e7a92c422e"; };
    plug_crypto = { version = "2.2.0"; sha256 = "83a95744ab1c75876542b6fab135fcc176280e0f301a111c1f757fddcec95d2c"; };
    postgrex = { version = "0.22.3"; sha256 = "f018c13752b2b46e8d35d7e2d84c3276557cbfd880769109021a1d0ee36c1cfe"; };
    ranch = { version = "2.2.1"; sha256 = "55f05cce20ec2da1d90de5d5981afb93dbfc01325fc7e933189aa5c62f037c24"; };
    srtm = { version = "0.8.0"; sha256 = "7ec2a2ced7c3c0c1bdcfca67ce4d466d77e66cf52589f546c91b96b4c79b6923"; };
    ssl_verify_fun = { version = "1.1.7"; sha256 = "fe4c190e8f37401d30167c8c405eda19469f34577987c76dde613e838bbc67f8"; };
    telemetry = { version = "1.4.2"; sha256 = "928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1"; };
    tesla = { version = "1.20.0"; sha256 = "3ecb41cb458772332752c3acdfe983e23abb991f5a43cfd69a64e9ea3f4b0061"; };
    timex = { version = "3.7.13"; sha256 = "09588e0522669328e973b8b4fd8741246321b3f0d32735b589f78b136e6d4c54"; };
    tortoise311 = { version = "0.12.2"; sha256 = "42b1e5e278c9c261c8453ece2a68da7b0275c41526a283d54c967d581e8c1bd7"; };
    tzdata = { version = "1.1.4"; sha256 = "ab48888699de8ff4a255522fd858abe81bac2e64690a375e6cb590112cf4a24e"; };
    unicode_util_compat = { version = "0.7.1"; sha256 = "b3a917854ce3ae233619744ad1e0102e05673136776fb2fa76234f3e03b23642"; };
    websock = { version = "0.5.3"; sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453"; };
    websock_adapter = { version = "0.6.0"; sha256 = "50021a85bce8f203b086705d9e0c5415e2c7eb05d319111b0428fe71f9934617"; };
    websockex = { version = "0.5.1"; sha256 = "8ef39576ed56bc3804c9cd8626f8b5d6b5721848d2726c0ccd4f05385a3c9f14"; };
  };

  # Per-dependency fetchHex: each hex tarball is a hashed fetchurl fetched
  # by the store and unpacked with the .hex lock metadata that hex would
  # write - nothing downloaded executes. mixRelease copies mixDepsTree into
  # deps/ in postUnpack and symlinks it into the build root, exactly as it
  # did for the old fetchMixDeps FOD, which ran `mix deps.get` (downloaded
  # code executing with network on the build host) and is retired by the
  # fod-only-downloads invariant (blumeops#1809). A lock that ever gains a
  # git/path/umbrella dep will not be served by this scheme - extend it
  # deliberately, not silently.
  mixDeps = lib.mapAttrs (name: v: beamPackages.fetchHex {
    pkg = name;
    inherit (v) version sha256;
  }) hexDeps;

  mixDepsTree = pkgs.stdenvNoCC.mkDerivation {
    pname = "mix-deps-teslamate";
    inherit version;
    buildInputs = builtins.attrValues mixDeps;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      ${lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs (name: d: "cp -r \"${d}\" \"$out/${name}\"") mixDeps))}
      runHook postInstall
    '';
  };

  teslamate = beamPackages.mixRelease {
    pname = "teslamate";
    inherit version src elixir;

    # Keep the build-generated Erlang cookie in the release. mixRelease
    # strips it by default (expecting RELEASE_COOKIE at runtime), but the
    # start script reads releases/COOKIE. teslamate is single-node (no
    # distributed Erlang exposed), so a baked-in cookie is fine.
    removeCookie = false;

    # Consumed purely as a path (postUnpack: cp -R); deliberately a plain
    # derivation, not a FOD, despite the upstream attr name.
    mixFodDeps = mixDepsTree;

    # Frontend assets. esbuild + sass are devDeps and the esbuild platform
    # binary is an optional dep, so npm ci must include both. We run npm ci
    # here (not a separate derivation) because assets/package.json has
    # file:../deps/phoenix references that only resolve once mixFodDeps has
    # populated deps/. npmConfigHook wires up the offline cache from npmDeps;
    # then `node scripts/build.js` (custom esbuild) + `mix phx.digest`.
    nativeBuildInputs = [ pkgs.nodejs pkgs.npmHooks.npmConfigHook ];
    npmDeps = pkgs.fetchNpmDeps {
      name = "teslamate-npm-deps";
      src = src + "/assets";
      hash = "sha256-nUWdQMCrJZqhyb7KgDeAsIOlGMJOg5towtbZuBhv0Mg=";
    };
    npmRoot = "assets";

    preBuild = ''
      ( cd assets && npm ci --include=dev --include=optional && node scripts/build.js )
      mix phx.digest --no-deps-check
    '';
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/teslamate";

  contents = [
    teslamate
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.dash
    pkgs.netcat-openbsd
    pkgs.cacert
    pkgs.tzdata
  ];

  # /opt/app (HOME, SRTM_CACHE) and /tmp must be writable by the runtime
  # uid 1000; the build user can't chown, so ownership is set in
  # fakeRootCommands (fakeroot records it into the layer tar).
  extraCommands = ''
    mkdir -p opt/app/.srtm_cache tmp
    chmod 1777 tmp
  '';
  fakeRootCommands = ''
    chown -R 1000:1000 opt/app
  '';
  enableFakechroot = true;

  config = {
    # Mirror entrypoint.sh: cap the nofile limit, wait for postgres, run
    # migrations, then start.
    Entrypoint = [
      "${pkgs.dash}/bin/dash"
      "-c"
      ''
        : "''${ULIMIT_MAX_NOFILE:=65536}"
        if test "''${ULIMIT_MAX_NOFILE}" != 0 && test "$(ulimit -n)" -gt "''${ULIMIT_MAX_NOFILE}"; then
          ulimit -n "''${ULIMIT_MAX_NOFILE}"
        fi
        : "''${DATABASE_HOST:=127.0.0.1}"
        : "''${DATABASE_PORT:=5432}"
        while ! ${pkgs.netcat-openbsd}/bin/nc -z "$DATABASE_HOST" "$DATABASE_PORT" 2>/dev/null; do
          echo "waiting for postgres at $DATABASE_HOST:$DATABASE_PORT"; sleep 1
        done
        ${teslamate}/bin/teslamate eval "TeslaMate.Release.migrate"
        exec ${teslamate}/bin/teslamate start
      ''
    ];
    Env = [
      "HOME=/opt/app"
      "SRTM_CACHE=/opt/app/.srtm_cache"
      "LANG=C.UTF-8"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    ExposedPorts = {
      "4000/tcp" = { };
    };
    # Run as uid 1000 per the PSA non-root decision (docs/reference/operations/security.md).
    User = "1000";
  };
}
