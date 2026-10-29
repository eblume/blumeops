# venv-lock.nix — GENERATED — do not edit by hand.
#
# Regenerate:  mise run generate-authentik-venv-lock --write
# Freshness:   the `generate-authentik-venv-lock` prek hook (Lint job) fails
#              when this file drifts from the pinned authentik rev's resolved
#              closure (a changed uv.lock without regeneration). The same
#              hook keeps containers/authentik/make-venv.py byte-exact with
#              the pinned pyproject-nix (the venv build-phase script).
#
# Provenance (the exact inputs this file was resolved from):
#   authentik         version/2026.8.5 (a914cd979a3a…)  sha256-gdhGKCfsMUrWyFnf5TaaHM2ZQ1WYgTLOgGg4DlCaUHU=
#     https://forge.ops.eblu.me/mirrors/authentik.git
#   build-system-pkgs   a17819c85163988e063806ffc4f6d2716bc8ead8  https://forge.ops.eblu.me/mirrors/build-system-pkgs.git
#   pyproject-nix       ddc400a6883b042646d0940e65971bb7f7e96107  https://forge.ops.eblu.me/mirrors/pyproject.nix.git
#   uv2nix              7aba73a3d85454f1118f8cf9de97979b4d26bcac  https://forge.ops.eblu.me/mirrors/uv2nix.git
#   nixpkgs pin       c3eea5b2156db11c7eeeada3dc737711255b253e  (containers/flake.lock)
#   python            3.14
#
# The resolved third-party venv closure of authentik's root project — local
# workspace projects excluded (authentik-django.nix installs them from the
# source tree). Pure data: each entry pins the exact wheel/sdist/git source the
# build fetches, plus the small build-system closure the sdist packages need.
# python-deps.nix consumes this to build the venv without import-from-derivation
# (eblume/blumeops#1867, prerequisite for the #1860 FOD eval check).
{
  provenance = {
    authentik = {
      url = "https://forge.ops.eblu.me/mirrors/authentik.git";
      tag = "version/2026.8.5";
      hash = "sha256-gdhGKCfsMUrWyFnf5TaaHM2ZQ1WYgTLOgGg4DlCaUHU=";
      sha = "a914cd979a3a6fc6b9415a6d7a0ef724c9f11482";
    };
    trio = {
      "build-system-pkgs" = { url = "https://forge.ops.eblu.me/mirrors/build-system-pkgs.git"; rev = "a17819c85163988e063806ffc4f6d2716bc8ead8"; };
      "pyproject-nix" = { url = "https://forge.ops.eblu.me/mirrors/pyproject.nix.git"; rev = "ddc400a6883b042646d0940e65971bb7f7e96107"; };
      "uv2nix" = { url = "https://forge.ops.eblu.me/mirrors/uv2nix.git"; rev = "7aba73a3d85454f1118f8cf9de97979b4d26bcac"; };
    };
    nixpkgs = { rev = "c3eea5b2156db11c7eeeada3dc737711255b253e"; };
    python = "3.14";
  };

  # Resolved attrset order (local workspace projects excluded): the consumer
  # feeds this to the trio's resolveCyclic over the recorded dep edges,
  # reproducing the old build's NIX_PYPROJECT_DEPS byte for byte (the venv
  # merge is order-sensitive on file collisions).
  venvOrder = [ "aiohappyeyeballs" "aiohttp" "aiohttp-retry" "aiosignal" "annotated-types" "anyio" "argon2-cffi" "argon2-cffi-bindings" "asgiref" "ast-serialize" "attrs" "autobahn" "automat" "aws-cdk-asset-awscli-v1" "aws-cdk-asset-node-proxy-agent-v6" "aws-cdk-cloud-assembly-schema" "aws-cdk-lib" "azure-core" "azure-identity" "bandit" "bcrypt" "black" "blessed" "boto3" "botocore" "bpython" "cachetools" "cattrs" "cbor2" "certifi" "cffi" "channels" "charset-normalizer" "click" "colorama" "constantly" "constructs" "coverage" "cron-converter" "cryptography" "curtsies" "cwcwidth" "dacite" "daphne" "debugpy" "decorator" "deepmerge" "defusedxml" "django" "django-countries" "django-filter" "django-model-utils" "django-pgactivity" "django-pglock" "django-pgtrigger" "django-postgres-extra" "django-prometheus" "django-storages" "django-stubs" "django-stubs-ext" "django-tenants" "djangoql" "djangorestframework" "djangorestframework-stubs" "dnspython" "docker" "dramatiq" "drf-jsonschema-serializer" "drf-spectacular" "dumb-init" "duo-client" "durationpy" "email-validator" "fido2" "freezegun" "frozenlist" "geographiclib" "geoip2" "geopy" "google-api-core" "google-api-python-client" "google-auth" "google-auth-httplib2" "googleapis-common-protos" "greenlet" "gssapi" "gunicorn" "h11" "h2" "hpack" "httpcore" "httplib2" "httptools" "httpx" "hyperframe" "hyperlink" "idna" "importlib-metadata" "importlib-resources" "incremental" "inflection" "iniconfig" "invoke" "jinja2" "jinxed" "jmespath" "jsii" "jsonpatch" "jsonpointer" "jsonschema" "jsonschema-specifications" "jwcrypto" "k5test" "kubernetes" "ldap3" "librt" "lxml" "lxml-stubs" "markdown-it-py" "markdown2" "markupsafe" "maxminddb" "mdurl" "microsoft-kiota-abstractions" "microsoft-kiota-authentication-azure" "microsoft-kiota-http" "microsoft-kiota-serialization-form" "microsoft-kiota-serialization-json" "microsoft-kiota-serialization-multipart" "microsoft-kiota-serialization-text" "msal" "msal-extensions" "msgpack" "msgraph-core" "msgraph-sdk" "msgspec" "multidict" "mypy" "mypy-extensions" "netaddr" "oauthlib" "opencontainers" "opentelemetry-api" "opentelemetry-sdk" "opentelemetry-semantic-conventions" "outcome" "packaging" "paramiko" "pathspec" "pdoc" "platformdirs" "pluggy" "ply" "prometheus-client" "propcache" "proto-plus" "protobuf" "psycopg" "psycopg-c" "psycopg-pool" "publication" "pyasn1" "pyasn1-modules" "pycparser" "pydantic" "pydantic-core" "pydantic-scim" "pygments" "pyjwt" "pynacl" "pyopenssl" "pyparsing" "pyrad" "pyroscope-io" "pysocks" "pytest" "pytest-django" "pytest-flakefinder" "pytest-github-actions-annotate-failures" "pytest-randomly" "pytest-timeout" "python-dateutil" "python-dotenv" "python-kadmin-rs" "pytokens" "pyxdg" "pyyaml" "referencing" "requests" "requests-mock" "requests-oauthlib" "rich" "rpds-py" "ruff" "s3transfer" "scim2-filter-parser" "selenium" "sentry-sdk" "service-identity" "setproctitle" "setuptools" "six" "sly" "sniffio" "sortedcontainers" "sqlparse" "std-uritemplate" "stevedore" "structlog" "swagger-spec-validator" "tenacity" "trio" "trio-websocket" "twilio" "twisted" "txaio" "typeguard" "types-channels" "types-docker" "types-jwcrypto" "types-ldap3" "types-paramiko" "types-pyasn1" "types-pyyaml" "types-requests" "types-zxcvbn" "typing-extensions" "typing-inspection" "ua-parser" "ua-parser-builtins" "ujson" "unidecode" "uritemplate" "urllib3" "uvicorn" "uvloop" "watchdog" "watchfiles" "wcwidth" "webauthn" "websocket-client" "websockets" "wsproto" "xmlsec" "yarl" "zipp" "zope-interface" "zxcvbn" ];

  # Root pyproject [tool.uv] facts the consumer's build phases need.
  config = {
    compile-bytecode = true;
  };

  # 248 venv packages, sorted by name.
  #   source.type: "wheel" -> { url, hash, platformTags }
  #               "sdist" -> { url, hash }
  #               "git"   -> { url, rev }
  #   dependencies/optionalDependencies/dependencyGroups: the trio's mkSpec
  #   of the package's marker-filtered lock edges ({} when none).
  venv = {
  "aiohappyeyeballs" = {
    version = "2.6.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5f/fc/a7bf5b6e4e617b45f90f2d9d2a68519c249c81dd4fc2658c7a2a61c4f4b7/aiohappyeyeballs-2.6.2-py3-none-any.whl";
      hash = "sha256:4708045e2d7a6c6bdf8aafa8ed39649eaf926a4543b54560659129e3365953c4";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "aiohttp" = {
    version = "3.14.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d5/b7/1da684a04175473fa4cddbf9a2f572e79514c3fd27a74597f43057d4f3da/aiohttp-3.14.3-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:18cb43369747b2ae007bd2655fb8e63a099c2ff1d207962943636dac989b3147";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {
      "aiohappyeyeballs" = [  ];
      "aiosignal" = [  ];
      "attrs" = [  ];
      "frozenlist" = [  ];
      "multidict" = [  ];
      "propcache" = [  ];
      "yarl" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "aiohttp-retry" = {
    version = "2.9.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1a/99/84ba7273339d0f3dfa57901b846489d2e5c2cd731470167757f1935fffbd/aiohttp_retry-2.9.1-py3-none-any.whl";
      hash = "sha256:66d2759d1921838256a05a3f80ad7e724936f083e35be5abb5e16eed6be6dc54";
      platformTags = [ "any" ];
    };
    dependencies = {
      "aiohttp" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "aiosignal" = {
    version = "1.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fb/76/641ae371508676492379f16e2fa48f4e2c11741bd63c48be4b12a6b09cba/aiosignal-1.4.0-py3-none-any.whl";
      hash = "sha256:053243f8b92b990551949e63930a839ff0cf0b0ebbe0597b0f3fb19e1a0fe82e";
      platformTags = [ "any" ];
    };
    dependencies = {
      "frozenlist" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "annotated-types" = {
    version = "0.7.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/78/b6/6307fbef88d9b5ee7421e68d78a9f162e0da4900bc5f5793f6d3d0e34fb8/annotated_types-0.7.0-py3-none-any.whl";
      hash = "sha256:1f02e8b43a8fbbc3f3e0d4f0f4bfc8131bcb4eebe8849b8e5c773f3a1c582a53";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "anyio" = {
    version = "4.14.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/da/35/f2287558c17e29fafc8ef3daf819bb9834061cfa43bff8014f7df7f63bdc/anyio-4.14.2-py3-none-any.whl";
      hash = "sha256:9f505dda5ac9f0c8309b5e8bd445a8c2bf7246f3ce950121e45ea15bc41d1494";
      platformTags = [ "any" ];
    };
    dependencies = {
      "idna" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "argon2-cffi" = {
    version = "25.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/4f/d3/a8b22fa575b297cd6e3e3b0155c7e25db170edf1c74783d6a31a2490b8d9/argon2_cffi-25.1.0-py3-none-any.whl";
      hash = "sha256:fdc8b074db390fccb6eb4a3604ae7231f219aa669a2652e0f20e16ba513d5741";
      platformTags = [ "any" ];
    };
    dependencies = {
      "argon2-cffi-bindings" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "argon2-cffi-bindings" = {
    version = "25.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/09/52/94108adfdd6e2ddf58be64f959a0b9c7d4ef2fa71086c38356d22dc501ea/argon2_cffi_bindings-25.1.0-cp39-abi3-manylinux_2_26_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:d3e924cfc503018a714f94a49a149fdc0b644eaead5d1f089330399134fa028a";
      platformTags = [ "manylinux_2_26_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {
      "cffi" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "asgiref" = {
    version = "3.11.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5c/0a/a72d10ed65068e115044937873362e6e32fab1b7dce0046aeb224682c989/asgiref-3.11.1-py3-none-any.whl";
      hash = "sha256:e8667a091e69529631969fd45dc268fa79b99c92c5fcdda727757e52146ec133";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ast-serialize" = {
    version = "0.5.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b2/71/4d1d479aa56d0101c40e17720c3d6ac2af7269ea0487a80b18e7bfd1a5b7/ast_serialize-0.5.0-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:b54f60c1d78767a53b67eaa663f0dfac3afe606aa07f1301572f588b73d64809";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "attrs" = {
    version = "26.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/64/b4/17d4b0b2a2dc85a6df63d1157e028ed19f90d4cd97c36717afef2bc2f395/attrs-26.1.0-py3-none-any.whl";
      hash = "sha256:c647aa4a12dfbad9333ca4e71fe62ddc36f4e63b2d260a37a8b83d2f043ac309";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "autobahn" = {
    version = "26.6.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ed/e0/7bec571c751f19abaeca291c7c8a9159e87c324725d13ab83148d9d8ef89/autobahn-26.6.2-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:136058e9013b6bf52832270700e5f3cb451d6d5bb6b9dde8fb074edc5478414d";
      platformTags = [ "manylinux_2_24_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {
      "cbor2" = [  ];
      "cffi" = [  ];
      "cryptography" = [  ];
      "hyperlink" = [  ];
      "msgpack" = [  ];
      "txaio" = [  ];
      "ujson" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "automat" = {
    version = "25.4.16";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/02/ff/1175b0b7371e46244032d43a56862d0af455823b5280a50c63d99cc50f18/automat-25.4.16-py3-none-any.whl";
      hash = "sha256:04e9bce696a8d5671ee698005af6e5a9fa15354140a87f4870744604dcdd3ba1";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "aws-cdk-asset-awscli-v1" = {
    version = "2.2.282";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c5/86/dcb45969f1b34351cfd9afdb6b35bff38a3e929c8bc42b07036879f3a62e/aws_cdk_asset_awscli_v1-2.2.282-py3-none-any.whl";
      hash = "sha256:24139da0eb1be59f8cfda22c6343d51e8d50bb89b5052b049cfab92683de7790";
      platformTags = [ "any" ];
    };
    dependencies = {
      "jsii" = [  ];
      "publication" = [  ];
      "typeguard" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "aws-cdk-asset-node-proxy-agent-v6" = {
    version = "2.1.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1e/06/29837eb8ae4dc82ed2e593e4b24449394393b9a8a247b0ce2cee811e5cbb/aws_cdk_asset_node_proxy_agent_v6-2.1.2-py3-none-any.whl";
      hash = "sha256:1028bff16fdb87b8c82404e9b48f32ed383429dece84067f47379c4049da5da4";
      platformTags = [ "any" ];
    };
    dependencies = {
      "jsii" = [  ];
      "publication" = [  ];
      "typeguard" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "aws-cdk-cloud-assembly-schema" = {
    version = "54.14.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7f/e4/badc4a25352fc53ac87208079145a811789c8b98be2c9b7b610619c285e0/aws_cdk_cloud_assembly_schema-54.14.0-py3-none-any.whl";
      hash = "sha256:9445f5a6a8b28dd71e2f55448292db795042adf4c3ac48c5b5f735e208591f42";
      platformTags = [ "any" ];
    };
    dependencies = {
      "jsii" = [  ];
      "publication" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "aws-cdk-lib" = {
    version = "2.262.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3a/27/93fdebaee66e8965542562302f863a55aec3362f76e93ff643f9d01e0bfe/aws_cdk_lib-2.262.0-py3-none-any.whl";
      hash = "sha256:dada56daa1792f74baa4443d8488f0621c1722d6c443d480b5a21f434f2e6410";
      platformTags = [ "any" ];
    };
    dependencies = {
      "aws-cdk-asset-awscli-v1" = [  ];
      "aws-cdk-asset-node-proxy-agent-v6" = [  ];
      "aws-cdk-cloud-assembly-schema" = [  ];
      "constructs" = [  ];
      "jsii" = [  ];
      "publication" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "azure-core" = {
    version = "1.41.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5b/db/325c6d7312d2200251c52323878281045aaffcb5586612296484e4280eaa/azure_core-1.41.0-py3-none-any.whl";
      hash = "sha256:522b4011e8180b1a3dcd2024396a4e7fe9ac37fb8597db47163d230b5efe892d";
      platformTags = [ "any" ];
    };
    dependencies = {
      "requests" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "azure-identity" = {
    version = "1.25.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/49/9a/417b3a533e01953a7c618884df2cb05a71e7b68bdbce4fbdb62349d2a2e8/azure_identity-1.25.3-py3-none-any.whl";
      hash = "sha256:f4d0b956a8146f30333e071374171f3cfa7bdb8073adb8c3814b65567aa7447c";
      platformTags = [ "any" ];
    };
    dependencies = {
      "azure-core" = [  ];
      "cryptography" = [  ];
      "msal" = [  ];
      "msal-extensions" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "bandit" = {
    version = "1.9.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/05/a4/a26d5b25671d27e03afb5401a0be5899d94ff8fab6a698b1ac5be3ec29ef/bandit-1.9.4-py3-none-any.whl";
      hash = "sha256:f89ffa663767f5a0585ea075f01020207e966a9c0f2b9ef56a57c7963a3f6f8e";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pyyaml" = [  ];
      "rich" = [  ];
      "stevedore" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "bcrypt" = {
    version = "5.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e4/6e/b77ade812672d15cf50842e167eead80ac3514f3beacac8902915417f8b7/bcrypt-5.0.0-cp39-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:7aeef54b60ceddb6f30ee3db090351ecf0d40ec6e2abf41430997407a46d2254";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "black" = {
    version = "26.5.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/81/6b/cfaf3d39f25132c156a068f6b805576c9103a84086019507c70e1911ee7d/black-26.5.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:ea8d16dc41655aa113cd64665e7219446cd7e4ff2248d7178eaa905190c86b18";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {
      "click" = [  ];
      "mypy-extensions" = [  ];
      "packaging" = [  ];
      "pathspec" = [  ];
      "platformdirs" = [  ];
      "pytokens" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "blessed" = {
    version = "1.44.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7e/c3/e8effb323af40a5d8e85ab557da2f0475f12a31f3266f28d91d0bf406963/blessed-1.44.0-py3-none-any.whl";
      hash = "sha256:e1d2ed93d3d90d0a1494a8b134d188c83fb89ae25590af638b921e8c1c8fa223";
      platformTags = [ "any" ];
    };
    dependencies = {
      "jinxed" = [  ];
      "wcwidth" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "boto3" = {
    version = "1.43.36";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9f/f1/274303f52483ecf199eae6f8d9b6f5951670397ee4d72c06cfd4eb644612/boto3-1.43.36-py3-none-any.whl";
      hash = "sha256:42942dde254673abcbc9e6e60017c88341a4f49d99d24e1f2e290fb38138c26f";
      platformTags = [ "any" ];
    };
    dependencies = {
      "botocore" = [  ];
      "jmespath" = [  ];
      "s3transfer" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "botocore" = {
    version = "1.43.36";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5c/19/934f81592527a3f7f9b943c893e334c721a4644948642bc33885d584e9ec/botocore-1.43.36-py3-none-any.whl";
      hash = "sha256:3c65fdc39ed01d8dfde1e961b34038aed03c459f8ddf80717a12ac006475e49d";
      platformTags = [ "any" ];
    };
    dependencies = {
      "jmespath" = [  ];
      "python-dateutil" = [  ];
      "urllib3" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "bpython" = {
    version = "0.26";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ea/92/26d8d98de4c1676305e03ec2be67850afaf883b507bf71b917d852585ec8/bpython-0.26-py3-none-any.whl";
      hash = "sha256:91bdbbe667078677dc6b236493fc03e47a04cd099630a32ca3f72d6d49b71e20";
      platformTags = [ "any" ];
    };
    dependencies = {
      "curtsies" = [  ];
      "cwcwidth" = [  ];
      "greenlet" = [  ];
      "pygments" = [  ];
      "pyxdg" = [  ];
      "requests" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "cachetools" = {
    version = "7.1.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9f/f2/2086ba18a925a73586c4d4e61d25f4a6058e56fd00d77ce8f1d361ab4c9b/cachetools-7.1.6-py3-none-any.whl";
      hash = "sha256:2c12e255780330af28b91bb7fb96cce4c766f04e38396b9a24510190a5827096";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "cattrs" = {
    version = "26.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/80/56/60547f7801b97c67e97491dc3d9ade9fbccbd0325058fd3dfcb2f5d98d90/cattrs-26.1.0-py3-none-any.whl";
      hash = "sha256:d1e0804c42639494d469d08d4f26d6b9de9b8ab26b446db7b5f8c2e97f7c3096";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "cbor2" = {
    version = "6.1.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c8/cb/6bd33461e8be8ded7ebb0fa38994a63752aefae2b4fcd1b2cc71ee3c06f1/cbor2-6.1.3-cp314-cp314-manylinux_2_28_x86_64.whl";
      hash = "sha256:ad4f3c6dfc6b83331eb04c6975efb2839ab65a3aa81502bc2b3f7945d4c4aa44";
      platformTags = [ "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "certifi" = {
    version = "2026.10.19";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c4/51/29046e48f693c54e5b7412216d447a1d8362c9653148d98c02cdf65fa733/certifi-2026.10.19-py3-none-any.whl";
      hash = "sha256:42d35340cc5b9ba78e818ddbff0c5b1c2b779de448a340fd1b989f5fa8670e1b";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "cffi" = {
    version = "2.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/47/d9/d83e293854571c877a92da46fdec39158f8d7e68da75bf73581225d28e90/cffi-2.0.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:afb8db5439b81cf9c9d0c80404b60c3cc9c3add93e114dcae767f1477cb53775";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {
      "pycparser" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "channels" = {
    version = "4.3.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/16/34/c32915288b7ef482377b6adc401192f98c6a99b3a145423d3b8aed807898/channels-4.3.2-py3-none-any.whl";
      hash = "sha256:fef47e9055a603900cf16cef85f050d522d9ac4b3daccf24835bd9580705c176";
      platformTags = [ "any" ];
    };
    dependencies = {
      "asgiref" = [  ];
      "django" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "charset-normalizer" = {
    version = "3.4.7";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/47/5c/032c2d5a07fe4d4855fea851209cca2b6f03ebeb6d4e3afdb3358386a684/charset_normalizer-3.4.7-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:bd6c2a1c7573c64738d716488d2cdd3c00e340e4835707d8fdb8dc1a66ef164e";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "click" = {
    version = "8.4.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fb/e2/79c688af8b210d232694e31e59da9f6ec747bae31c3f5946e4e9b98860d5/click-8.4.2-py3-none-any.whl";
      hash = "sha256:e6f9f66136c816745b9d65817da91d61d957fb16e02e4dcd0552553c5a197b76";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "colorama" = {
    version = "0.4.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d1/d6/3965ed04c63042e047cb6a3e6ed1a63a35087b6a609aa3a15ed8ac56c221/colorama-0.4.6-py2.py3-none-any.whl";
      hash = "sha256:4f1d9991f5acc0ca119f9d443620b77f9d6b33703e51011c16baf57afb285fc6";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "constantly" = {
    version = "23.10.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b8/40/c199d095151addf69efdb4b9ca3a4f20f70e20508d6222bffb9b76f58573/constantly-23.10.4-py3-none-any.whl";
      hash = "sha256:3fd9b4d1c3dc1ec9757f3c52aef7e53ad9323dbe39f51dfd4c43853b68dfa3f9";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "constructs" = {
    version = "10.7.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ab/e7/f014792cb9e76d407e552aead634e048134c22e59a2f892b1cb7324afc71/constructs-10.7.1-py3-none-any.whl";
      hash = "sha256:f212c66b37249c45eca4638c6b33c68efddae50599d27062d71d0bf81c11431e";
      platformTags = [ "any" ];
    };
    dependencies = {
      "jsii" = [  ];
      "publication" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "coverage" = {
    version = "7.15.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6c/58/821b533b8db9e44cf1d8a97bd525149ced40dde1d0093da02cb78e715244/coverage-7.15.2-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:b9a6367e4aff723e8ee8190836836124284e8fcd4265e307c844010cfa074f3f";
      platformTags = [ "manylinux1_x86_64" "manylinux_2_28_x86_64" "manylinux_2_5_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "cron-converter" = {
    version = "1.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/da/9e/4285b91b03ad0d641fefaa69cc39cd7978106c40f729ac0052dd98a44204/cron_converter-1.3.1-py3-none-any.whl";
      hash = "sha256:60c645532802e12ad09097091a5ec83a79b9b1064374e89edb0facf2ba36a697";
      platformTags = [ "any" ];
    };
    dependencies = {
      "python-dateutil" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "cryptography" = {
    version = "50.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d9/41/029086c34d91052fc3b88bcc8056f709a7c915c7a23b235a54eb800b1c97/cryptography-50.0.0-cp311-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:06a32a980526a6ab9a4b9bf8f7385800791e2bb960903cb6b530e4817509a3b7";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {
      "cffi" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "curtsies" = {
    version = "0.4.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ab/9b/b8ee3720d056309f4ab667bfc85995c4351f67b22e8c2008612b70350c3a/curtsies-0.4.3-py3-none-any.whl";
      hash = "sha256:65a1b4d6ff887bd9b0f0836cc6dc68c3a2c65c57f51a62f0ee5df408edee1a99";
      platformTags = [ "any" ];
    };
    dependencies = {
      "blessed" = [  ];
      "cwcwidth" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "cwcwidth" = {
    version = "0.1.12";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e9/8b/f212d553fab5aa32e98bf7134e594c613cbaaaffd638d918725b0a6a795d/cwcwidth-0.1.12-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:156a88f6c753497d4a6b637672be4030ab405b6196f0309845b8e67212f5880b";
      platformTags = [ "manylinux1_x86_64" "manylinux_2_28_x86_64" "manylinux_2_5_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "dacite" = {
    version = "1.9.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/94/35/386550fd60316d1e37eccdda609b074113298f23cef5bddb2049823fe666/dacite-1.9.2-py3-none-any.whl";
      hash = "sha256:053f7c3f5128ca2e9aceb66892b1a3c8936d02c686e707bee96e19deef4bc4a0";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "daphne" = {
    version = "4.2.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/bd/0c/59e966c167880904f2e6a235c63169760dce58ba8062a7a153a6183539cc/daphne-4.2.3-py3-none-any.whl";
      hash = "sha256:34442c539a98111f4d8cac98a7204aeeb53811229bd96063e6fbe740e97078c9";
      platformTags = [ "any" ];
    };
    dependencies = {
      "asgiref" = [  ];
      "autobahn" = [  ];
      "twisted" = [ "tls" ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "debugpy" = {
    version = "1.8.21";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8c/2d/6e7ec524984a1702777868de49a4c53202bddac2a432a76a093469587750/debugpy-1.8.21-cp314-cp314-manylinux_2_34_x86_64.whl";
      hash = "sha256:3d6922439bf33fd38a3e2c447869ebc7b97da5cd3d329ff1ef9bc06c4903437e";
      platformTags = [ "manylinux_2_34_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "decorator" = {
    version = "5.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/05/7f/798705f5296a58ca505d600456748d1be48078eac8a7050d8a98bc9edb89/decorator-5.3.1-py3-none-any.whl";
      hash = "sha256:f47fe6fdbd2edd623ecfe36875d37aba411624e2670dd395dddae1358689bb3c";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "deepmerge" = {
    version = "2.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/51/25/2a75b47cb057b1e164c604fb81ab690a6cdb5e2260ce651194eae90f64a3/deepmerge-2.1.0-py3-none-any.whl";
      hash = "sha256:8f148339a91d680a75ecb74ade235d9e759a93df373a0b04e9d31c8666cfeb75";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "defusedxml" = {
    version = "0.7.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/07/6c/aa3f2f849e01cb6a001cd8554a88d4c77c5c1a31c95bdf1cf9301e6d9ef4/defusedxml-0.7.1-py2.py3-none-any.whl";
      hash = "sha256:a352e7e428770286cc899e2542b6cdaedb2b4953ff269a210103ec58f6198a61";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django" = {
    version = "5.2.17";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/df/f8/ce120525ca78f12b07daf65786679c5d0b54a75285a8958d3ae55e39da35/django-5.2.17-py3-none-any.whl";
      hash = "sha256:f04fb3b36ee119e1af4fa1d397d5fd6cf12700f49321e84d4f4c642c5b1973db";
      platformTags = [ "any" ];
    };
    dependencies = {
      "asgiref" = [  ];
      "sqlparse" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-countries" = {
    version = "9.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5c/bb/5a17b339852f6486d02b4dd0033132082976c71f049ee909ccb42917be52/django_countries-9.0.0-py3-none-any.whl";
      hash = "sha256:21fce461733c856355c487d1f24b71338599482505004a0c2e521fd574a59fb1";
      platformTags = [ "any" ];
    };
    dependencies = {
      "asgiref" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-filter" = {
    version = "26.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1f/01/afffed1e3c4540fb75bf550a18b6176a9f6371b5f3e52b69a28995b6480c/django_filter-26.1-py3-none-any.whl";
      hash = "sha256:7d98ef2899218e6242619b532cb1b95af14e09dfcf74844aecb550ad27b59ff2";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-model-utils" = {
    version = "5.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fd/13/87a42048700c54bfce35900a34e2031245132775fb24363fc0e33664aa9c/django_model_utils-5.0.0-py3-none-any.whl";
      hash = "sha256:fec78e6c323d565a221f7c4edc703f4567d7bb1caeafe1acd16a80c5ff82056b";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-pgactivity" = {
    version = "1.8.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/89/b1/966b4717bbcd002d0c6b90ba3af0361aee4b3d9b75246cb99d372ea42343/django_pgactivity-1.8.0-py3-none-any.whl";
      hash = "sha256:9b17f5d570266d26b3f8797379aeb721c95f60f999629a0648558374f0579eda";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-pglock" = {
    version = "1.8.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/44/75/0c145fbf2dc92cde0ad1b0d20891a41ea4843a8a6ed592ce35ec46d76e87/django_pglock-1.8.0-py3-none-any.whl";
      hash = "sha256:8bbfcb5d732a87e377f69d0fef5697042311c787912ad7baa3f0e00dcff06c41";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
      "django-pgactivity" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-pgtrigger" = {
    version = "4.17.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/91/47/13c0c23c134cd0f0b0addfbc3ef1477f90d891184d21689f9074b794b00c/django_pgtrigger-4.17.0-py3-none-any.whl";
      hash = "sha256:06048cdeb57e20987fd0bf7dd673512a1413a08868eea248d70dbb970e967175";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-postgres-extra" = {
    version = "2.0.9";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fe/0d/2e611d8977b6dad077296b6880e8ee2d7d320e55f834601c6ad5eb87b982/django_postgres_extra-2.0.9-py3-none-any.whl";
      hash = "sha256:0a4f9fd7f843e2ef5cfe7a291fcb883bd72d2ca8e4b369d0070866205e00b404";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
      "python-dateutil" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-prometheus" = {
    version = "2.5.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5d/5d/6ec3083ba69545696c962ae505a0e52e280e7592d4c278c2f3803cabb688/django_prometheus-2.5.0-py2.py3-none-any.whl";
      hash = "sha256:f15efb526cd53f9cf12da72dc55506322f5566b017a819ff27be1da302303134";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
      "prometheus-client" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-storages" = {
    version = "1.14.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1f/21/3cedee63417bc5553eed0c204be478071c9ab208e5e259e97287590194f1/django_storages-1.14.6-py3-none-any.whl";
      hash = "sha256:11b7b6200e1cb5ffcd9962bd3673a39c7d6a6109e8096f0e03d46fab3d3aabd9";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
    };
    optionalDependencies = {
      "s3" = {
        "boto3" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "django-stubs" = {
    version = "6.0.7";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/02/86/230ae6056221b543d63f7710d73967fe1c6840693540e99ea3c54f45859c/django_stubs-6.0.7-py3-none-any.whl";
      hash = "sha256:7ed9a14c438e589272ca04e966dee82a4d1ff7ca5c2171bc986c50a0d03ec35b";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
      "django-stubs-ext" = [  ];
      "types-pyyaml" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {
      "compatible-mypy" = {
        "mypy" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "django-stubs-ext" = {
    version = "6.0.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f1/e4/7d60a1bdb092807318af34a809dc6674b95cc78ec4d3aaa6027174e7201c/django_stubs_ext-6.0.6-py3-none-any.whl";
      hash = "sha256:5470c970f61a3ccf5aae7633feef1a097f944f417b955da200c9ac26ecd9134b";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "django-tenants" = {
    version = "3.10.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1f/0b/dad7316ef5e180fb4883a855e0a284cd349c4742f41603c7a1f4a26c52b5/django_tenants-3.10.2-py3-none-any.whl";
      hash = "sha256:200a5ec5be12812bda5436beaf21612fe15ae975c3211fc162e0dd70885b30e3";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "djangoql" = {
    version = "0.19.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/59/86/4455346b3c3cd7e5abe74a9c6abc97ceda2d597e73dd9eb77bd3bd558086/djangoql-0.19.1-py2.py3-none-any.whl";
      hash = "sha256:70cf53218b15557ed02baaace1387de1caffb6809cdfb3c633e4fd4e53a36111";
      platformTags = [ "any" ];
    };
    dependencies = {
      "ply" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "djangorestframework" = {
    version = "3.17.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5a/e1/2c516bdc83652b1a60c6119366ac2c0607b479ed05cd6093f916ca8928f8/djangorestframework-3.17.1-py3-none-any.whl";
      hash = "sha256:c3c74dd3e83a5a3efc37b3c18d92bd6f86a6791c7b7d4dff62bb068500e76457";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "djangorestframework-stubs" = {
    version = "3.17.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/72/ff/6e27d4aea12f67d14e0c0ec41869307ae98ad3816858ddc2a56bc3f4e0b5/djangorestframework_stubs-3.17.0-py3-none-any.whl";
      hash = "sha256:babe2703f0401507780848439f49f76222a178b4fc73a6dcb30d0952a0a6dbc6";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django-stubs" = [  ];
      "types-pyyaml" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {
      "compatible-mypy" = {
        "django-stubs" = [ "compatible-mypy" ];
        "mypy" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "dnspython" = {
    version = "2.8.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ba/5a/18ad964b0086c6e62e2e7500f7edc89e3faa45033c71c1893d34eed2b2de/dnspython-2.8.0-py3-none-any.whl";
      hash = "sha256:01d9bbc4a2d76bf0db7c1f729812ded6d912bd318d3b1cf81d30c0f845dbf3af";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "docker" = {
    version = "7.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/75/23/529140fe1aab80fc6992f93a706deec709140a6397439139a054e1515c45/docker-7.2.0-py3-none-any.whl";
      hash = "sha256:a3f45fdeb9165e2d25d9a1d02ddf3bc70fb572cf5ebbf9b58558c22caf29b71f";
      platformTags = [ "any" ];
    };
    dependencies = {
      "requests" = [  ];
      "urllib3" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "dramatiq" = {
    version = "2.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ef/57/a9be0b205b24e794c833a5295497f914776eb4d606d5a25a5b290e8b75ec/dramatiq-2.2.0-py3-none-any.whl";
      hash = "sha256:2b2aa244b4098e154600c47cdb2c04cec6c3af44e9e159c319c6fc8b6f0ba90e";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "drf-jsonschema-serializer" = {
    version = "3.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2f/71/1f500097efe09e04c3be862ab26c997314237a8b0a16dc3e3047fee23f4c/drf_jsonschema_serializer-3.0.0-py3-none-any.whl";
      hash = "sha256:d0e5cce095a5638b0bb7867aa060ed59ab9eed2f54ba5058dd9b483c9c887ed5";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
      "djangorestframework" = [  ];
      "jsonschema" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "drf-spectacular" = {
    version = "0.29.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/32/d9/502c56fc3ca960075d00956283f1c44e8cafe433dada03f9ed2821f3073b/drf_spectacular-0.29.0-py3-none-any.whl";
      hash = "sha256:d1ee7c9535d89848affb4427347f7c4a22c5d22530b8842ef133d7b72e19b41a";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
      "djangorestframework" = [  ];
      "inflection" = [  ];
      "jsonschema" = [  ];
      "pyyaml" = [  ];
      "uritemplate" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "dumb-init" = {
    version = "1.2.5.post1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/80/9f/04e2f23d636acdabcb62c623467f37ec672ee77d301fa2e98d6abb0dc763/dumb_init-1.2.5.post1-py2.py3-none-manylinux_2_12_x86_64.manylinux2010_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:5d6b1fe9b8efcdbbdcb670efe7a55f9117251ee9648d35ffd0c487fd79515ea5";
      platformTags = [ "manylinux2010_x86_64" "manylinux2014_x86_64" "manylinux_2_12_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "duo-client" = {
    version = "5.6.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9d/db/798547ea1a4af7be4454d621f8c23dbbad153dc7d9c57285fbcde03abd42/duo_client-5.6.1-py3-none-any.whl";
      hash = "sha256:ec7fa30548b7b8e3b7983948d08d167ada4df7a1b54b4723e7a02ee4635bb513";
      platformTags = [ "any" ];
    };
    dependencies = {
      "setuptools" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "durationpy" = {
    version = "0.10";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b0/0d/9feae160378a3553fa9a339b0e9c1a048e147a4127210e286ef18b730f03/durationpy-0.10-py3-none-any.whl";
      hash = "sha256:3b41e1b601234296b4fb368338fdcd3e13e0b4fb5b67345948f4f2bf9868b286";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "email-validator" = {
    version = "2.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/de/15/545e2b6cf2e3be84bc1ed85613edd75b8aea69807a71c26f4ca6a9258e82/email_validator-2.3.0-py3-none-any.whl";
      hash = "sha256:80f13f623413e6b197ae73bb10bf4eb0908faf509ad8362c5edeb0be7fd450b4";
      platformTags = [ "any" ];
    };
    dependencies = {
      "dnspython" = [  ];
      "idna" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "fido2" = {
    version = "2.2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/71/84/198d99c3312557ef6121cf78c38281efe9b3bc88cba0e2c05446f38a024d/fido2-2.2.1-py3-none-any.whl";
      hash = "sha256:ed397da981b9ab133da6ead7309e41f924b566b749956129efe286fae097749f";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cryptography" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "freezegun" = {
    version = "1.5.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5e/2e/b41d8a1a917d6581fc27a35d05561037b048e47df50f27f8ac9c7e27a710/freezegun-1.5.5-py3-none-any.whl";
      hash = "sha256:cd557f4a75cf074e84bc374249b9dd491eaeacd61376b9eb3c423282211619d2";
      platformTags = [ "any" ];
    };
    dependencies = {
      "python-dateutil" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "frozenlist" = {
    version = "1.8.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a7/b2/fabede9fafd976b991e9f1b9c8c873ed86f202889b864756f240ce6dd855/frozenlist-1.8.0-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:cba69cb73723c3f329622e34bdbf5ce1f80c21c290ff04256cff1cd3c2036ed2";
      platformTags = [ "manylinux1_x86_64" "manylinux_2_28_x86_64" "manylinux_2_5_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "geographiclib" = {
    version = "2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/31/b3/802576f2ea5dcb48501bb162e4c7b7b3ca5654a42b2c968ef98a797a4c79/geographiclib-2.1-py3-none-any.whl";
      hash = "sha256:e2a873b9b9e7fc38721ad73d5f4e6c9ed140d428a339970f505c07056997d40b";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "geoip2" = {
    version = "5.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/71/bf/407ea894512ad989f6fbf9f8e50a02a69ce888bf6a2b799e53a99e4d26a7/geoip2-5.3.0-py3-none-any.whl";
      hash = "sha256:7f82c587f3f3691f30adc8634d0b93de9853d96d514ed48ff3ba38f188a5df31";
      platformTags = [ "any" ];
    };
    dependencies = {
      "aiohttp" = [  ];
      "maxminddb" = [  ];
      "requests" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "geopy" = {
    version = "2.5.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/66/e5/de8b557b279e31cdfb2070ac83eb45dc7e29bd93cd544128756f658e52c7/geopy-2.5.0-py3-none-any.whl";
      hash = "sha256:8ad8cc226b505ca4d272ae9a2eeba08b8a2c565fc9a04eaefc33ad49c32b51aa";
      platformTags = [ "any" ];
    };
    dependencies = {
      "geographiclib" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "google-api-core" = {
    version = "2.31.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/86/40/9bdbb60b03a332bd45acb8703da08bbc27d991d35286b62e42acc86d243a/google_api_core-2.31.0-py3-none-any.whl";
      hash = "sha256:ef79fb3784c71cbac89cbd03301ba0c8fb8ad2aa95d7f9204dd9628f7adf59ab";
      platformTags = [ "any" ];
    };
    dependencies = {
      "google-auth" = [  ];
      "googleapis-common-protos" = [  ];
      "proto-plus" = [  ];
      "protobuf" = [  ];
      "requests" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "google-api-python-client" = {
    version = "2.198.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d5/92/0fc9e7a09eb240c31b879bd8d2e43f81ed1f86c4798b79ead4a083921ab3/google_api_python_client-2.198.0-py3-none-any.whl";
      hash = "sha256:fabac935474e817da5e662ff61bf7139439d6f92b32d332a7318a2d45931e03e";
      platformTags = [ "any" ];
    };
    dependencies = {
      "google-api-core" = [  ];
      "google-auth" = [  ];
      "google-auth-httplib2" = [  ];
      "httplib2" = [  ];
      "uritemplate" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "google-auth" = {
    version = "2.55.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e8/1d/f6d3ca1ad0725f2e08a1c6915640748a52de2e66596160a4d53b010cccf0/google_auth-2.55.1-py3-none-any.whl";
      hash = "sha256:eada68dfd52b3b81191827601e2a0c3fa12540c818534b630ddc5355769c3995";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cryptography" = [  ];
      "pyasn1-modules" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "google-auth-httplib2" = {
    version = "0.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/97/be/954c35a62b9e31de66b0a43c225c9b6bb9e0f98d6b1dc110a2308e3644f5/google_auth_httplib2-0.4.0-py3-none-any.whl";
      hash = "sha256:8e55cfafa3358cba85f6cad4a886138e88e158d71e7e5c9ee5936a5c1507fb91";
      platformTags = [ "any" ];
    };
    dependencies = {
      "google-auth" = [  ];
      "httplib2" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "googleapis-common-protos" = {
    version = "1.75.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e7/c8/e2645aa8ed02fd4c7a2f59d68783b65b1f3cbdfe39a6308e156509d1fee8/googleapis_common_protos-1.75.0-py3-none-any.whl";
      hash = "sha256:961ed60399c457ceb0ee8f285a84c870aabc9c6a832b9d37bb281b5bebde43ed";
      platformTags = [ "any" ];
    };
    dependencies = {
      "protobuf" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "greenlet" = {
    version = "3.5.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/99/69/d6c99db15dc0b5e892ac3cc7b942c8b21f4a9cc3bd9ea0bc3b0f339ffbd4/greenlet-3.5.2-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:26aed8d9503ca78889141a9739d71b383efea5f472a7c522b5410f7eb2a1b163";
      platformTags = [ "manylinux_2_24_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "gssapi" = {
    version = "1.11.1";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/23/52/c1e90623c259a42ab0587078bb04f959867b970add46ff66750ead8fc7c5/gssapi-1.11.1.tar.gz";
      hash = "sha256:2049ee4b1d0c363163a1344b7282a363f9f4094e51d2c36de0cf01d4735e0ae2";
    };
    dependencies = {
      "decorator" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "gunicorn" = {
    version = "26.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e6/40/9c2384fc2be4ad25dd4a49decd5ad9ea5a3639814c11bd40ab77cb9f0a14/gunicorn-26.0.0-py3-none-any.whl";
      hash = "sha256:40233d26a5f0d1872916188c276e21641155111c2853f0c2cd55260aec0d24fc";
      platformTags = [ "any" ];
    };
    dependencies = {
      "packaging" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "h11" = {
    version = "0.16.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/04/4b/29cac41a4d98d144bf5f6d33995617b185d14b22401f75ca86f384e87ff1/h11-0.16.0-py3-none-any.whl";
      hash = "sha256:63cf8bbe7522de3bf65932fda1d9c2772064ffb3dae62d55932da54b31cb6c86";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "h2" = {
    version = "4.4.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7e/22/e85faf23bd72a92d1921e37d674ca56eb298a3c8be31fdecef0ff2b3aaac/h2-4.4.1-py3-none-any.whl";
      hash = "sha256:0e25f1462b23c9cb82d9eb02e28bc706dac2a68cb457c6a0d74d63c8a2a5d0e6";
      platformTags = [ "any" ];
    };
    dependencies = {
      "hpack" = [  ];
      "hyperframe" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "hpack" = {
    version = "4.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/71/b4/4a9fcfb2aef6ba44d9073ecd301443aa00b3dac95de5619f2a7de7ec8a91/hpack-4.2.0-py3-none-any.whl";
      hash = "sha256:858ac0b02280fa582b5080d68db0899c62a80375e0e5413a74970c5e518b6986";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "httpcore" = {
    version = "1.0.9";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7e/f5/f66802a942d491edb555dd61e3a9961140fd64c90bce1eafd741609d334d/httpcore-1.0.9-py3-none-any.whl";
      hash = "sha256:2d400746a40668fc9dec9810239072b40b4484b640a8c38fd654a024c7a1bf55";
      platformTags = [ "any" ];
    };
    dependencies = {
      "certifi" = [  ];
      "h11" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "httplib2" = {
    version = "0.32.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/33/a0/550eec327e5f5c7b732531c489f5307efec41f047b0d703bd4ca1e5ad2db/httplib2-0.32.0-py3-none-any.whl";
      hash = "sha256:dc6705cacdf3fb0a2aba7629fa33c90fd93e30035db0c157325826be177e4816";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pyparsing" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "httptools" = {
    version = "0.8.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ba/53/771bd891eb0f236f32145d6a1775777ec85745f3cc983a1f23d1a3b8ddfe/httptools-0.8.0-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:c4a9f1707e4823d54dfec6c33fa3697d302aed536ed352a7ebb5a061ddb869d0";
      platformTags = [ "manylinux1_x86_64" "manylinux_2_28_x86_64" "manylinux_2_5_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "httpx" = {
    version = "0.28.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2a/39/e50c7c3a983047577ee07d2a9e53faf5a69493943ec3f6a384bdc792deb2/httpx-0.28.1-py3-none-any.whl";
      hash = "sha256:d909fcccc110f8c7faf814ca82a9a4d816bc5a6dbfea25d6591d6985b8ba59ad";
      platformTags = [ "any" ];
    };
    dependencies = {
      "anyio" = [  ];
      "certifi" = [  ];
      "httpcore" = [  ];
      "idna" = [  ];
    };
    optionalDependencies = {
      "http2" = {
        "h2" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "hyperframe" = {
    version = "6.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/48/30/47d0bf6072f7252e6521f3447ccfa40b421b6824517f82854703d0f5a98b/hyperframe-6.1.0-py3-none-any.whl";
      hash = "sha256:b03380493a519fce58ea5af42e4a42317bf9bd425596f7a0835ffce80f1a42e5";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "hyperlink" = {
    version = "21.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6e/aa/8caf6a0a3e62863cbb9dab27135660acba46903b703e224f14f447e57934/hyperlink-21.0.0-py2.py3-none-any.whl";
      hash = "sha256:e6b14c37ecb73e89c77d78cdb4c2cc8f3fb59a885c5b3f819ff4ed80f25af1b4";
      platformTags = [ "any" ];
    };
    dependencies = {
      "idna" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "idna" = {
    version = "3.18";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1e/5e/d4e9f1a599fb8e573b7b87160658329fbf28d19eac2718f51fc3def3aa5a/idna-3.18-py3-none-any.whl";
      hash = "sha256:7f952cbe720b688055e3f87de14f5c3e5fdaa8bc3928985c4077ca689de849a2";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "importlib-metadata" = {
    version = "9.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/38/3d/2d244233ac4f76e38533cfcb2991c9eb4c7bf688ae0a036d30725b8faafe/importlib_metadata-9.0.0-py3-none-any.whl";
      hash = "sha256:2d21d1cc5a017bd0559e36150c21c830ab1dc304dedd1b7ea85d20f45ef3edd7";
      platformTags = [ "any" ];
    };
    dependencies = {
      "zipp" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "importlib-resources" = {
    version = "7.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8a/db/55a262f3606bebcae07cc14095338471ad7c0bbcaa37707e6f0ee49725b7/importlib_resources-7.1.0-py3-none-any.whl";
      hash = "sha256:1bd7b48b4088eddb2cd16382150bb515af0bd2c70128194392725f82ad2c96a1";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "incremental" = {
    version = "24.11.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1d/55/0f4df2a44053867ea9cbea73fc588b03c55605cd695cee0a3d86f0029cb2/incremental-24.11.0-py3-none-any.whl";
      hash = "sha256:a34450716b1c4341fe6676a0598e88a39e04189f4dce5dc96f656e040baa10b3";
      platformTags = [ "any" ];
    };
    dependencies = {
      "packaging" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "inflection" = {
    version = "0.5.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/59/91/aa6bde563e0085a02a435aa99b49ef75b0a4b062635e606dab23ce18d720/inflection-0.5.1-py2.py3-none-any.whl";
      hash = "sha256:f38b2b640938a4f35ade69ac3d053042959b62a0f1076a5bbaa1b9526605a8a2";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "iniconfig" = {
    version = "2.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cb/b1/3846dd7f199d53cb17f49cba7e651e9ce294d8497c8c150530ed11865bb8/iniconfig-2.3.0-py3-none-any.whl";
      hash = "sha256:f631c04d2c48c52b84d0d0549c99ff3859c98df65b3101406327ecc7d53fbf12";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "invoke" = {
    version = "3.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5a/de/bbc12563bbf979618d17625a4e753ff7a078523e28d870d3626daa97261a/invoke-3.0.3-py3-none-any.whl";
      hash = "sha256:f11327165e5cbb89b2ad1d88d3292b5113332c43b8553b494da435d6ec6f5053";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jinja2" = {
    version = "3.1.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/62/a1/3d680cbfd5f4b8f15abc1d571870c5fc3e594bb582bc3b64ea099db13e56/jinja2-3.1.6-py3-none-any.whl";
      hash = "sha256:85ece4451f492d0c13c5dd7c13a64681a86afae63a5f347908daf103ce6d2f67";
      platformTags = [ "any" ];
    };
    dependencies = {
      "markupsafe" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jinxed" = {
    version = "2.0.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a2/b8/fe4e07cffa35c13fb8c7d21062082f27c89663f3009ec7d0c9b6908faa10/jinxed-2.0.4-py2.py3-none-any.whl";
      hash = "sha256:58ae0a4a2930b51e9de162208c356b382f5e25b3bc0ad73e2013b02a62d84e8b";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jmespath" = {
    version = "1.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/14/2f/967ba146e6d58cf6a652da73885f52fc68001525b4197effc174321d70b4/jmespath-1.1.0-py3-none-any.whl";
      hash = "sha256:a5663118de4908c91729bea0acadca56526eb2698e83de10cd116ae0f4e97c64";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jsii" = {
    version = "1.139.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/33/3e/fce01768f79b2d5d0cf6258b55045f4b083ee86fd5de24c1af38168312ab/jsii-1.139.0-py3-none-any.whl";
      hash = "sha256:11468f767c6da698ed9888a04352850af33ccccfec7656475626caf36fca8bbb";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "cattrs" = [  ];
      "publication" = [  ];
      "python-dateutil" = [  ];
      "typeguard" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jsonpatch" = {
    version = "1.33";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/73/07/02e16ed01e04a374e644b575638ec7987ae846d25ad97bcc9945a3ee4b0e/jsonpatch-1.33-py2.py3-none-any.whl";
      hash = "sha256:0ae28c0cd062bbd8b8ecc26d7d164fbbea9652a1a3693f3b956c1eae5145dade";
      platformTags = [ "any" ];
    };
    dependencies = {
      "jsonpointer" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jsonpointer" = {
    version = "3.1.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9e/6a/a83720e953b1682d2d109d3c2dbb0bc9bf28cc1cbc205be4ef4be5da709d/jsonpointer-3.1.1-py3-none-any.whl";
      hash = "sha256:8ff8b95779d071ba472cf5bc913028df06031797532f08a7d5b602d8b2a488ca";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jsonschema" = {
    version = "4.26.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/69/90/f63fb5873511e014207a475e2bb4e8b2e570d655b00ac19a9a0ca0a385ee/jsonschema-4.26.0-py3-none-any.whl";
      hash = "sha256:d489f15263b8d200f8387e64b4c3a75f06629559fb73deb8fdfb525f2dab50ce";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "jsonschema-specifications" = [  ];
      "referencing" = [  ];
      "rpds-py" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jsonschema-specifications" = {
    version = "2025.9.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/41/45/1a4ed80516f02155c51f51e8cedb3c1902296743db0bbc66608a0db2814f/jsonschema_specifications-2025.9.1-py3-none-any.whl";
      hash = "sha256:98802fee3a11ee76ecaca44429fda8a41bff98b00a0f2838151b113f210cc6fe";
      platformTags = [ "any" ];
    };
    dependencies = {
      "referencing" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "jwcrypto" = {
    version = "1.5.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6e/7c/f87c5db042c4f7b4476346fc0d22f1025a777fee08eebde3720d3b9c4eb5/jwcrypto-1.5.8-py3-none-any.whl";
      hash = "sha256:85aeb475f808d56bbc2f2ed1f6f73e6a317c4011a4321505f02f0aed695a3742";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cryptography" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "k5test" = {
    version = "0.10.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b5/ba/d86d465c589cbed8f872e187e90abbac73eb1453483477771e87e7ee8376/k5test-0.10.4-py2.py3-none-any.whl";
      hash = "sha256:33de7ff10bf99155fe8ee5d5976798ad1db6237214306dadf5a0ae9d6bb0ad03";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "kubernetes" = {
    version = "36.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5b/30/a96d47df739689ac0001ade0afefc16e3b477fc2fb426b568515fdc8afce/kubernetes-36.0.3-py2.py3-none-any.whl";
      hash = "sha256:8fde9241c4b298e6374a069dcf728359b4e72c2fb29489a975ba4e1c047cf10f";
      platformTags = [ "any" ];
    };
    dependencies = {
      "aiohttp" = [  ];
      "certifi" = [  ];
      "durationpy" = [  ];
      "python-dateutil" = [  ];
      "pyyaml" = [  ];
      "requests" = [  ];
      "requests-oauthlib" = [  ];
      "six" = [  ];
      "urllib3" = [  ];
      "websocket-client" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ldap3" = {
    version = "2.9.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/4e/f6/71d6ec9f18da0b2201287ce9db6afb1a1f637dedb3f0703409558981c723/ldap3-2.9.1-py2.py3-none-any.whl";
      hash = "sha256:5869596fc4948797020d3f03b7939da938778a0f9e2009f7a072ccf92b8e8d70";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pyasn1" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "librt" = {
    version = "0.11.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0a/7e/f5d92af8486b8272c23b3e686b46ff72d89c8169585eb61eef01a2ac7147/librt-0.11.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:05fb8fb2ab90e21c8d12ea240d744ad514da9baf381ebfa70d91d20d21713175";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "lxml" = {
    version = "6.1.1";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/05/3b/aab6728cae887456f409b4d75e8a01856e4f04bd510de38052a47768b680/lxml-6.1.1.tar.gz";
      hash = "sha256:ba96ae44888e0185281e937633a743ea90d5a196c6000f82565ebb0580012d40";
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "lxml-stubs" = {
    version = "0.5.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1f/c9/e0f8e4e6e8a69e5959b06499582dca6349db6769cc7fdfb8a02a7c75a9ae/lxml_stubs-0.5.1-py3-none-any.whl";
      hash = "sha256:1f689e5dbc4b9247cb09ae820c7d34daeb1fdbd1db06123814b856dae7787272";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "markdown-it-py" = {
    version = "4.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b3/81/4da04ced5a082363ecfa159c010d200ecbd959ae410c10c0264a38cac0f5/markdown_it_py-4.2.0-py3-none-any.whl";
      hash = "sha256:9f7ebbcd14fe59494226453aed97c1070d83f8d24b6fc3a3bcf9a38092641c4a";
      platformTags = [ "any" ];
    };
    dependencies = {
      "mdurl" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "markdown2" = {
    version = "2.5.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/43/af/4b3891eb0a49d6cfd5cbf3e9bf514c943afc2b0f13e2c57cc57cd88ecc21/markdown2-2.5.5-py3-none-any.whl";
      hash = "sha256:be798587e09d1f52d2e4d96a649c4b82a778c75f9929aad52a2c95747fa26941";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "markupsafe" = {
    version = "3.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/41/3c/a36c2450754618e62008bf7435ccb0f88053e07592e6028a34776213d877/markupsafe-3.0.3-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:457a69a9577064c05a97c41f4e65148652db078a3a509039e64d3467b9e7ef97";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "maxminddb" = {
    version = "3.1.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d3/13/7914f150c633e8acbbcde6e37b58a280f79888d5668ae5a50bd3846fde2b/maxminddb-3.1.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:7bf4df891b71bb30ef0583effb0e694f610649ace69212def73dd20cc4ae8038";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "mdurl" = {
    version = "0.1.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b3/38/89ba8ad64ae25be8de66a6d463314cf1eb366222074cfda9ee839c56a4b4/mdurl-0.1.2-py3-none-any.whl";
      hash = "sha256:84008a41e51615a49fc9966191ff91509e3c40b939176e643fd50a5c2196b8f8";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-abstractions" = {
    version = "1.11.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1a/45/ef8a3dc123bf22eda20a88bfc100912ad3b1678d5fe89001eacf2e873657/microsoft_kiota_abstractions-1.11.6-py3-none-any.whl";
      hash = "sha256:9ca952adfd4abc3688db4082b98a971c26759368e63a6a3077dbb881b392fd7b";
      platformTags = [ "any" ];
    };
    dependencies = {
      "opentelemetry-api" = [  ];
      "opentelemetry-sdk" = [  ];
      "std-uritemplate" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-authentication-azure" = {
    version = "1.11.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/55/43/e02c82493ef1c8953210627f8f525d6e165ea31f3ece6b3acacccc82df89/microsoft_kiota_authentication_azure-1.11.6-py3-none-any.whl";
      hash = "sha256:8d23455357b39113595ec36259d7f27dfd0825a5f72db7a3216d9e0d0eccfb0d";
      platformTags = [ "any" ];
    };
    dependencies = {
      "aiohttp" = [  ];
      "azure-core" = [  ];
      "microsoft-kiota-abstractions" = [  ];
      "opentelemetry-api" = [  ];
      "opentelemetry-sdk" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-http" = {
    version = "1.11.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9a/35/975336e01aaf2c319e77d64671bfb18c6114b3e3d5bfb0cf6fc7469f37a8/microsoft_kiota_http-1.11.6-py3-none-any.whl";
      hash = "sha256:ce11fec36b21cdac697bf73a17b0c0148246e2607ee9c57c50f8fcee1d964ea0";
      platformTags = [ "any" ];
    };
    dependencies = {
      "httpx" = [ "http2" ];
      "microsoft-kiota-abstractions" = [  ];
      "opentelemetry-api" = [  ];
      "opentelemetry-sdk" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-serialization-form" = {
    version = "1.11.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/20/55/44da586cf8edcd185ff90773d99d99d73648c71ac20c1ea955df24ff20a3/microsoft_kiota_serialization_form-1.11.6-py3-none-any.whl";
      hash = "sha256:aa4a1f26208cf8dcb47c2a320cc4fb77ede543f40ada43b9f5cf90c0c0a315a1";
      platformTags = [ "any" ];
    };
    dependencies = {
      "microsoft-kiota-abstractions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-serialization-json" = {
    version = "1.11.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/bb/e4/6f148274b47eeb277059d57011243d1456c75be630710e95cab53bee89a4/microsoft_kiota_serialization_json-1.11.6-py3-none-any.whl";
      hash = "sha256:d8df49f5f141cbed8119007e0cd3bbd5bfed207cafb2ed0d70dcb80a9ab5a30e";
      platformTags = [ "any" ];
    };
    dependencies = {
      "microsoft-kiota-abstractions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-serialization-multipart" = {
    version = "1.11.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/98/94/1fdc35f1a7f644f5cb0fd1bd1f76daaa5ef63d63ffcb84022a7ba6b70442/microsoft_kiota_serialization_multipart-1.11.6-py3-none-any.whl";
      hash = "sha256:5b4b13b22c1adcac2b9f99b1f84124e556cc59e6d039b37cbc15abe03c49e12e";
      platformTags = [ "any" ];
    };
    dependencies = {
      "microsoft-kiota-abstractions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-serialization-text" = {
    version = "1.11.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b4/ef/89b1cb51031ec865f799c46f5783d15eee5544abce0be2d3bc5ad1fd5a32/microsoft_kiota_serialization_text-1.11.6-py3-none-any.whl";
      hash = "sha256:4063af8dcb9624b42183fe8e1588fe2498b00c63a7ec82780e471494ae2ab1be";
      platformTags = [ "any" ];
    };
    dependencies = {
      "microsoft-kiota-abstractions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "msal" = {
    version = "1.37.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/94/b0/d807279f4b55d16d1f120d5ac4344c6e39b56732e2a224d40bded7fd67ad/msal-1.37.0-py3-none-any.whl";
      hash = "sha256:dd17e95a7c71bce75e8108113438ba7c4a086b3bcad4f57a8c09b7af3d753c2d";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cryptography" = [  ];
      "pyjwt" = [ "crypto" ];
      "requests" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "msal-extensions" = {
    version = "1.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5e/75/bd9b7bb966668920f06b200e84454c8f3566b102183bc55c5473d96cb2b9/msal_extensions-1.3.1-py3-none-any.whl";
      hash = "sha256:96d3de4d034504e969ac5e85bae8106c8373b5c6568e4c8fa7af2eca9dbe6bca";
      platformTags = [ "any" ];
    };
    dependencies = {
      "msal" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "msgpack" = {
    version = "1.2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/19/03/8c63e8cf52958534ef688625965ab04c269a6cadd8caef16758b380a821a/msgpack-1.2.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:0e2bf9280bceb5efca998435904b5d3e9fdbcc11d90dc9df30aec7973252b720";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "msgraph-core" = {
    version = "1.5.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b5/86/0acc90e555be33ff77d0ddad4d30f4f16706b44b6ac170beaebfae3aa1fc/msgraph_core-1.5.1-py3-none-any.whl";
      hash = "sha256:929758ca0ba5dc4231aff051d7dda93f4faba2dbf781e178ef86d36b4592ea12";
      platformTags = [ "any" ];
    };
    dependencies = {
      "httpx" = [ "http2" ];
      "microsoft-kiota-abstractions" = [  ];
      "microsoft-kiota-authentication-azure" = [  ];
      "microsoft-kiota-http" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "msgraph-sdk" = {
    version = "1.60.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/70/4c/9e0c3195f282844b17afe7d50acb057f511ee241b90ebc3296c3d0e4f693/msgraph_sdk-1.60.0-py3-none-any.whl";
      hash = "sha256:2cc481ca7645711f6f97cba5737840ada1f44bf553c3673b60d573988f21830f";
      platformTags = [ "any" ];
    };
    dependencies = {
      "azure-identity" = [  ];
      "microsoft-kiota-serialization-form" = [  ];
      "microsoft-kiota-serialization-json" = [  ];
      "microsoft-kiota-serialization-multipart" = [  ];
      "microsoft-kiota-serialization-text" = [  ];
      "msgraph-core" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "msgspec" = {
    version = "0.21.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/25/1f/cca084ca2572810fff12ea9dbdcbe39eac048f40daf4a9077b49fcbe8cee/msgspec-0.21.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:3d6b9dc50948eaf65df54d2fd0ff66e6d8c32f116037209ee861810eb9b676cb";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "multidict" = {
    version = "6.7.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fe/3b/8ec5074bcfc450fe84273713b4b0a0dd47c0249358f5d82eb8104ffe2520/multidict-6.7.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:7eee46ccb30ff48a1e35bb818cc90846c6be2b68240e42a78599166722cea709";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "mypy" = {
    version = "2.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/51/4d/b6d34db183133b83761b9199a82d31557cdbb70a380d8c3b3438e11882a3/mypy-2.1.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:c90345fc182dc363b891350457ec69c35140858538f38b4540845afcc32b1aef";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {
      "ast-serialize" = [  ];
      "librt" = [  ];
      "mypy-extensions" = [  ];
      "pathspec" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "mypy-extensions" = {
    version = "1.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/79/7b/2c79738432f5c924bef5071f933bcc9efd0473bac3b4aa584a6f7c1c8df8/mypy_extensions-1.1.0-py3-none-any.whl";
      hash = "sha256:1be4cccdb0f2482337c4743e60421de3a356cd97508abadd57d47403e94f5505";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "netaddr" = {
    version = "1.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/12/cc/f4fe2c7ce68b92cbf5b2d379ca366e1edae38cccaad00f69f529b460c3ef/netaddr-1.3.0-py3-none-any.whl";
      hash = "sha256:c2c6a8ebe5554ce33b7d5b3a306b71bbb373e000bbbf2350dd5213cc56e3dbbe";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "oauthlib" = {
    version = "3.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/be/9c/92789c596b8df838baa98fa71844d84283302f7604ed565dafe5a6b5041a/oauthlib-3.3.1-py3-none-any.whl";
      hash = "sha256:88119c938d2b8fb88561af5f6ee0eec8cc8d552b7bb1f712743136eb7523b7a1";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "opencontainers" = {
    version = "0.0.14";
    fmt = "git";
    source = {
      type = "git";
      url = "https://forge.ops.eblu.me/mirrors/oci-python";
      rev = "ceb4fcc090851717a3069d78e85ceb1e86c2740c";
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "opentelemetry-api" = {
    version = "1.43.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/17/83/6dba32b85f31868400440dc7ad2ca1eab94cbbf3a7b0459ed39f8311a9e2/opentelemetry_api-1.43.0-py3-none-any.whl";
      hash = "sha256:20acf45e9b21851926835292e4045d290acade1edd2ff3de86d2f069687ba1fd";
      platformTags = [ "any" ];
    };
    dependencies = {
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "opentelemetry-sdk" = {
    version = "1.43.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/49/e3/b17be23af124201c9f52eececd4cc8ddfed1597d37b4ee771895d325805c/opentelemetry_sdk-1.43.0-py3-none-any.whl";
      hash = "sha256:d1323a547c1ce69d6a069a17a44b7da82bb8b332051ecb074041f87642c86823";
      platformTags = [ "any" ];
    };
    dependencies = {
      "opentelemetry-api" = [  ];
      "opentelemetry-semantic-conventions" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "opentelemetry-semantic-conventions" = {
    version = "0.64b0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f2/ca/23ba87a221b574a7c5a99d48849d80bfe8b047624681357e2b002e566187/opentelemetry_semantic_conventions-0.64b0-py3-none-any.whl";
      hash = "sha256:ea77e85e354b8f604ddbe5f3d9135216f982fa4d77e5859ac30f6d8a50505aa6";
      platformTags = [ "any" ];
    };
    dependencies = {
      "opentelemetry-api" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "outcome" = {
    version = "1.3.0.post0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/55/8b/5ab7257531a5d830fc8000c476e63c935488d74609b50f9384a643ec0a62/outcome-1.3.0.post0-py2.py3-none-any.whl";
      hash = "sha256:e771c5ce06d1415e356078d3bdd68523f284b4ce5419828922b6871e65eda82b";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "packaging" = {
    version = "26.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/df/b2/87e62e8c3e2f4b32e5fe99e0b86d576da1312593b39f47d8ceef365e95ed/packaging-26.2-py3-none-any.whl";
      hash = "sha256:5fc45236b9446107ff2415ce77c807cee2862cb6fac22b8a73826d0693b0980e";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "paramiko" = {
    version = "5.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/82/5b/eadf6d45de38d30ab603f49393b6cd2cbe7e233af8cf90197e32782b68a9/paramiko-5.0.0-py3-none-any.whl";
      hash = "sha256:b7044611c30140d9a75261653210e2002977b71a0497ff3ba0d98d7edbf62f7c";
      platformTags = [ "any" ];
    };
    dependencies = {
      "bcrypt" = [  ];
      "cryptography" = [  ];
      "invoke" = [  ];
      "pynacl" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pathspec" = {
    version = "1.1.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f1/d9/7fb5aa316bc299258e68c73ba3bddbc499654a07f151cba08f6153988714/pathspec-1.1.1-py3-none-any.whl";
      hash = "sha256:a00ce642f577bf7f473932318056212bc4f8bfdf53128c78bbd5af0b9b20b189";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pdoc" = {
    version = "16.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/16/a1/56a17b7f9e18c2bb8df73f3833345d97083b344708b97bab148fdd7e0b82/pdoc-16.0.0-py3-none-any.whl";
      hash = "sha256:070b51de2743b9b1a4e0ab193a06c9e6c12cf4151cf9137656eebb16e8556628";
      platformTags = [ "any" ];
    };
    dependencies = {
      "jinja2" = [  ];
      "markdown2" = [  ];
      "markupsafe" = [  ];
      "pygments" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "platformdirs" = {
    version = "4.10.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/81/e6/cd9575ac904136b3cbf7aa7ee819ef86eedb7274e46f230e94ea4342e729/platformdirs-4.10.0-py3-none-any.whl";
      hash = "sha256:fb516cdb12eb0d857d0cd85a7c57cea4d060bee4578d6cf5a14dfdf8cbf8784a";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pluggy" = {
    version = "1.6.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/54/20/4d324d65cc6d9205fabedc306948156824eb9f0ee1633355a8f7ec5c66bf/pluggy-1.6.0-py3-none-any.whl";
      hash = "sha256:e920276dd6813095e9377c0bc5566d94c932c33b27a3e3945d8389c374dd4746";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ply" = {
    version = "3.11";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a3/58/35da89ee790598a0700ea49b2a66594140f44dec458c07e8e3d4979137fc/ply-3.11-py2.py3-none-any.whl";
      hash = "sha256:096f9b8350b65ebd2fd1346b12452efe5b9607f7482813ffca50c22722a807ce";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "prometheus-client" = {
    version = "0.25.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8d/9b/d4b1e644385499c8346fa9b622a3f030dce14cd6ef8a1871c221a17a67e7/prometheus_client-0.25.0-py3-none-any.whl";
      hash = "sha256:d5aec89e349a6ec230805d0df882f3807f74fd6c1a2fa86864e3c2279059fed1";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "propcache" = {
    version = "0.5.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2b/76/7f1bfd6afff4c5e38e36a3c6d68eb5f4b7311ea80baf693db78d95b603c4/propcache-0.5.2-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:e00820e192c8dbebcafb383ebbf99030895f09905e7a0eb2e0340a0bcc2bc825";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "proto-plus" = {
    version = "1.28.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7c/20/b122d4626976acb81132036d2ad1bb35a1a8775fceb837ec30964622516a/proto_plus-1.28.0-py3-none-any.whl";
      hash = "sha256:a630604310899e73c59ec302e5765c058d412b2f090b9c79c8822589f14955b8";
      platformTags = [ "any" ];
    };
    dependencies = {
      "protobuf" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "protobuf" = {
    version = "7.35.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e4/be/5b3cfe508bfab6761414ff944e3366eb13be4fd71efcd69450f89ba39f43/protobuf-7.35.1-cp310-abi3-manylinux2014_x86_64.whl";
      hash = "sha256:74758715c53d7158fb76caf4f0cfdacc5329a4b1bb994f865d6cf302d413a1c4";
      platformTags = [ "manylinux2014_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "psycopg" = {
    version = "3.3.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5c/e0/7b3dee031daae7743609ce3c746565d4a3ed7c2c186479eb48e34e838c64/psycopg-3.3.4-py3-none-any.whl";
      hash = "sha256:b6bbc25ccf05c8fad3b061d9db2ef0909a555171b84b07f29458a447253d679a";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {
      "c" = {
        "psycopg-c" = [  ];
      };
      "pool" = {
        "psycopg-pool" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "psycopg-c" = {
    version = "3.3.4";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/21/7c/c08364f2eab2913e4068b3b955d963e7a3491986a85429990969525def30/psycopg_c-3.3.4.tar.gz";
      hash = "sha256:ed8106128b2d04359c185fc9641b4409abfce4d0b6fb1d1ff6800646e27f1a22";
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "psycopg-pool" = {
    version = "3.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/37/ed/89c2c620af0e1660354cd8aabf9f5b21f911597ce22acb37c805d6c86bc8/psycopg_pool-3.3.1-py3-none-any.whl";
      hash = "sha256:2af5b432941c4c9ad5c87b3fa410aec910ec8f7c122855897983a06c45f2e4b5";
      platformTags = [ "any" ];
    };
    dependencies = {
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "publication" = {
    version = "0.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f8/d3/6308debad7afcdb3ea5f50b4b3d852f41eb566a311fbcb4da23755a28155/publication-0.0.3-py2.py3-none-any.whl";
      hash = "sha256:0248885351febc11d8a1098d5c8e3ab2dabcf3e8c0c96db1e17ecd12b53afbe6";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyasn1" = {
    version = "0.6.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9a/3b/6163796d69c3977d1e4287bea4a6979161cbbdd170ebb430511e8e1999ce/pyasn1-0.6.4-py3-none-any.whl";
      hash = "sha256:deda9277cfd454080ec40b207fb6df82206a3a2688735233cdcd8d3d565f088b";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyasn1-modules" = {
    version = "0.4.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/47/8d/d529b5d697919ba8c11ad626e835d4039be708a35b0d22de83a269a6682c/pyasn1_modules-0.4.2-py3-none-any.whl";
      hash = "sha256:29253a9207ce32b64c3ac6600edc75368f98473906e8fd1043bd6b5b1de2c14a";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pyasn1" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pycparser" = {
    version = "3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0c/c3/44f3fbbfa403ea2a7c779186dc20772604442dde72947e7d01069cbe98e3/pycparser-3.0-py3-none-any.whl";
      hash = "sha256:b727414169a36b7d524c1c3e31839a521725078d7b2ff038656844266160a992";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pydantic" = {
    version = "2.13.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fd/7b/122376b1fd3c62c1ed9dc80c931ace4844b3c55407b6fb2d199377c9736f/pydantic-2.13.4-py3-none-any.whl";
      hash = "sha256:45a282cde31d808236fd7ea9d919b128653c8b38b393d1c4ab335c62924d9aba";
      platformTags = [ "any" ];
    };
    dependencies = {
      "annotated-types" = [  ];
      "pydantic-core" = [  ];
      "typing-extensions" = [  ];
      "typing-inspection" = [  ];
    };
    optionalDependencies = {
      "email" = {
        "email-validator" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "pydantic-core" = {
    version = "2.46.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/89/1d/8eff589b45bb8190a9d12c49cfad0f176a5cbd1534908a6b5125e2886239/pydantic_core-2.46.4-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:7a5f930472650a82629163023e630d160863fce524c616f4e5186e5de9d9a49b";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pydantic-scim" = {
    version = "0.0.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d7/a9/6b8df69afdb5338aea75b04e39ad38956820843b030d0bd8ad56398a96d6/pydantic_scim-0.0.8-py3-none-any.whl";
      hash = "sha256:407b3bf55240947155c77a6dd839881d63368c61d64076d6b167ef124ceac79a";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pydantic" = [ "email" ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pygments" = {
    version = "2.20.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f4/7e/a72dd26f3b0f4f2bf1dd8923c85f7ceb43172af56d63c7383eb62b332364/pygments-2.20.0-py3-none-any.whl";
      hash = "sha256:81a9e26dd42fd28a23a2d169d86d7ac03b46e2f8b59ed4698fb4785f946d0176";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyjwt" = {
    version = "2.15.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/50/ca/44de4e75f8aadc457f0634be3b542815078ded46dca30efb960edeecad6e/pyjwt-2.15.1-py3-none-any.whl";
      hash = "sha256:42d59d631f7768a1028a64c7ff581a9bf7519804daf91fc5b6c56e30eec5e193";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {
      "crypto" = {
        "cryptography" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "pynacl" = {
    version = "1.6.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7f/81/d60984052df5c97b1d24365bc1e30024379b42c4edcd79d2436b1b9806f2/pynacl-1.6.2-cp38-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:22de65bb9010a725b0dac248f353bb072969c94fa8d6b1f34b87d7953cf7bbe4";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {
      "cffi" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyopenssl" = {
    version = "26.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/51/ad/2cf6d3fa2fae5c79e1ed9960c0d42badd0f94d81dd12b50604cdc839e648/pyopenssl-26.4.0-py3-none-any.whl";
      hash = "sha256:f0eb0cb2d581d3ad2b9c489468485e7f2ab6727d08401bcf9d824c3caddf3c1c";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cryptography" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyparsing" = {
    version = "3.3.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/10/bd/c038d7cc38edc1aa5bf91ab8068b63d4308c66c4c8bb3cbba7dfbc049f9c/pyparsing-3.3.2-py3-none-any.whl";
      hash = "sha256:850ba148bd908d7e2411587e247a1e4f0327839c40e2e5e6d05a007ecc69911d";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyrad" = {
    version = "2.5.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/19/54/5b0ded99e5a8390be3e5c29513b9f53c01e5741256b7f73a20c0c606f29d/pyrad-2.5.4-py3-none-any.whl";
      hash = "sha256:2c75e8a5642df262071d631e4552e08d9d5bed0c62699d83c24105c4fbfc2cff";
      platformTags = [ "any" ];
    };
    dependencies = {
      "netaddr" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyroscope-io" = {
    version = "1.2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a7/7e/908489444509ec91ba0f2d165ba745a0315dcf8eb9a17f55af3b17bec708/pyroscope_io-1.2.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:5ec8e2a8954de298000811af743060c2ec85295c452a8b3e0226be11ffaf1c80";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pysocks" = {
    version = "1.7.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8d/59/b4572118e098ac8e46e399a1dd0f2d85403ce8bbaad9ec79373ed6badaf9/PySocks-1.7.1-py3-none-any.whl";
      hash = "sha256:2725bd0a9925919b9b51739eea5f9e2bae91e83288108a9ad338b2e3a4435ee5";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pytest" = {
    version = "9.1.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/24/25/1de2678b631f5a49215c6c96fff41ba892b0a34df68d6d80292b1b48aa7f/pytest-9.1.1-py3-none-any.whl";
      hash = "sha256:37a86b45efb9a47a61a36449063e8e18d0cab3161329fc099eb21783169c4f0c";
      platformTags = [ "any" ];
    };
    dependencies = {
      "iniconfig" = [  ];
      "packaging" = [  ];
      "pluggy" = [  ];
      "pygments" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pytest-django" = {
    version = "4.12.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/83/a5/41d091f697c09609e7ef1d5d61925494e0454ebf51de7de05f0f0a728f1d/pytest_django-4.12.0-py3-none-any.whl";
      hash = "sha256:3ff300c49f8350ba2953b90297d23bf5f589db69545f56f1ec5f8cff5da83e85";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pytest" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pytest-flakefinder" = {
    version = "1.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/33/8b/06787150d0fd0cbd3a8054262b56f91631c7778c1bc91bf4637e47f909ad/pytest_flakefinder-1.1.0-py2.py3-none-any.whl";
      hash = "sha256:741e0e8eea427052f5b8c89c2b3c3019a50c39a59ce4df6a305a2c2d9ba2bd13";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pytest" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pytest-github-actions-annotate-failures" = {
    version = "0.4.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3c/09/c44e658f3a27c588c2017d858c8b0fa962612af9b74326beabbf010c839c/pytest_github_actions_annotate_failures-0.4.2-py3-none-any.whl";
      hash = "sha256:02911cd3b55f235328a334f8ca6037a89944398b8e8b028c82de97111eff4071";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pytest" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pytest-randomly" = {
    version = "4.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9a/db/2df9a1fca597a273f957a559c20c2d95d629928384507b2afa43ba6909d1/pytest_randomly-4.1.0-py3-none-any.whl";
      hash = "sha256:f55e89e53367b090c0c053697d7f9d77595543d0e0516c93978b50c0f6b252f9";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pytest" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pytest-timeout" = {
    version = "2.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fa/b6/3127540ecdf1464a00e5a01ee60a1b09175f6913f0644ac748494d9c4b21/pytest_timeout-2.4.0-py3-none-any.whl";
      hash = "sha256:c42667e5cdadb151aeb5b26d114aff6bdf5a907f176a007a30b940d3d865b5c2";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pytest" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "python-dateutil" = {
    version = "2.9.0.post0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ec/57/56b9bcc3c9c6a792fcbaf139543cee77261f3651ca9da0c93f5c1221264b/python_dateutil-2.9.0.post0-py2.py3-none-any.whl";
      hash = "sha256:a8b2bc7bffae282281c8140a97d3aa9c14da0b136dfe83f850eea9a5f7470427";
      platformTags = [ "any" ];
    };
    dependencies = {
      "six" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "python-dotenv" = {
    version = "1.2.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0b/d7/1959b9648791274998a9c3526f6d0ec8fd2233e4d4acce81bbae76b44b2a/python_dotenv-1.2.2-py3-none-any.whl";
      hash = "sha256:1d8214789a24de455a8b8bd8ae6fe3c6b69a5e3d64aa8a8e5d68e694bbcb285a";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "python-kadmin-rs" = {
    version = "0.7.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f9/d8/c2706859bec76cc629d7665effd6fd540d31b10631d800796269806c86cc/python_kadmin_rs-0.7.2-cp314-cp314-manylinux_2_28_x86_64.whl";
      hash = "sha256:cb51f980597383c4f4adb308e3e4c0c796e5dba560f68b17e4b3cd269c043ae2";
      platformTags = [ "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pytokens" = {
    version = "0.4.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0f/95/70d7041273890f9f97a24234c00b746e8da86df462620194cef1d411ddeb/pytokens-0.4.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:dc74c035f9bfca0255c1af77ddd2d6ae8419012805453e4b0e7513e17904545d";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyxdg" = {
    version = "0.28";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e5/8d/cf41b66a8110670e3ad03dab9b759704eeed07fa96e90fdc0357b2ba70e2/pyxdg-0.28-py2.py3-none-any.whl";
      hash = "sha256:bdaf595999a0178ecea4052b7f4195569c1ff4d344567bccdc12dfdf02d545ab";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyyaml" = {
    version = "6.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/88/f9/16491d7ed2a919954993e48aa941b200f38040928474c9e85ea9e64222c3/pyyaml-6.0.3-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:c458b6d084f9b935061bc36216e8a69a7e293a2f1e68bf956dcd9e6cbcd143f5";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "referencing" = {
    version = "0.37.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2c/58/ca301544e1fa93ed4f80d724bf5b194f6e4b945841c5bfd555878eea9fcb/referencing-0.37.0-py3-none-any.whl";
      hash = "sha256:381329a9f99628c9069361716891d34ad94af76e461dcb0335825aecc7692231";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "rpds-py" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "requests" = {
    version = "2.34.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a0/f4/c67b0b3f1b9245e8d266f0f112c500d50e5b4e83cb6f3b71b6528104182a/requests-2.34.2-py3-none-any.whl";
      hash = "sha256:2a0d60c172f83ac6ab31e4554906c0f3b3588d37b5cb939b1c061f4907e278e0";
      platformTags = [ "any" ];
    };
    dependencies = {
      "certifi" = [  ];
      "charset-normalizer" = [  ];
      "idna" = [  ];
      "urllib3" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "requests-mock" = {
    version = "1.12.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/97/ec/889fbc557727da0c34a33850950310240f2040f3b1955175fdb2b36a8910/requests_mock-1.12.1-py2.py3-none-any.whl";
      hash = "sha256:b1e37054004cdd5e56c84454cc7df12b25f90f382159087f4b6915aaeef39563";
      platformTags = [ "any" ];
    };
    dependencies = {
      "requests" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "requests-oauthlib" = {
    version = "2.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3b/5d/63d4ae3b9daea098d5d6f5da83984853c1bbacd5dc826764b249fe119d24/requests_oauthlib-2.0.0-py2.py3-none-any.whl";
      hash = "sha256:7dd8a5c40426b779b0868c404bdef9768deccf22749cde15852df527e6269b36";
      platformTags = [ "any" ];
    };
    dependencies = {
      "oauthlib" = [  ];
      "requests" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "rich" = {
    version = "15.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/82/3b/64d4899d73f91ba49a8c18a8ff3f0ea8f1c1d75481760df8c68ef5235bf5/rich-15.0.0-py3-none-any.whl";
      hash = "sha256:33bd4ef74232fb73fe9279a257718407f169c09b78a87ad3d296f548e27de0bb";
      platformTags = [ "any" ];
    };
    dependencies = {
      "markdown-it-py" = [  ];
      "pygments" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "rpds-py" = {
    version = "2026.5.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/19/c8/d63bb75b68afe77b229e3021c6031bcaf01da5db5b0e69d0d10f9ba679a7/rpds_py-2026.5.1-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:21846aac0ed2e0589f38c12dc44e77bb64e494b771eadbcf169cba00566ba7ba";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ruff" = {
    version = "0.15.22";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f6/f9/a0d4871d12fae702eb1f41b686caf05f1f8b124dc6db6f784f53d74918fa/ruff-0.15.22-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:365523eb91d9224e1bcb03b022fbf0facb8f9e23792a2c53d9d4b3924bdbdebb";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "s3transfer" = {
    version = "0.19.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/46/5f/4c174edad94f82de888ac00a5ddd8d07b35609b6c94f0bdf4d74af57703e/s3transfer-0.19.0-py3-none-any.whl";
      hash = "sha256:777cc2415536f1debadb5c2ef7779275d0fc0fe0e042411cdd6caebeb2685262";
      platformTags = [ "any" ];
    };
    dependencies = {
      "botocore" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "scim2-filter-parser" = {
    version = "0.7.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/57/54/b54961bfc5018fa593758c439fe0d4a22fbadfabff49a7559850af9a79e1/scim2_filter_parser-0.7.0-py3-none-any.whl";
      hash = "sha256:a74f90a2d52a77e0f1bc4d77e84b79f88749469f6f7192d64a4f92e4fe50ab69";
      platformTags = [ "any" ];
    };
    dependencies = {
      "sly" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "selenium" = {
    version = "4.46.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/30/f4/365c723a37c7e9ba6a6a19bf0c9e407137703f56a72c6201d0e4cb1432cb/selenium-4.46.0-py3-none-any.whl";
      hash = "sha256:f03e864770a21ab32009961c9d015cb2c6275eba45c926c272e02d90af423aad";
      platformTags = [ "any" ];
    };
    dependencies = {
      "certifi" = [  ];
      "trio" = [  ];
      "trio-websocket" = [  ];
      "typing-extensions" = [  ];
      "urllib3" = [ "socks" ];
      "websocket-client" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "sentry-sdk" = {
    version = "2.66.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/89/d3/726bd88f0eece09ddf431bea4c9191c18e7a8d070b854eb0014d447712ee/sentry_sdk-2.66.1-py3-none-any.whl";
      hash = "sha256:86002793161d9a95ef04bdd8d442e9bfece5d989b755f05d6360215094a7aff6";
      platformTags = [ "any" ];
    };
    dependencies = {
      "certifi" = [  ];
      "urllib3" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "service-identity" = {
    version = "26.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/93/eb/2433e1af4ff903499144de4846569fb3300b816179ae99a03c2f011b666a/service_identity-26.1.0-py3-none-any.whl";
      hash = "sha256:68c32dadbb69135fb951077677e07cd7f6031020f3a8c8f47a28cda8a0742118";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "cryptography" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "setproctitle" = {
    version = "1.3.7";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ab/26/8e3bb082992f19823d831f3d62a89409deb6092e72fc6940962983ffc94f/setproctitle-1.3.7-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:fcb966a6c57cf07cc9448321a08f3be6b11b7635be502669bc1d8745115d7e7f";
      platformTags = [ "manylinux1_x86_64" "manylinux_2_28_x86_64" "manylinux_2_5_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "setuptools" = {
    version = "83.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5d/40/e1e72872c6354b306daef1703549e8e83b4d43cfea356311bf722a043752/setuptools-83.0.0-py3-none-any.whl";
      hash = "sha256:29b23c360f22f414dc7336bb39178cc7bcbf6021ed2733cde173f09dba19abb3";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "six" = {
    version = "1.17.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b7/ce/149a00dd41f10bc29e5921b496af8b574d8413afcd5e30dfa0ed46c2cc5e/six-1.17.0-py2.py3-none-any.whl";
      hash = "sha256:4721f391ed90541fddacab5acf947aa0d3dc7d27b2e1e8eda2be8970586c3274";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "sly" = {
    version = "0.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8e/4d/c96d807295183f2360329cd8d8bf5e8072c53d664125b3858c04153f026e/sly-0.5-py3-none-any.whl";
      hash = "sha256:20485483259eec7f6ba85ff4d2e96a4e50c6621902667fc2695cc8bc2a3e5133";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "sniffio" = {
    version = "1.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e9/44/75a9c9421471a6c4805dbf2356f7c181a29c1879239abab1ea2cc8f38b40/sniffio-1.3.1-py3-none-any.whl";
      hash = "sha256:2f6da418d1f1e0fddd844478f41680e794e6051915791a034ff65e5f100525a2";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "sortedcontainers" = {
    version = "2.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/32/46/9cb0e58b2deb7f82b84065f37f3bffeb12413f947f9388e4cac22c4621ce/sortedcontainers-2.4.0-py2.py3-none-any.whl";
      hash = "sha256:a163dcaede0f1c021485e957a39245190e74249897e2ae4b2aa38595db237ee0";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "sqlparse" = {
    version = "0.6.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d9/50/f00935da0ec7cbf325f8dc4f772ae46fbc7b672dd62876e73f0a94adda57/sqlparse-0.6.0-py3-none-any.whl";
      hash = "sha256:b861c0288ce2fa56209a9a6412d2e066ac664b3873b89c26c9d8415e8e32996f";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "std-uritemplate" = {
    version = "2.0.10";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/79/5b/86b48580bcebff823102978c36c15eaaca45f2f0c74001dc39e759ff5d10/std_uritemplate-2.0.10-py3-none-any.whl";
      hash = "sha256:bc93137c5718216aaaf6e5a016ce24cb6e356512cedb66182b1f835bc57a55cb";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "stevedore" = {
    version = "5.8.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f5/ac/19f9941c74add59d17694930ec8105d5eddeee4ce56dd8632b765ca16d6c/stevedore-5.8.0-py3-none-any.whl";
      hash = "sha256:88eede9e66ca80e34085b9174e2327da2c61ac91f24f70e41c3ad76e4bb4872b";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "structlog" = {
    version = "26.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a9/18/489c97b834dfff9cf2fc2507cede4bcd4b11e67f84bc462acd1992496f86/structlog-26.1.0-py3-none-any.whl";
      hash = "sha256:e081a26d6c373e6d201eca24eede26d8ffab07f88f477822e679183428d3d91e";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "swagger-spec-validator" = {
    version = "3.0.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f4/ac/31ba87a959b19e640ebc18851438b82b5b66cef02ad31da7468d1d8bd625/swagger_spec_validator-3.0.4-py2.py3-none-any.whl";
      hash = "sha256:1a2a4f4f7076479ae7835d892dd53952ccca9414efa172c440c775cf0ac01f48";
      platformTags = [ "any" ];
    };
    dependencies = {
      "importlib-resources" = [  ];
      "jsonschema" = [  ];
      "pyyaml" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "tenacity" = {
    version = "9.1.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d7/c1/eb8f9debc45d3b7918a32ab756658a0904732f75e555402972246b0b8e71/tenacity-9.1.4-py3-none-any.whl";
      hash = "sha256:6095a360c919085f28c6527de529e76a06ad89b23659fa881ae0649b867a9d55";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "trio" = {
    version = "0.33.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1c/93/dab25dc87ac48da0fe0f6419e07d0bfd98799bed4e05e7b9e0f85a1a4b4b/trio-0.33.0-py3-none-any.whl";
      hash = "sha256:3bd5d87f781d9b0192d592aef28691f8951d6c2e41b7e1da4c25cde6c180ae9b";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "idna" = [  ];
      "outcome" = [  ];
      "sniffio" = [  ];
      "sortedcontainers" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "trio-websocket" = {
    version = "0.12.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c7/19/eb640a397bba49ba49ef9dbe2e7e5c04202ba045b6ce2ec36e9cadc51e04/trio_websocket-0.12.2-py3-none-any.whl";
      hash = "sha256:df605665f1db533f4a386c94525870851096a223adcb97f72a07e8b4beba45b6";
      platformTags = [ "any" ];
    };
    dependencies = {
      "outcome" = [  ];
      "trio" = [  ];
      "wsproto" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "twilio" = {
    version = "9.10.9";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ed/6b/df08b499d01ba6b9f7f42f9dd51b82aab1eb26c93602f3b89179a520494f/twilio-9.10.9-py2.py3-none-any.whl";
      hash = "sha256:1c50bfb394b5dbc044bacab24b2e3b550bee0c08da51c4a1fa4816293303e66c";
      platformTags = [ "any" ];
    };
    dependencies = {
      "aiohttp" = [  ];
      "aiohttp-retry" = [  ];
      "pyjwt" = [  ];
      "requests" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "twisted" = {
    version = "26.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a6/57/bcf4e2370dd218c9aa68a9140a65d86729c73f1d529f7e94786c2766fc72/twisted-26.4.0-py3-none-any.whl";
      hash = "sha256:dc25ea0ebf6511c24f03232ee9f4afa54b291c5d897990e3a39cc4d14a1ef4c0";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "automat" = [  ];
      "constantly" = [  ];
      "hyperlink" = [  ];
      "incremental" = [  ];
      "typing-extensions" = [  ];
      "zope-interface" = [  ];
    };
    optionalDependencies = {
      "tls" = {
        "idna" = [  ];
        "pyopenssl" = [  ];
        "service-identity" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "txaio" = {
    version = "26.6.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/91/68/075bf851e11c9ef65bd6a0426791f0d9a0c7dae0e7f6e0b16ca67334b456/txaio-26.6.1-py3-none-any.whl";
      hash = "sha256:91a84a7825485a367c0b070c7399824c0e1a1e8c071cbdf3882dd3146dab587b";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "typeguard" = {
    version = "2.13.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9a/bb/d43e5c75054e53efce310e79d63df0ac3f25e34c926be5dffb7d283fb2a8/typeguard-2.13.3-py3-none-any.whl";
      hash = "sha256:5e3e3be01e887e7eafae5af63d1f36c849aaa94e3a0112097312aabfa16284f1";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-channels" = {
    version = "4.3.0.20260518";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fc/e3/939312e5a5f184fe54f17e323a81426d19eddde0ed25ed745fcba5c8e515/types_channels-4.3.0.20260518-py3-none-any.whl";
      hash = "sha256:98443bd8a5892d87b535b3b54a409441d401a60df3c426f82a79faae12bdd8e7";
      platformTags = [ "any" ];
    };
    dependencies = {
      "asgiref" = [  ];
      "django-stubs" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-docker" = {
    version = "7.2.0.20260722";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/44/af/cc4cffffbc0c31912230c52c30215dee9e5ad95fd623fbc575cccb6ce183/types_docker-7.2.0.20260722-py3-none-any.whl";
      hash = "sha256:f836f097a011fca0b36d12202dc43298c2941a392eb72fb63c2a2e0c2c771f65";
      platformTags = [ "any" ];
    };
    dependencies = {
      "types-paramiko" = [  ];
      "types-requests" = [  ];
      "urllib3" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-jwcrypto" = {
    version = "1.5.8.20260720";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6b/ef/728dfe98bf0423f8e7e0074ad6f60feaad95982b44d7398fd35f429c08c2/types_jwcrypto-1.5.8.20260720-py3-none-any.whl";
      hash = "sha256:e606fefc5381c71236d6dccd7500f283eb19c22151fb1ef19cefe5589630d376";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cryptography" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-ldap3" = {
    version = "2.9.13.20260518";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2c/d7/2ee992a0957c9a36713935b215f55fcea262eb55002468690369bbac1ed0/types_ldap3-2.9.13.20260518-py3-none-any.whl";
      hash = "sha256:c70656b7e31fc1497ea5e666e7a3a46311898c6b75f526193ba28eb5c649c668";
      platformTags = [ "any" ];
    };
    dependencies = {
      "types-pyasn1" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-paramiko" = {
    version = "5.0.0.20260617";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/50/4d/eab89decb4201dfff665a3b92088f384ff1e165bf6caa447509733bc1bc6/types_paramiko-5.0.0.20260617-py3-none-any.whl";
      hash = "sha256:83d87c396405666524441710ec59e693bca8b19021861456ac0a2401327812f8";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cryptography" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-pyasn1" = {
    version = "0.6.0.20260408";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e1/a5/473e06d5aaec3730aab5a9d40c2044e673c927412c24bd7f3fa0df7e95d3/types_pyasn1-0.6.0.20260408-py3-none-any.whl";
      hash = "sha256:ee7fbd98bce61193c5d4f8f7812fa53cddc5b8cc5ceb9fcda6eea539947c6d6b";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-pyyaml" = {
    version = "6.0.12.20260518";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/06/a2/c01db32be2ae7d6a1689972f3c492b149ee4e164b12fdfd9f64b50888215/types_pyyaml-6.0.12.20260518-py3-none-any.whl";
      hash = "sha256:d2150f75a231c9fe9c7463bd29487d93e60bac90400287351384bc2284eba7cd";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-requests" = {
    version = "2.33.0.20260712";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/62/e7/010c87f559e216d83f9dc51e939633fd0d0ead3377340181ab0e223cd3b5/types_requests-2.33.0.20260712-py3-none-any.whl";
      hash = "sha256:de027e28c171d3da529689cbfa023b0b4eab188c8dfa22fd834eebd2cee6e7bb";
      platformTags = [ "any" ];
    };
    dependencies = {
      "urllib3" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-zxcvbn" = {
    version = "4.5.0.20260518";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ef/d4/ea0d35a3290168e967895f9d0e5121264fabe6555f57e82033def10b8d02/types_zxcvbn-4.5.0.20260518-py3-none-any.whl";
      hash = "sha256:763a9d96a2e84357dbe89b751d570474bb91200d3060cbb4cb7b4583db42a946";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "typing-extensions" = {
    version = "4.15.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/18/67/36e9267722cc04a6b9f15c7f3441c2363321a3ea07da7ae0c0707beb2a9c/typing_extensions-4.15.0-py3-none-any.whl";
      hash = "sha256:f0fa19c6845758ab08074a0cfa8b7aecb71c999ca73d62883bc25cc018c4e548";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "typing-inspection" = {
    version = "0.4.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/dc/9b/47798a6c91d8bdb567fe2698fe81e0c6b7cb7ef4d13da4114b41d239f65d/typing_inspection-0.4.2-py3-none-any.whl";
      hash = "sha256:4ed1cacbdc298c220f1bd249ed5287caa16f34d44ef4e9c3d0cbad5b521545e7";
      platformTags = [ "any" ];
    };
    dependencies = {
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ua-parser" = {
    version = "1.0.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a9/7c/6367995ff57aaa2d9e1055adbaec2519cf5a979780a83a93fdf8c6ec37be/ua_parser-1.0.2-py3-none-any.whl";
      hash = "sha256:0f8e6d0484af2a9ff804bba5a4fe696e87c028eaba98ad9a7dfae873fef7788a";
      platformTags = [ "any" ];
    };
    dependencies = {
      "ua-parser-builtins" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ua-parser-builtins" = {
    version = "202606";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/51/a3/f26edd95a2ce2ffbf559da432e5ff544e8dcda3673d1c775f71afffb18b7/ua_parser_builtins-202606-py3-none-any.whl";
      hash = "sha256:13b483eb12a5419c1094ce02b7df705fefc6b5d869764b3ffbf6c940c6d014cb";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ujson" = {
    version = "5.13.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6e/b3/0ac9a03551467784067f505df1bb875c639ba32f1da79ce467ab15911ada/ujson-5.13.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:b98bf2faa5e37ecfe752226ea08290031e375a0c43d425a0b955fb3e702a2a71";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "unidecode" = {
    version = "1.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8f/b7/559f59d57d18b44c6d1250d2eeaa676e028b9c527431f5d0736478a73ba1/Unidecode-1.4.0-py3-none-any.whl";
      hash = "sha256:c3c7606c27503ad8d501270406e345ddb480a7b5f38827eafe4fa82a137f0021";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "uritemplate" = {
    version = "4.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a9/99/3ae339466c9183ea5b8ae87b34c0b897eda475d2aec2307cae60e5cd4f29/uritemplate-4.2.0-py3-none-any.whl";
      hash = "sha256:962201ba1c4edcab02e60f9a0d3821e82dfc5d2d6662a21abd533879bdb8a686";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "urllib3" = {
    version = "2.7.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7f/3e/5db95bcf282c52709639744ca2a8b149baccf648e39c8cc87553df9eae0c/urllib3-2.7.0-py3-none-any.whl";
      hash = "sha256:9fb4c81ebbb1ce9531cce37674bbc6f1360472bc18ca9a553ede278ef7276897";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {
      "socks" = {
        "pysocks" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "uvicorn" = {
    version = "0.51.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/45/ec/dbb7e5a6b91f86bfb9eb7d2988a2730907b6a729875b949c7f022e8b88fa/uvicorn-0.51.0-py3-none-any.whl";
      hash = "sha256:5d38af6cd620f2ae3849fb44fd4879e0890aa1febe8d47eb355fb45d93fe6a5b";
      platformTags = [ "any" ];
    };
    dependencies = {
      "click" = [  ];
      "h11" = [  ];
    };
    optionalDependencies = {
      "standard" = {
        "httptools" = [  ];
        "python-dotenv" = [  ];
        "pyyaml" = [  ];
        "uvloop" = [  ];
        "watchfiles" = [  ];
        "websockets" = [  ];
      };
    };
    dependencyGroups = {};
  };
  "uvloop" = {
    version = "0.22.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b5/35/60249e9fd07b32c665192cec7af29e06c7cd96fa1d08b84f012a56a0b38e/uvloop-0.22.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:c1955d5a1dd43198244d47664a5858082a3239766a839b2102a269aaff7a4e25";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "watchdog" = {
    version = "6.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b5/e8/dbf020b4d98251a9860752a094d09a65e1b436ad181faf929983f697048f/watchdog-6.0.0-py3-none-manylinux2014_x86_64.whl";
      hash = "sha256:20ffe5b202af80ab4266dcd3e91aae72bf2da48c0d33bdb15c66658e685e94e2";
      platformTags = [ "manylinux2014_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "watchfiles" = {
    version = "1.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7c/8a/3076c496ca8dafe0e8cd03fcebdfc47be4b1174b4e5b24ff6e396e6b3af2/watchfiles-1.2.0-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:054dc20fd2e3132b4c3883b4a00d72fd6e1f56fdaf89fccd12e8057d74cd74d7";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {
      "anyio" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "wcwidth" = {
    version = "0.8.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/bd/6e/95b0e537de1f4d4301f76f944642c6da50d1511cc7b3d64dc418a66c7509/wcwidth-0.8.1-py3-none-any.whl";
      hash = "sha256:f453740b1e4a4f3291faa37944c555d71056c4da08d59809b307ef4feba695c8";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "webauthn" = {
    version = "3.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1f/d3/38d4efaedba74d854f88b60fd7b80ab37869032f9a9ad54d1892dab20241/webauthn-3.0.0-py3-none-any.whl";
      hash = "sha256:b5d0c02b6efa16be683f8a75abd2073f5e59a15f42623cc22c31f27600259e64";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cbor2" = [  ];
      "cryptography" = [  ];
      "pyasn1" = [  ];
      "pyasn1-modules" = [  ];
      "pyopenssl" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "websocket-client" = {
    version = "1.9.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/34/db/b10e48aa8fff7407e67470363eac595018441cf32d5e1001567a7aeba5d2/websocket_client-1.9.0-py3-none-any.whl";
      hash = "sha256:af248a825037ef591efbf6ed20cc5faa03d3b47b9e5a2230a529eeee1c1fc3ef";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "websockets" = {
    version = "16.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/63/bc/d3e208028de777087e6fb2b122051a6ff7bbcca0d6df9d9c2bf1dd869ae9/websockets-16.0-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:781caf5e8eee67f663126490c2f96f40906594cb86b408a703630f95550a8c3e";
      platformTags = [ "manylinux1_x86_64" "manylinux_2_28_x86_64" "manylinux_2_5_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "wsproto" = {
    version = "1.3.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a4/f5/10b68b7b1544245097b2a1b8238f66f2fc6dcaeb24ba5d917f52bd2eed4f/wsproto-1.3.2-py3-none-any.whl";
      hash = "sha256:61eea322cdf56e8cc904bd3ad7573359a242ba65688716b0710a5eb12beab584";
      platformTags = [ "any" ];
    };
    dependencies = {
      "h11" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "xmlsec" = {
    version = "1.3.17";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/49/14/538b75379e6ab8f688f14d8663e2ab138d9c778bac4999d155b5f33c71c1/xmlsec-1.3.17.tar.gz";
      hash = "sha256:f3fac9ae679f66585925cc00c5f6839ae36c1d03157619571dee18acc05b9c01";
    };
    dependencies = {
      "lxml" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "yarl" = {
    version = "1.24.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c2/53/d81269aaafccea0d33396c03035de997b743f11e648e6e27a0df99c72980/yarl-1.24.2-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:e51b2cf5ec89a8b8470177641ed62a3ba22d74e1e898e06ad53aa77972487208";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {
      "idna" = [  ];
      "multidict" = [  ];
      "propcache" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "zipp" = {
    version = "4.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3a/13/547360d81e6d88d58492968ffda9f9542854f11310ee556fef14260cc886/zipp-4.1.0-py3-none-any.whl";
      hash = "sha256:25ad4e16390cd314347dd8f1de67a2ac538ae658ed4ab9db16029c07c188e97f";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "zope-interface" = {
    version = "8.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a7/eb/37d05b935ede53d79690fecc8d201440084418e590bcfc05f384451c7593/zope_interface-8.5-cp314-cp314-manylinux1_x86_64.manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:9342fb74e2afefdb081bf1df727d209ea56995c6e13f5a0540e6d7aff4beafb8";
      platformTags = [ "manylinux1_x86_64" "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_5_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "zxcvbn" = {
    version = "4.5.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c2/16/7410f8e714a109d43d17f4e27c8eabb351557653a9b570db1bd7dfdfd822/zxcvbn-4.5.0-py2.py3-none-any.whl";
      hash = "sha256:2b6eed621612ce6d65e6e4c7455b966acee87d0280e257956b1f06ccc66bd5ff";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };  };

  # Build-system packages the sdist venv packages need (prebuilt wheels the
  # consumer installs before the `uv build --no-build-isolation` sdist builds).
  buildSystem = {
    "cython" = {
      version = "3.3.0";
      format = "wheel";
      source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9f/57/6d620ebee4fc24d89340427702f6ceaf7b956511d1f2222a88c92c1a72b7/cython-3.3.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:82f94565b6001bab8e31bf52a0911672910b5735910612a2c0f772c719670006";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    };
    "pkgconfig" = {
      version = "1.6.0";
      format = "wheel";
      source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/75/6f/f7ec07fba48f07c555cc4099481df644fbbc12067879072c17ac229f6556/pkgconfig-1.6.0-py3-none-any.whl";
      hash = "sha256:98e71754855e9563838d952a160eb577edabb57782e49853edb5381927e6bea1";
      platformTags = [ "any" ];
    };
    };
    "setuptools" = {
      version = "83.0.0";
      format = "wheel";
      source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5d/40/e1e72872c6354b306daef1703549e8e83b4d43cfea356311bf722a043752/setuptools-83.0.0-py3-none-any.whl";
      hash = "sha256:29b23c360f22f414dc7336bb39178cc7bcbf6021ed2733cde173f09dba19abb3";
      platformTags = [ "any" ];
    };
    };
  };
}
