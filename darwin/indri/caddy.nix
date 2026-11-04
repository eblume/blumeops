{ lib, caddyBinary, gandiTokenFile, configDir }:
# Renders the indri Caddyfile and caddy-wrapper.sh from caddy-services.json.
# Each service block ends with a blank line; the fly listener is emitted only
# when fly_proxied_services is non-empty.
let
  data = builtins.fromJSON (builtins.readFile ./caddy-services.json);
  t = n: lib.concatStrings (lib.genList (_: "\t") n);
  render = lines: lib.concatMapStrings (l: l + "\n") lines;
  domain = data.domain;
  httpsPort = toString data.https_port;
  flyPort = toString data.fly_https_port;
  services = data.services;
  flyServices = builtins.filter (s: s.fly_proxied or false) services;
  tcp = data.tcp_services;

  staticBody = s:
    let n = s.name; in
    [
      "${t 2}root * ${s.root}"
      "${t 2}encode gzip"
      "${t 2}# Long-cache fingerprinted assets; everything else stays default."
      "${t 2}@${n}_assets path_regexp \\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$"
      "${t 2}header @${n}_assets Cache-Control \"public, max-age=31536000, immutable\""
    ]
    ++ lib.concatLists (lib.imap1 (i: dl: [
      "${t 2}@${n}_dl${toString i} path ${dl.path}"
      "${t 2}header @${n}_dl${toString i} Content-Disposition `attachment; filename=\"${dl.filename}\"`"
    ]) (s.download_paths or [ ]))
    ++ lib.optionals (s.try_html or false) [
      "${t 2}# Quartz clean URLs: path → path/ → path.html → /404.html (200)."
      "${t 2}# Caddy's handle_errors is a top-level directive and can't live in"
      "${t 2}# this nested handle, so the 404 page rides as the final try_files"
      "${t 2}# candidate (served with 200 — acceptable for a human-facing 404)."
      "${t 2}try_files {path} {path}/ {path}.html /404.html"
    ]
    ++ [ "${t 2}file_server" ];

  proxyBody = s:
    let n = s.name; in
    lib.optionals ((s.cache_policy or "") == "spa") [
      "${t 2}# SPA cache policy: hashed static assets are immutable, HTML must revalidate."
      "${t 2}# Prevents stale HTML from referencing chunk hashes that no longer exist."
      "${t 2}@${n}_static path /static/dist/*"
      "${t 2}header @${n}_static Cache-Control \"public, max-age=31536000, immutable\""
      "${t 2}@${n}_html path /if/*"
      "${t 2}header @${n}_html Cache-Control \"no-cache\""
    ]
    ++ lib.concatLists (lib.imap1 (i: ip: [
      "${t 2}@${n}_deny${toString i} remote_ip ${ip}"
      "${t 2}respond @${n}_deny${toString i} 403"
    ]) (s.deny_ips or [ ]))
    ++ (if lib.hasPrefix "https://" s.backend then [
      "${t 2}reverse_proxy ${s.backend} {"
      "${t 3}# Caddy v2.11+ rewrites Host to upstream for HTTPS backends."
      "${t 3}# Preserve the original Host so services see *.ops.eblu.me."
      "${t 3}header_up Host {http.request.host}"
      "${t 2}}"
    ] else [ "${t 2}reverse_proxy ${s.backend}" ]);

  # One service's matcher + handle block, ending with the blank separator line.
  serviceBody = s:
    [
      "${t 1}@${s.name} host ${s.host}"
      "${t 1}handle @${s.name} {"
    ]
    ++ (if (s.kind or "proxy") == "static" then staticBody s else proxyBody s)
    ++ [ "${t 1}}" "" ];

  tlsLines = [
    "${t 1}tls {"
    "${t 2}dns gandi {env.GANDI_BEARER_TOKEN}"
    "${t 1}}"
  ];

  caddyfileLines = [
    "# Caddy reverse proxy for blumeops services"
    "# Managed by the indri nix-darwin generation (darwin/indri/caddy.nix) - do not edit manually"
    "#"
    "# All *.${domain} requests are proxied to backend services."
    "# TLS certificates are obtained via ACME DNS-01 challenge using Gandi."
    ""
    "{"
    "${t 1}# Global options"
    "${t 1}admin off"
    ""
  ]
  ++ lib.optionals (tcp != [ ]) (
    [ "${t 1}# Layer 4 (TCP) routing" "${t 1}layer4 {" ]
    ++ lib.concatMap (x: [
      "${t 2}:${toString x.port} {"
      "${t 3}route {"
      "${t 4}proxy ${x.backend}"
      "${t 3}}"
      "${t 2}}"
    ]) tcp
    ++ [ "${t 1}}" ]
  )
  ++ [
    "}"
    ""
    "# Wildcard certificate for all services"
    "*.${domain}:${httpsPort} {"
  ]
  ++ tlsLines
  ++ [ "" ]
  ++ lib.concatMap serviceBody services
  ++ [
    "${t 1}# Fallback for unknown hosts"
    "${t 1}handle {"
    "${t 2}respond \"Unknown service\" 404"
    "${t 1}}"
    "}"
    ""
    "# Fly-only listener: services flagged fly_proxied: true (expected set:"
    "# fly_proxied_services in caddy-services.json, enforced by mise-tasks/caddy-render-check). Reachable only by tag:flyio-proxy (tcp:8443"
    "# ACL grant); every other *.${domain} host is 404 here."
  ]
  ++ lib.optionals (data.fly_proxied_services != [ ]) (
    [ "*.${domain}:${flyPort} {" ]
    ++ tlsLines
    ++ [ "" ]
    ++ lib.concatMap serviceBody flyServices
    ++ [
      "${t 1}handle {"
      "${t 2}respond \"Unknown service\" 404"
      "${t 1}}"
      "}"
    ]
  )
  ++ [
    "# Base domain (${domain})"
    "${domain}:${httpsPort} {"
  ]
  ++ tlsLines
  ++ [
    ""
    "${t 1}respond \"blumeops services - use a subdomain (e.g., forge.${domain})\""
    "}"
  ];
in
{
  caddyfile = render caddyfileLines;
  wrapper = render [
    "#!/bin/bash"
    "# Wrapper script for Caddy that loads the Gandi token from file"
    "# Managed by the indri nix-darwin generation (darwin/indri/caddy.nix) - do not edit manually"
    ""
    "export GANDI_BEARER_TOKEN=$(cat ${gandiTokenFile})"
    "exec ${caddyBinary} run --config ${configDir}/Caddyfile"
  ];
}
