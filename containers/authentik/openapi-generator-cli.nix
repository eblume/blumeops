# openapi-generator-cli 7.22.0: the upstream release jar, pinned by sha256,
# run on a bespoke JRE. nixpkgs builds this with a maven FOD that executes
# downloaded maven plugins, which the fod-eval-check invariant forbids.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "7.22.0";

  jar = pkgs.fetchurl {
    url = "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/${version}/openapi-generator-cli-${version}.jar";
    hash = "sha256-Px5s5catTxUkLGFwq0Oq1LrXcWImF+7s5KfU9y/68yk=";
  };

  jre = pkgs.jre_minimal.override {
    modules = [
      "java.base"
      "java.compiler"
      "java.datatransfer"
      "java.desktop"
      "java.instrument"
      "java.logging"
      "java.management"
      "java.naming"
      "java.net.http"
      "java.prefs"
      "java.scripting"
      "java.security.jgss"
      "java.sql"
      "java.xml"
      "jdk.compiler"
      "jdk.unsupported"
    ];
  };
in
pkgs.writeShellScriptBin "openapi-generator-cli" ''
  exec ${jre}/bin/java -jar ${jar} "$@"
''
