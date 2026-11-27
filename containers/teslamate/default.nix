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
# v4.5.0 tag's sha so builtins.fetchGit needs no hash. The Elixir project
# lives under elixir/, but mix.exs and lib/ read ../VERSION, ../NOTICE and
# ../grafana, so the whole repository is the source and sourceRoot selects elixir/.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/331800de5053fcebacf6813adb5db9c9dca22a0c.tar.gz";
    sha256 = "1p54fm6dkbq62kpi55cr4wyx7b1nsajpsnjgs64cmp073fwi15f7";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  lib = pkgs.lib;

  version = "4.5.0";

  beamPackages = pkgs.beam.packages.erlang_28;
  elixir = beamPackages.elixir_1_19;

  srcName = "teslamate-src";
  src = builtins.fetchGit {
    name = srcName;
    url = "https://forge.ops.eblu.me/mirrors/teslamate.git";
    ref = "refs/tags/v${version}";
    rev = "83652a688ef4ff2118572e9f48c49807e348453f";
  };

  # Every hex dep in the v4.5.0 elixir/mix.lock: name -> (version, tarball sha256).
  # Regenerate on a version bump by parsing mix.lock; the lock entry
  # "name": {:hex, :atom, "version", "package-sha", builders, deps, "hexpm",
  # "tar-sha256"} carries the fetched tarball's sha256 in the LAST field.
  hexDeps = {
    bunt = { version = "1.0.0"; sha256 = "dc5f86aa08a5f6fa6b8096f0735c4e76d54ae5c9fa2c143e5a1fc7c1cd9bb6b5"; };
    castore = { version = "1.0.22"; sha256 = "c2a4d42723b4affbc1c3e15d8f6df3f7d8f1f627c84de643383634cce58493d5"; };
    cc_precompiler = { version = "0.1.11"; sha256 = "3427232caf0835f94680e5bcf082408a70b48ad68a5f5c0b02a3bea9f3a075b9"; };
    cloak = { version = "1.1.4"; sha256 = "92b20527b9aba3d939fab0dd32ce592ff86361547cfdc87d74edce6f980eb3d7"; };
    cloak_ecto = { version = "1.3.0"; sha256 = "314beb0c123b8a800418ca1d51065b27ba3b15f085977e65c0f7b2adab2de1cc"; };
    combine = { version = "0.10.0"; sha256 = "1b1dbc1790073076580d0d1d64e42eae2366583e7aecd455d1215b0d16f2451b"; };
    cowboy = { version = "2.21.0"; sha256 = "90b4d6fe91806054538349dbeabcac86315a3fdaec4eb491f5445259668398f6"; };
    cowboy_telemetry = { version = "0.4.0"; sha256 = "7d98bac1ee4565d31b62d59f8823dfd8356a169e7fcbb83831b8a5397404c9de"; };
    cowlib = { version = "2.22.0"; sha256 = "b1ea5995d8f1ab5086ae7afe710c2075c7872c7e1acaf45dd0db7595e900c0fc"; };
    credo = { version = "1.7.19"; sha256 = "2d8bc95d5a7bb99dd2613621d4f08c6a3575c3fd4b62e6a2b48a100352a557b8"; };
    db_connection = { version = "2.10.2"; sha256 = "510b14482330f1af6490a2fa0efd8d4f1435d1529b165647df22ac0f2df0fa93"; };
    decimal = { version = "3.2.0"; sha256 = "190bca80580ce61aa69bb0eacadd7677710205c770225c2c2c07e32a5c31b234"; };
    dialyxir = { version = "1.4.9"; sha256 = "1c049c22b47680f4fff78ed0b0fe377073a762e96af153fdfe28bf00131de76d"; };
    ecto = { version = "3.14.3"; sha256 = "da2548bd3ced0f56c27d54255389bbbb8f110150ce15cffc95ec0cafa364465c"; };
    ecto_sql = { version = "3.14.0"; sha256 = "f4d8d36faf294c9417b5a37ec7ac8217ee2abdef5fcf197ba690f361548d3949"; };
    elixir_make = { version = "0.10.1"; sha256 = "ce1eaa234bc87f0279718e793fd6f8ad35b4e8ee8d412329e3879eee8d40adba"; };
    erlex = { version = "0.2.9"; sha256 = "8cfffc0ec7159e6d73de2ab28a588064de80f88b2798d5cbe4482cbbc200178b"; };
    excoveralls = { version = "0.18.5"; sha256 = "523fe8a15603f86d64852aab2abe8ddbd78e68579c8525ae765facc5eae01562"; };
    expo = { version = "1.1.1"; sha256 = "5fb308b9cb359ae200b7e23d37c76978673aa1b06e2b3075d814ce12c5811640"; };
    file_system = { version = "1.1.1"; sha256 = "7a15ff97dfe526aeefb090a7a9d3d03aa907e100e262a0f8f7746b78f8f87a5d"; };
    finch = { version = "0.24.0"; sha256 = "33ba40069c3587c2f99f9125b766e19dad87d6d54be3c6961db2304df04cef00"; };
    fine = { version = "0.2.0"; sha256 = "6f69a9e8dadbfd017b27f611b000362870683ae65f28aec904f36ec4c5058db5"; };
    floki = { version = "0.38.5"; sha256 = "c8c5b04455f01b076cd489fee7dc26b49edf9851ef61146e743f4676114bf6b0"; };
    fuse = { version = "2.5.0"; sha256 = "7f52a1c84571731ad3c91d569e03131cc220ebaa7e2a11034405f0bac46a4fef"; };
    gen_state_machine = { version = "3.0.0"; sha256 = "0a59652574bebceb7309f6b749d2a41b45fdeda8dbb4da0791e355dd19f0ed15"; };
    gettext = { version = "1.0.2"; sha256 = "eab805501886802071ad290714515c8c4a17196ea76e5afc9d06ca85fb1bfeb3"; };
    hpax = { version = "1.1.0"; sha256 = "0b8d0f05832f55571d65ac720f79bf8994138ffbb133209dc4685eae0ad456a8"; };
    jason = { version = "1.4.5"; sha256 = "b0c823996102bcd0239b3c2444eb00409b72f6a140c1950bc8b457d836b30684"; };
    lazy_html = { version = "0.1.14"; sha256 = "99210889b0cc591398d006def761f2faef438d1ac77d045a527791733571dc0c"; };
    localize = { version = "1.7.1"; sha256 = "d61c0a8242db18487674719edc781a78404dba0123e9825c38dc026a88d594ec"; };
    localize_web = { version = "1.3.1"; sha256 = "5a98b46a2c610e4e384fa788b9fb21472760bb0ddaa835b76e1cd2199a2f937a"; };
    meck = { version = "1.2.0"; sha256 = "a2cfd08306ef4992db7cd2aa3521b797456abec9f562f3f0341633052dee4af9"; };
    mime = { version = "2.0.7"; sha256 = "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd"; };
    mint = { version = "1.11.0"; sha256 = "c6279ba2d6aa3a383a1d4cfbe7b59f42e6efd400f58d8e2acfeac48a438693ab"; };
    mock = { version = "0.3.9"; sha256 = "9e1b244c4ca2551bb17bb8415eed89e40ee1308e0fbaed0a4fdfe3ec8a4adbd3"; };
    nimble_csv = { version = "1.3.0"; sha256 = "41ccdc18f7c8f8bb06e84164fc51635321e80d5a3b450761c4997d620925d619"; };
    nimble_options = { version = "1.2.0"; sha256 = "3a784a75ef9e407619c8c9e98239b1acd29216deb737044a8c1063e2671ce6d9"; };
    nimble_parsec = { version = "1.4.2"; sha256 = "4b21398942dda052b403bbe1da991ccd03a053668d147d53fb8c4e0efe09c973"; };
    nimble_pool = { version = "1.1.0"; sha256 = "af2e4e6b34197db81f7aad230c1118eac993acc0dae6bc83bac0126d4ae0813a"; };
    phoenix = { version = "1.8.16"; sha256 = "e7355c35889305bc539eb09dae2393abcbaf0f65f6874a3f0dcb5f0ec53737fe"; };
    phoenix_bakery = { version = "1.0.0"; sha256 = "c369fd908cd794bebc8d7813ef44474b57b90344c22c47ec5e62331af3c66b25"; };
    phoenix_ecto = { version = "4.7.0"; sha256 = "1d75011e4254cb4ddf823e81823a9629559a1be93b4321a6a5f11a5306fbf4cc"; };
    phoenix_html = { version = "4.4.0"; sha256 = "94832038da7ab8f86d4c0d36f7797a269fd06fe611f25c69f55108c075505228"; };
    phoenix_html_helpers = { version = "1.0.1"; sha256 = "cffd2385d1fa4f78b04432df69ab8da63dc5cf63e07b713a4dcf36a3740e3090"; };
    phoenix_live_reload = { version = "1.7.0"; sha256 = "dc9f44271aa6fc4ab7797f2aa374ba096ef2c87520586280eb095626b7387a68"; };
    phoenix_live_view = { version = "1.2.13"; sha256 = "a5cd2a3df10552bce6b7e68e5d376ff3b46cca3ca62d6c43bd4398d80c197fbe"; };
    phoenix_pubsub = { version = "2.4.1"; sha256 = "352fba7a87bf61395b6e97da66944ad9b1bfe5459e5981039f60d68270bd9700"; };
    phoenix_template = { version = "1.1.0"; sha256 = "eba70070de79b2c3501ef205a74a69f98ab352f3785aa15da9ed161f9fe0fd5d"; };
    phoenix_view = { version = "2.0.4"; sha256 = "4e992022ce14f31fe57335db27a28154afcc94e9983266835bb3040243eb620b"; };
    plug = { version = "1.20.3"; sha256 = "be266aee1b8536ef6409d58cf39a3121319f0ec47cfa1b24024485aa0e76ad76"; };
    plug_cowboy = { version = "2.9.0"; sha256 = "2002bafba4f3a45b55a58e68d70211b153a7ed18d37edb1ceb6e96e7a92c422e"; };
    plug_crypto = { version = "2.2.1"; sha256 = "4417ccbd8f85e627321cd07d2ab9c4b621f1fd883b9905af241f9b4b780b94b6"; };
    postgrex = { version = "0.22.4"; sha256 = "4aae45a2d60e35b04eea2602440be152fae332901f1fc7a60fc7cb7f0f9a9c5a"; };
    ranch = { version = "2.4.0"; sha256 = "64d98b8c61d39b7b9a2e2cf92ae659b8623a69766f415ae13dc726864ec04ab9"; };
    srtm = { version = "0.9.0"; sha256 = "50f521eaeccdfb570622f381904e7c284b7755c5bf8ca405ce5a52e629decc6a"; };
    telemetry = { version = "1.4.3"; sha256 = "17a63581cf2e832a238287f5fe6811e8ca1f333249f1376ad653164a3c4770d4"; };
    tesla = { version = "1.23.0"; sha256 = "674fac7a2edfc4e7dbb0c42b18f73780447a3c7fe9fd644156df507f47bad13f"; };
    timex = { version = "4.0.0"; sha256 = "74118ceb13fd7b75abc6804511fc0484438a6ca51e8e03fc94520cfb12868035"; };
    tortoise311 = { version = "0.12.3"; sha256 = "2d5f2e25a7e416326bcf38efe460ae91b65b5bb211e51b9dc82dde48ae3e251f"; };
    tzdata = { version = "1.2.2"; sha256 = "4a2435eb3614711b220a9f9f9b56204d14518c6a84e94278cc8b697ca62221a7"; };
    websock = { version = "0.5.3"; sha256 = "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453"; };
    websock_adapter = { version = "0.7.2"; sha256 = "f9e80710008783864177c81e9d8418d05769ce10a26e9e538f5ed72e283f7358"; };
    websockex = { version = "0.5.1"; sha256 = "8ef39576ed56bc3804c9cd8626f8b5d6b5721848d2726c0ccd4f05385a3c9f14"; };
  };

  # Per-dependency fetchHex: each hex tarball is a hashed fetchurl fetched
  # by the store and unpacked with the .hex lock metadata that hex would
  # write - nothing downloaded executes. mixRelease copies mixDepsTree into
  # deps/ in postUnpack and symlinks it into the build root. A lock that
  # ever gains a git/path/umbrella dep will not be served by this scheme -
  # extend it deliberately, not silently.
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
    sourceRoot = "${srcName}/elixir";

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
      src = src + "/elixir/assets";
      hash = pkgs.lib.fakeHash;
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
    # Mirror entrypoint.sh: cap the nofile limit, wait for the database and
    # run migrations, then start.
    Entrypoint = [
      "${pkgs.dash}/bin/dash"
      "-c"
      ''
        : "''${ULIMIT_MAX_NOFILE:=65536}"
        if test "''${ULIMIT_MAX_NOFILE}" != 0 && test "$(ulimit -n)" -gt "''${ULIMIT_MAX_NOFILE}"; then
          ulimit -n "''${ULIMIT_MAX_NOFILE}"
        fi
        ${teslamate}/bin/teslamate eval "TeslaMate.Release.wait_for_database_and_migrate()"
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
