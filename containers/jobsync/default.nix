# Nix-built JobSync container
# Next.js job application tracker with Prisma/SQLite
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.1.4";

  prismaEngines = pkgs.prisma-engines;

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/jobsync.git";
    rev = "v${version}";
    hash = "sha256-59W5OF36yD67jEK5xa9jSL4EVN9RG+Ez/w9Mq2VykSA=";
  };

  jobsync = pkgs.buildNpmPackage {
    inherit src version;
    pname = "jobsync";
    npmDepsHash = "sha256-yRNOxtz66qSlmfjR3QDPUQe0C8sdg06tBbuK1Ws1gEA=";

    nodejs = pkgs.nodejs_20;

    # Patch out Google Fonts import (nix sandbox blocks network access at
    # build time). Replace with a simple object; app uses system sans-serif.
    postPatch = ''
      substituteInPlace src/app/layout.tsx \
        --replace-fail 'import { Inter } from "next/font/google";' "" \
        --replace-fail 'const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});' 'const inter = { variable: "" };'
    '';

    # Point Prisma at nixpkgs-built engines (no network download in sandbox)
    env = {
      PRISMA_QUERY_ENGINE_LIBRARY = "${prismaEngines}/lib/libquery_engine.node";
      PRISMA_QUERY_ENGINE_BINARY = "${prismaEngines}/bin/query-engine";
      PRISMA_SCHEMA_ENGINE_BINARY = "${prismaEngines}/bin/schema-engine";
      PRISMA_FMT_BINARY = "${prismaEngines}/bin/prisma-fmt";
      PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING = "1";
      DATABASE_URL = "file:/tmp/build.db";
      NEXT_TELEMETRY_DISABLED = "1";
    };

    buildPhase = ''
      runHook preBuild

      # Generate Prisma client using nixpkgs engines
      npx prisma generate

      # Build Next.js
      npm run build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/app

      # Copy Next.js standalone output
      cp -r .next/standalone/. $out/app/
      cp -r .next/static $out/app/.next/static
      cp -r public $out/app/public

      # Copy Prisma schema and migrations for runtime migrate deploy
      cp -r prisma $out/app/prisma

      # Copy entrypoint
      cp ${./entrypoint.sh} $out/app/entrypoint.sh

      runHook postInstall
    '';

    dontNpmBuild = true;
  };

  entrypoint = pkgs.writeShellScript "jobsync-entrypoint" ''
    cd ${jobsync}/app
    exec ${pkgs.bash}/bin/bash entrypoint.sh "$@"
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/jobsync";
  tag = "latest";

  contents = [
    jobsync
    prismaEngines
    pkgs.nodejs_20
    pkgs.cacert
    pkgs.tzdata
    pkgs.bash
    pkgs.coreutils
  ];

  # Create writable directories and FHS symlinks for nix container
  extraCommands = ''
    mkdir -p tmp data usr/bin
    ln -s ${pkgs.coreutils}/bin/env usr/bin/env
  '';

  config = {
    Entrypoint = [ "${entrypoint}" ];
    WorkingDir = "${jobsync}/app";
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "NODE_ENV=production"
      "PORT=3000"
      "DATABASE_URL=file:/data/dev.db"
      "PRISMA_QUERY_ENGINE_LIBRARY=${prismaEngines}/lib/libquery_engine.node"
      "PRISMA_SCHEMA_ENGINE_BINARY=${prismaEngines}/bin/schema-engine"
      "PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1"
    ];
    ExposedPorts = {
      "3000/tcp" = { };
    };
    Volumes = {
      "/data" = { };
    };
  };
}
