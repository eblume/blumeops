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
#   authentik         version/2026.5.8 (bdaf0f47786e…)  sha256-g4TurRSLMarStJLV4QWpccyKfoXfkOqOQbLDlnlwUqU=
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
      tag = "version/2026.5.8";
      hash = "sha256-g4TurRSLMarStJLV4QWpccyKfoXfkOqOQbLDlnlwUqU=";
      sha = "bdaf0f47786e751b102aef76e530b0f6a3499a67";
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
  venvOrder = [ "aiohappyeyeballs" "aiohttp" "aiohttp-retry" "aiosignal" "annotated-types" "anyio" "argon2-cffi" "argon2-cffi-bindings" "asgiref" "attrs" "autobahn" "automat" "aws-cdk-asset-awscli-v1" "aws-cdk-asset-node-proxy-agent-v6" "aws-cdk-cloud-assembly-schema" "aws-cdk-lib" "azure-core" "azure-identity" "bandit" "bcrypt" "black" "blessed" "boto3" "botocore" "bpython" "cachetools" "cattrs" "cbor2" "certifi" "cffi" "channels" "charset-normalizer" "click" "colorama" "constantly" "constructs" "coverage" "cron-converter" "cryptography" "curtsies" "cwcwidth" "dacite" "daphne" "debugpy" "decorator" "deepmerge" "defusedxml" "django" "django-countries" "django-filter" "django-model-utils" "django-pgactivity" "django-pglock" "django-pgtrigger" "django-postgres-extra" "django-prometheus" "django-storages" "django-stubs" "django-stubs-ext" "django-tenants" "djangoql" "djangorestframework" "djangorestframework-stubs" "dnspython" "docker" "dramatiq" "drf-jsonschema-serializer" "drf-orjson-renderer" "drf-spectacular" "dumb-init" "duo-client" "durationpy" "email-validator" "fido2" "freezegun" "frozenlist" "geographiclib" "geoip2" "geopy" "google-api-core" "google-api-python-client" "google-auth" "google-auth-httplib2" "googleapis-common-protos" "greenlet" "gssapi" "gunicorn" "h11" "h2" "hpack" "httpcore" "httplib2" "httptools" "httpx" "hyperframe" "hyperlink" "idna" "importlib-metadata" "importlib-resources" "incremental" "inflection" "iniconfig" "invoke" "jinja2" "jmespath" "jsii" "jsonpatch" "jsonpointer" "jsonschema" "jsonschema-specifications" "jwcrypto" "k5test" "kubernetes" "ldap3" "librt" "lxml" "lxml-stubs" "markdown-it-py" "markdown2" "markupsafe" "maxminddb" "mdurl" "microsoft-kiota-abstractions" "microsoft-kiota-authentication-azure" "microsoft-kiota-http" "microsoft-kiota-serialization-form" "microsoft-kiota-serialization-json" "microsoft-kiota-serialization-multipart" "microsoft-kiota-serialization-text" "msal" "msal-extensions" "msgpack" "msgraph-core" "msgraph-sdk" "multidict" "mypy" "mypy-extensions" "netaddr" "oauthlib" "opencontainers" "opentelemetry-api" "opentelemetry-sdk" "opentelemetry-semantic-conventions" "orjson" "outcome" "packaging" "paramiko" "pathspec" "pdoc" "platformdirs" "pluggy" "ply" "prometheus-client" "propcache" "proto-plus" "protobuf" "psycopg" "psycopg-c" "psycopg-pool" "publication" "py-ubjson" "pyasn1" "pyasn1-modules" "pycparser" "pydantic" "pydantic-core" "pydantic-scim" "pygments" "pyjwt" "pynacl" "pyopenssl" "pyparsing" "pyrad" "pysocks" "pytest" "pytest-django" "pytest-flakefinder" "pytest-github-actions-annotate-failures" "pytest-randomly" "pytest-timeout" "python-dateutil" "python-dotenv" "python-kadmin-rs" "pytokens" "pyxdg" "pyyaml" "referencing" "requests" "requests-mock" "requests-oauthlib" "rich" "rpds-py" "ruff" "s3transfer" "scim2-filter-parser" "selenium" "sentry-sdk" "service-identity" "setproctitle" "setuptools" "six" "sly" "sniffio" "sortedcontainers" "sqlparse" "std-uritemplate" "stevedore" "structlog" "swagger-spec-validator" "tenacity" "trio" "trio-websocket" "twilio" "twisted" "txaio" "typeguard" "types-channels" "types-docker" "types-jwcrypto" "types-ldap3" "types-paramiko" "types-pyasn1" "types-pyyaml" "types-requests" "types-zxcvbn" "typing-extensions" "typing-inspection" "ua-parser" "ua-parser-builtins" "ujson" "unidecode" "uritemplate" "urllib3" "uvicorn" "uvloop" "watchdog" "watchfiles" "wcwidth" "webauthn" "websocket-client" "websockets" "wsproto" "xmlsec" "yarl" "zipp" "zope-interface" "zxcvbn" ];

  # Root pyproject [tool.uv] facts the consumer's build phases need.
  config = {
    compile-bytecode = true;
  };

  # 247 venv packages, sorted by name.
  #   source.type: "wheel" -> { url, hash, platformTags }
  #               "sdist" -> { url, hash }
  #               "git"   -> { url, rev }
  #   dependencies/optionalDependencies/dependencyGroups: the trio's mkSpec
  #   of the package's marker-filtered lock edges ({} when none).
  venv = {
  "aiohappyeyeballs" = {
    version = "2.6.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0f/15/5bf3b99495fb160b63f95972b81750f18f7f4e02ad051373b669d17d44f2/aiohappyeyeballs-2.6.1-py3-none-any.whl";
      hash = "sha256:f349ba8f4b75cb25c99c5c2d84e997e485204d2902a9597802b0371f09331fb8";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "aiohttp" = {
    version = "3.13.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/bd/c9/989f4034fb46841208de7aeeac2c6d8300745ab4f28c42f629ba77c2d916/aiohttp-3.13.5-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:241a94f7de7c0c3b616627aaad530fe2cb620084a8b144d3be7b6ecfe95bae3b";
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
    version = "4.13.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/da/42/e921fccf5015463e32a3cf6ee7f980a6ed0f395ceeaa45060b61d86486c2/anyio-4.13.0-py3-none-any.whl";
      hash = "sha256:08b310f9e24a9594186fd75b4f73f4a4152069e3853f1ed8bfbf58369f4ad708";
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
  "attrs" = {
    version = "25.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3a/2a/7cc015f5b9f5db42b7d48157e23356022889fc354a2813c15934b7cb5c0e/attrs-25.4.0-py3-none-any.whl";
      hash = "sha256:adcf7e2a1fb3b36ac48d97835bb6d8ade15b8dcce26aba8bf1d14847b57a3373";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "autobahn" = {
    version = "25.12.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/19/8b/4215ac49d6b793b592fb08698f3a0e21a59eb3520be7f7ed288fcb52d919/autobahn-25.12.2-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:9abda5cf817c0f8a19a55a67a031adf2fc70ed351719b5bd9e6fa0f5f4bc8f89";
      platformTags = [ "manylinux_2_24_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {
      "cbor2" = [  ];
      "cffi" = [  ];
      "cryptography" = [  ];
      "hyperlink" = [  ];
      "msgpack" = [  ];
      "py-ubjson" = [  ];
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
    version = "2.2.273";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3e/eb/817ecd9e0987465114d17808bb8d10907ef64c9ea6029addfab0ab9aa055/aws_cdk_asset_awscli_v1-2.2.273-py3-none-any.whl";
      hash = "sha256:1a0994afa7b48f63b580603be64c7a99d19ed6777bdf81d3c2435d8b43cf0d71";
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
    version = "2.1.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/dc/b1/775c53a017d30d6bb0c9fa19182df11672569b6c8c7c1a1b325639abff63/aws_cdk_asset_node_proxy_agent_v6-2.1.1-py3-none-any.whl";
      hash = "sha256:a24fab484423fcb7c729fb376817a4dbb6a09c176243fd1dcbdaa05ddf62f037";
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
    version = "53.20.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b5/eb/7bf100ad3603d5fbbebb49b3d48add58abda59c3fa44a4a7eae40da5b8d0/aws_cdk_cloud_assembly_schema-53.20.0-py3-none-any.whl";
      hash = "sha256:b68ea0754ec830751d4a375ebe84d4c077dc488a2498c3607a2f998bc7e91d73";
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
  "aws-cdk-lib" = {
    version = "2.251.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d2/fb/ab682b518e3ca5d18b23b252832e0fade4e6617a2c0f2b0ae0d8d2e74312/aws_cdk_lib-2.251.0-py3-none-any.whl";
      hash = "sha256:a684f3461d096443ac688adbf559abe1af2d50dd5c8e0fa7dbf4a5f361702db8";
      platformTags = [ "any" ];
    };
    dependencies = {
      "aws-cdk-asset-awscli-v1" = [  ];
      "aws-cdk-asset-node-proxy-agent-v6" = [  ];
      "aws-cdk-cloud-assembly-schema" = [  ];
      "constructs" = [  ];
      "jsii" = [  ];
      "publication" = [  ];
      "typeguard" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "azure-core" = {
    version = "1.39.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7e/d6/8ebcd05b01a580f086ac9a97fb9fac65c09a4b012161cc97c21a336e880b/azure_core-1.39.0-py3-none-any.whl";
      hash = "sha256:4ac7b70fab5438c3f68770649a78daf97833caa83827f91df9c14e0e0ea7d34f";
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
    version = "26.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/03/87/e766c7f2e90c07fb7586cc787c9ae6462b1eedab390191f2b7fc7f6170a9/black-26.3.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:b07fc0dab849d24a80a29cfab8d8a19187d1c4685d8a5e6385a5ce323c1f015f";
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
    version = "1.38.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/08/81/26113a258b8b4068a7ae528cb1c13f1af2acfa0702368312183013ddc4f4/blessed-1.38.0-py3-none-any.whl";
      hash = "sha256:905884ae650e41284fa4fd7d0c3eed5e5b4a42be8c2bfb24c90d79fbf26a1490";
      platformTags = [ "any" ];
    };
    dependencies = {
      "wcwidth" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "boto3" = {
    version = "1.42.97";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/38/43/84c1888139aa1aaf1dc53f8f914e6ec629e5a571fbafdd42fb2d98ac361f/boto3-1.42.97-py3-none-any.whl";
      hash = "sha256:966e49f0510af9a64057a902b7df53d4348c447de0d3df4cc855dfd85e058fcd";
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
    version = "1.42.97";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e3/d2/8e025ba1a4e257879af72d06913272311af79673d82fa2581a351b924317/botocore-1.42.97-py3-none-any.whl";
      hash = "sha256:77d2c8ce1bc592d3fbd7c01c35836f4a5b0cac2ca03ccdf6ffc60faa16b5fadc";
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
    version = "7.0.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fe/c4/cf76242a5da1410917107ff14551764aa405a5fd10cd10cf9a5ca8fa77f4/cachetools-7.0.6-py3-none-any.whl";
      hash = "sha256:4e94956cfdd3086f12042cdd29318f5ced3893014f7d0d059bf3ead3f85b7f8b";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "cattrs" = {
    version = "25.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d8/2b/a40e1488fdfa02d3f9a653a61a5935ea08b3c2225ee818db6a76c7ba9695/cattrs-25.3.0-py3-none-any.whl";
      hash = "sha256:9896e84e0a5bf723bc7b4b68f4481785367ce07a8a02e7e9ee6eb2819bc306ff";
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
    version = "5.9.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/08/3c/24cd5ef488a957d90e016f200a3aad820e4c2f85edd61c9fe4523007a1ee/cbor2-5.9.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:422817286c1d0ce947fb2f7eca9212b39bddd7231e8b452e2d2cc52f15332dba";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
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
    version = "8.3.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ae/44/c1221527f6a71a01ec6fbad7fa78f1d50dfa02217385cf0fa3eec7087d59/click-8.3.3-py3-none-any.whl";
      hash = "sha256:a2bf429bb3033c89fa4936ffb35d5cb471e3719e1f3c8a7c3fff0b8314305613";
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
    version = "10.6.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fc/38/6de46d122a2fcd275a5f1fa4ad1d8d2058afd6b72d8db5f0c125515cbb5c/constructs-10.6.0-py3-none-any.whl";
      hash = "sha256:ad4ffabdb53c17cde00fb94e441a1ba9fddac57c92ad49d263f8dbd416cec513";
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
  "coverage" = {
    version = "7.13.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/22/e5/06b1f88f42a5a99df42ce61208bdec3bddb3d261412874280a19796fc09c/coverage-7.13.5-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:6c36ddb64ed9d7e496028d1d00dfec3e428e0aabf4006583bb1839958d280510";
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
    version = "48.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/90/04/673510ed51ddff56575f306cf1617d80411ee76831ccd3097599140efdfe/cryptography-48.0.0-cp311-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:7995ef305d7165c3f11ae07f2517e5a4f1d5c18da1376a0a9ed496336b69e5f3";
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
    version = "4.2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/01/34/6171ab34715ed210bcd6c2b38839cc792993cff4fe2493f50bc92b0086a0/daphne-4.2.1-py3-none-any.whl";
      hash = "sha256:881e96b387b95b35ad85acd855f229d7f5b79073d6649089c8a33f661885e055";
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
    version = "1.8.20";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c5/56/6ddca50b53624e1ca3ce1d1e49ff22db46c47ea5fb4c0cc5c9b90a616364/debugpy-1.8.20-cp314-cp314-manylinux_2_34_x86_64.whl";
      hash = "sha256:077a7447589ee9bc1ff0cdf443566d0ecf540ac8aa7333b775ebcb8ce9f4ecad";
      platformTags = [ "manylinux_2_34_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "decorator" = {
    version = "5.2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/4e/8c/f3147f5c4b73e7550fe5f9352eaa956ae838d5c51eb58e7a25b9f3e2643b/decorator-5.2.1-py3-none-any.whl";
      hash = "sha256:d316bb415a2d9e2d2b3abcc4084c6502fc09240e292cd76a76afc106a1c8e04a";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "deepmerge" = {
    version = "2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2d/82/e5d2c1c67d19841e9edc74954c827444ae826978499bde3dfc1d007c8c11/deepmerge-2.0-py3-none-any.whl";
      hash = "sha256:6de9ce507115cff0bed95ff0ce9ecc31088ef50cbdf09bc90a09349a318b3d00";
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
    version = "8.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/20/3c/9ebd7ed021b7c519bac954bc88146bc870e7d3c8db2580fa67268464fd2e/django_countries-8.2.0-py3-none-any.whl";
      hash = "sha256:2b2617bec7c15dc735bdec38ae89f0058e38fddfffdb19a7f6b75ef1e3d5380f";
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
    version = "25.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c1/40/6a02495c5658beb1f31eb09952d8aa12ef3c2a66342331ce3a35f7132439/django_filter-25.2-py3-none-any.whl";
      hash = "sha256:9c0f8609057309bba611062fe1b720b4a873652541192d232dd28970383633e3";
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
    version = "2.4.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/01/50/9c5e022fa92574e5d20606687f15a2aa255e10512a17d11a8216fa117f72/django_prometheus-2.4.1-py2.py3-none-any.whl";
      hash = "sha256:7fe5af7f7c9ad9cd8a429fe0f3f1bf651f0e244f77162147869eab7ec09cc5e7";
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
    version = "6.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/80/a3/6751b7684d20fc4f228bdd3dd8341d382ab3faaf65d3d050c0d59ab0a1b0/django_stubs-6.0.3-py3-none-any.whl";
      hash = "sha256:5fee22bcbbad59a78c727a820b6f4e68ff442ca76a922b7002e57c25dd7cb390";
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
    version = "6.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/10/fa/0a3a05c29d6295dbd52fa3cb4047a95de11ba4f2696072d6f3f2c1e6f370/django_stubs_ext-6.0.3-py3-none-any.whl";
      hash = "sha256:9e4105955419ae310d7da9cfd808e039d4dae3092c628f021057bb4f2c237f8f";
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
    version = "3.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/de/2f/309ab84126582f92d137e49c3df1ee9cc05b56e3b32428130138f5263036/django_tenants-3.10.1-py3-none-any.whl";
      hash = "sha256:01b4fb6754ac1e77d7f6a21f43b92149fecbdf7ea9dd91d73ec9c43e11967c40";
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
    version = "3.16.9";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5a/be/e53e3b89eaa30c21e036ae4d2ee88a92ef8cb43678400901748ddad870c5/djangorestframework_stubs-3.16.9-py3-none-any.whl";
      hash = "sha256:27b3e245d5f9c22ff6988d9e54388249f98f88608cc2b365b71e9f39dd096958";
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
    version = "7.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e3/26/57c6fb270950d476074c087527a558ccb6f4436657314bfb6cdf484114c4/docker-7.1.0-py3-none-any.whl";
      hash = "sha256:c96b93b7f0a746f9e77d325bcfb87422a3d8bd4f03136ae8a85b37f1898d5fc0";
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
    version = "2.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c2/91/422960c8c415fd31ca1519d71d6f7e4bcabb2cdcc5872f784467e9fe7237/dramatiq-2.1.0-py3-none-any.whl";
      hash = "sha256:3ef940c2815722d3679aed79ef96c805f02fd33d4361529b2de30f01511ca44d";
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
  "drf-orjson-renderer" = {
    version = "1.8.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7e/1a/8dab7b29cd33f94b927fba554ba4dfc4483f8e215e0e3ecaea88bdc045cb/drf_orjson_renderer-1.8.0-py3-none-any.whl";
      hash = "sha256:386ef0feda21147a490886a233b34b2ec0baf874a1de07e689aa8bc264c9baff";
      platformTags = [ "any" ];
    };
    dependencies = {
      "django" = [  ];
      "djangorestframework" = [  ];
      "orjson" = [  ];
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
    version = "2.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/01/82/f3c5dd87b0977f5547cc132b7969e6f5075a8c2f5881cf4b6df6378505f9/fido2-2.2.0-py3-none-any.whl";
      hash = "sha256:3587ccf0af7b71b5dd73f17e1dbec9f0fd157292f9163f02e7778f46d0d25fe5";
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
    version = "5.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/dd/d2/d55df737199a52b9d06e742ed2a608c525f0677e40375951372e65714fbd/geoip2-5.2.0-py3-none-any.whl";
      hash = "sha256:3d1546fd4eb7cad20445d027d2d9e81d3a71c074e019383f30db5d45e2c23320";
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
    version = "2.4.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e5/15/cf2a69ade4b194aa524ac75112d5caac37414b20a3a03e6865dfe0bd1539/geopy-2.4.1-py3-none-any.whl";
      hash = "sha256:ae8b4bc5c1131820f4d75fce9d4aaaca0c85189b3aa5d64c3dcaf5e3b7b882a7";
      platformTags = [ "any" ];
    };
    dependencies = {
      "geographiclib" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "google-api-core" = {
    version = "2.30.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/03/15/e56f351cf6ef1cfea58e6ac226a7318ed1deb2218c4b3cc9bd9e4b786c5a/google_api_core-2.30.3-py3-none-any.whl";
      hash = "sha256:a85761ba72c444dad5d611c2220633480b2b6be2521eca69cca2dbb3ffd6bfe8";
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
    version = "2.194.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b0/34/5a624e49f179aa5b0cb87b2ce8093960299030ff40423bfbde09360eb908/google_api_python_client-2.194.0-py3-none-any.whl";
      hash = "sha256:61eaaac3b8fc8fdf11c08af87abc3d1342d1b37319cc1b57405f86ef7697e717";
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
    version = "2.49.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/73/76/d241a5c927433420507215df6cac1b1fa4ac0ba7a794df42a84326c68da8/google_auth-2.49.2-py3-none-any.whl";
      hash = "sha256:c2720924dfc82dedb962c9f52cabb2ab16714fd0a6a707e40561d217574ed6d5";
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
    version = "0.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/97/e9/93afb14d23a949acaa3f4e7cc51a0024671174e116e35f42850764b99634/google_auth_httplib2-0.3.1-py3-none-any.whl";
      hash = "sha256:682356a90ef4ba3d06548c37e9112eea6fc00395a11b0303a644c1a86abc275c";
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
    version = "1.74.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b6/b0/be5d3329badb9230b765de6eea66b73abd5944bdeb5afb3562ddcd80ae84/googleapis_common_protos-1.74.0-py3-none-any.whl";
      hash = "sha256:702216f78610bb510e3f12ac3cafd281b7ac45cc5d86e90ad87e4d301a3426b5";
      platformTags = [ "any" ];
    };
    dependencies = {
      "protobuf" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "greenlet" = {
    version = "3.5.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a3/59/1bd6d7428d6ed9106efbb8c52310c60fd04f6672490f452aeaa3829aa436/greenlet-3.5.0-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:8f52a464e4ed91780bdfbbdd2b97197f3accaa629b98c200f4dffada759f3ae7";
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
    version = "25.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/43/c8/8aaf447698c4d59aa853fd318eed300b5c9e44459f242ab8ead6c9c09792/gunicorn-25.3.0-py3-none-any.whl";
      hash = "sha256:cacea387dab08cd6776501621c295a904fe8e3b7aae9a1a3cbb26f4e7ed54660";
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
    version = "4.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/69/b2/119f6e6dcbd96f9069ce9a2665e0146588dc9f88f29549711853645e736a/h2-4.3.0-py3-none-any.whl";
      hash = "sha256:c438f029a25f7945c69e0ccf0fb951dc3f73a5f6412981daee861431b70e2bdd";
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
    version = "4.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/07/c6/80c95b1b2b94682a72cbdbfb85b81ae2daffa4291fbfa1b1464502ede10d/hpack-4.1.0-py3-none-any.whl";
      hash = "sha256:157ac792668d995c657d93111f46b4535ed114f0c9c8d672271bbec7eae1b496";
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
    version = "0.31.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2f/90/fd509079dfcab01102c0fdd87f3a9506894bc70afcf9e9785ef6b2b3aff6/httplib2-0.31.2-py3-none-any.whl";
      hash = "sha256:dbf0c2fa3862acf3c55c078ea9c0bc4481d7dc5117cae71be9514912cf9f8349";
      platformTags = [ "any" ];
    };
    dependencies = {
      "pyparsing" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "httptools" = {
    version = "0.7.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b3/cb/eea88506f191fb552c11787c23f9a405f4c7b0c5799bf73f2249cd4f5228/httptools-0.7.1-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:0e68b8582f4ea9166be62926077a3334064d422cf08ab87d8b74664f8e9058e1";
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
    version = "3.13";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5d/13/ad7d7ca3808a898b4612b6fe93cde56b53f3034dcde235acb1f0e1df24c6/idna-3.13-py3-none-any.whl";
      hash = "sha256:892ea0cde124a99ce773decba204c5552b69c3c67ffd5f232eb7696135bc8bb3";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "importlib-metadata" = {
    version = "8.7.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fa/5e/f8e9a1d23b9c20a551a8a02ea3637b4642e22c2626e3a13a9a29cdea99eb/importlib_metadata-8.7.1-py3-none-any.whl";
      hash = "sha256:5a1f80bf1daa489495071efbb095d75a634cf28a8bc299581244063b53176151";
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
    version = "1.128.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/19/17/963cc6f0cb8b143649c0371a4b293490811c2ff2d3707511202e192dd272/jsii-1.128.0-py3-none-any.whl";
      hash = "sha256:25912f66516c08c21dfcd350c9efd4c71548a98fd1af61ed08e73d99a73e0af0";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "cattrs" = [  ];
      "importlib-resources" = [  ];
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
    version = "1.5.7";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/72/24/fb7da4d6613de7001feaf540d4b5969c6b5a1c42839043b0196cb13aa057/jwcrypto-1.5.7-py3-none-any.whl";
      hash = "sha256:729463fefe28b6de5cf1ebfda3e94f1a1b41d2799148ef98a01cb9678ebe2bb0";
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
    version = "35.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0c/70/05b685ea2dffcb2adbf3cdcea5d8865b7bc66f67249084cf845012a0ff13/kubernetes-35.0.0-py2.py3-none-any.whl";
      hash = "sha256:39e2b33b46e5834ef6c3985ebfe2047ab39135d41de51ce7641a7ca5b372a13d";
      platformTags = [ "any" ];
    };
    dependencies = {
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
    version = "0.9.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f2/94/a2025fe442abedf8b038038dab3dba942009ad42b38ea064a1a9e6094241/librt-0.9.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:f3fd278f5e6bf7c75ccd6d12344eb686cc020712683363b66f46ac79d37c799f";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "lxml" = {
    version = "6.1.0";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/28/30/9abc9e34c657c33834eaf6cd02124c61bdf5944d802aa48e69be8da3585d/lxml-6.1.0.tar.gz";
      hash = "sha256:bfd57d8008c4965709a919c3e9a98f76c2c7cb319086b3d26858250620023b13";
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
    version = "4.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/94/54/e7d793b573f298e1c9013b8c4dade17d481164aa517d1d7148619c2cedbf/markdown_it_py-4.0.0-py3-none-any.whl";
      hash = "sha256:87327c59b172c5011896038353a81343b6754500a08cd7a4973bb48c6d578147";
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
    version = "1.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/37/83/a099731bb11df9f3e2c39364a94579523aaa20c315a89ee69d8b7c851436/microsoft_kiota_abstractions-1.10.1-py3-none-any.whl";
      hash = "sha256:31d3f0581884eb221899f355834d86ceba6289b4b9df23e63d01f02aac6c4d0b";
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
    version = "1.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/80/99/325df634219d113d2418c76883f5cf9debf0ebb1ff04fb04438f7bc56284/microsoft_kiota_authentication_azure-1.10.1-py3-none-any.whl";
      hash = "sha256:0f82de6dbfc55d3b1df5c42d5c82631014f9db9c45ba0d0a2cdf13853f78649d";
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
    version = "1.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/11/ea/4ee59599c57561663d9f4d44e5de674f77ad1f7432242aba042768403c31/microsoft_kiota_http-1.10.1-py3-none-any.whl";
      hash = "sha256:77944e25594a65cced34702fa953bfd631eec1492ae4bef3d398eabc4ed8a6bc";
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
    version = "1.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1d/a4/67f7450b38837b361b43099457f85f60730adc729dd6cc21afe6e86ace95/microsoft_kiota_serialization_form-1.10.1-py3-none-any.whl";
      hash = "sha256:232c29eb43c4bf66773a80912fa3e1015d53a88ac6b10f48f18498f4626211bd";
      platformTags = [ "any" ];
    };
    dependencies = {
      "microsoft-kiota-abstractions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-serialization-json" = {
    version = "1.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b7/c6/39c3c653dee9dc36b879f05a1ad270aa218fd7434ec866b3e0b8942f56e9/microsoft_kiota_serialization_json-1.10.1-py3-none-any.whl";
      hash = "sha256:42b56b49afb412e77dbcdd825660723f1a9355fb438f3e2dcb7a161670b17499";
      platformTags = [ "any" ];
    };
    dependencies = {
      "microsoft-kiota-abstractions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-serialization-multipart" = {
    version = "1.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/33/ce/afd8d4f81c08a159f093f1dbc42ffa3b0b484cafe6e303812bf90ece3b65/microsoft_kiota_serialization_multipart-1.10.1-py3-none-any.whl";
      hash = "sha256:81f49060a274026227ebf30c04aac0d7022d2ee18cee9fb2149ec308333bf903";
      platformTags = [ "any" ];
    };
    dependencies = {
      "microsoft-kiota-abstractions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "microsoft-kiota-serialization-text" = {
    version = "1.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9a/e9/330603879b363b2bb6ffed81e43ab9c619c6d39d67f285be0fc5b4e6913e/microsoft_kiota_serialization_text-1.10.1-py3-none-any.whl";
      hash = "sha256:43e3d4e8ae4866440c031ae5dbf6d63a00a38ec62a61ac7eafc047de31b20269";
      platformTags = [ "any" ];
    };
    dependencies = {
      "microsoft-kiota-abstractions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "msal" = {
    version = "1.36.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2a/d3/414d1f0a5f6f4fe5313c2b002c54e78a3332970feb3f5fed14237aa17064/msal-1.36.0-py3-none-any.whl";
      hash = "sha256:36ecac30e2ff4322d956029aabce3c82301c29f0acb1ad89b94edcabb0e58ec4";
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
    version = "1.1.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2f/40/dc34d1a8d5f1e51fc64640b62b191684da52ca469da9cd74e84936ffa4a6/msgpack-1.1.2-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:180759d89a057eab503cf62eeec0aa61c4ea1200dee709f3a8e9397dbb3b6931";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "msgraph-core" = {
    version = "1.3.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cf/4d/01432f60727ae452787014cad0d5bc9e035c6e11a670f12c23f7fc926d90/msgraph_core-1.3.8-py3-none-any.whl";
      hash = "sha256:86d83edcf62119946f201d13b7e857c947ef67addb088883940197081de85bea";
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
    version = "1.56.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/56/1d/24da99bec3e419ed4da4bfdc50c0cd2406061f478d6225fb9af780099002/msgraph_sdk-1.56.0-py3-none-any.whl";
      hash = "sha256:9afe06413aed910095dd95de7a5d2d1ea14d6734cc68b778acdb2d9930bdafdc";
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
    version = "1.20.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/19/65/0cd9285ab010ee8214c83d67c6b49417c40d86ce46f1aa109457b5a9b8d7/mypy-1.20.2-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:5a65aa591af023864fd08a97da9974e919452cfe19cb146c8a5dc692626445dc";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {
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
      url = "https://github.com/vsoch/oci-python";
      rev = "ceb4fcc090851717a3069d78e85ceb1e86c2740c";
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "opentelemetry-api" = {
    version = "1.41.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/29/59/3e7118ed140f76b0982ba4321bdaed1997a0473f9720de2d10788a577033/opentelemetry_api-1.41.1-py3-none-any.whl";
      hash = "sha256:a22df900e75c76dc08440710e51f52f1aa6b451b429298896023e60db5b3139f";
      platformTags = [ "any" ];
    };
    dependencies = {
      "importlib-metadata" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "opentelemetry-sdk" = {
    version = "1.41.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b4/e7/a1420b698aad018e1cf60fdbaaccbe49021fb415e2a0d81c242f4c518f54/opentelemetry_sdk-1.41.1-py3-none-any.whl";
      hash = "sha256:edee379c126c1bce952b0c812b48fe8ff35b30df0eecf17e98afa4d598b7d85d";
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
    version = "0.62b1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/eb/a6/83dc2ab6fa397ee66fba04fe2e74bdf7be3b3870005359ceb7689103c058/opentelemetry_semantic_conventions-0.62b1-py3-none-any.whl";
      hash = "sha256:cf506938103d331fbb78eded0d9788095f7fd59016f2bda813c3324e5a74a93c";
      platformTags = [ "any" ];
    };
    dependencies = {
      "opentelemetry-api" = [  ];
      "typing-extensions" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "orjson" = {
    version = "3.11.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8d/c7/ea9e08d1f0ba981adffb629811148b44774d935171e7b3d780ae43c4c254/orjson-3.11.8-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:7679bc2f01bb0d219758f1a5f87bb7c8a81c0a186824a393b366876b4948e14f";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
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
    version = "4.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a9/90/a744336f5af32c433bd09af7854599682a383b37cfd78f7de263de6ad6cb/paramiko-4.0.0-py3-none-any.whl";
      hash = "sha256:0e20e00ac666503bf0b4eda3b6d833465a2b7aff2e2b3d79a8bba5ef144ee3b9";
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
    version = "4.9.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/75/a6/a0a304dc33b49145b21f4808d763822111e67d1c3a32b524a1baf947b6e1/platformdirs-4.9.6-py3-none-any.whl";
      hash = "sha256:e61adb1d5e5cb3441b4b7710bea7e4c12250ca49439228cc1021c00dcfac0917";
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
    version = "0.4.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b2/f2/889ad4b2408f72fe1a4f6a19491177b30ea7bf1a0fd5f17050ca08cfc882/propcache-0.4.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:8326e144341460402713f91df60ade3c999d601e7eb5ff8f6f7862d54de0610d";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "proto-plus" = {
    version = "1.27.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/84/f3/1fba73eeffafc998a25d59703b63f8be4fe8a5cb12eaff7386a0ba0f7125/proto_plus-1.27.2-py3-none-any.whl";
      hash = "sha256:6432f75893d3b9e70b9c412f1d2f03f65b11fb164b793d14ae2ca01821d22718";
      platformTags = [ "any" ];
    };
    dependencies = {
      "protobuf" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "protobuf" = {
    version = "6.33.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/16/92/d1e32e3e0d894fe00b15ce28ad4944ab692713f2e7f0a99787405e43533a/protobuf-6.33.6-cp39-abi3-manylinux2014_x86_64.whl";
      hash = "sha256:e9db7e292e0ab79dd108d7f1a94fe31601ce1ee3f7b79e0692043423020b0593";
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
    version = "3.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e7/c3/26b8a0908a9db249de3b4169692e1c7c19048a9bc41a4d3209cee7dbb758/psycopg_pool-3.3.0-py3-none-any.whl";
      hash = "sha256:2e44329155c410b5e8666372db44276a8b1ebd8c90f1c3026ebba40d4bc81063";
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
  "py-ubjson" = {
    version = "0.16.1";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/1d/c7/28220d37e041fe1df03e857fe48f768dcd30cd151480bf6f00da8713214a/py-ubjson-0.16.1.tar.gz";
      hash = "sha256:b9bfb8695a1c7e3632e800fb83c943bf67ed45ddd87cd0344851610c69a5a482";
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "pyasn1" = {
    version = "0.6.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5d/a0/7d793dce3fa811fe047d6ae2431c672364b462850c6235ae306c0efd025f/pyasn1-0.6.3-py3-none-any.whl";
      hash = "sha256:a80184d120f0864a52a073acc6fc642847d0be408e7c7252f31390c0f4eadcde";
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
    version = "2.13.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a3/5e/ecf12fdb62546d64385c158514e9b2b671f7832108ef2ecd2020ce0af2d1/pyjwt-2.13.0-py3-none-any.whl";
      hash = "sha256:66adcc2aff09b3f1bbd95fc1e1577df8ac8723c978552fd43304c8a290ac5728";
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
    version = "26.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/73/b8/a0e2790ae249d6f38c9f66de7a211621a7ab2650217bcd04e1262f578a56/pyopenssl-26.2.0-py3-none-any.whl";
      hash = "sha256:4f9d971bc5298b8bc1fab282803da04bf000c755d4ad9d99b52de2569ca19a70";
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
    version = "9.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d4/24/a372aaf5c9b7208e7112038812994107bc65a84cd00e0354a88c2c77a617/pytest-9.0.3-py3-none-any.whl";
      hash = "sha256:2c5efc453d45394fdd706ade797c0a81091eccd1d6e4bccfcd476e2b8e0ab5d9";
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
    version = "0.4.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0f/bd/11809f5c78d5d8da2d0e004845d2382768bc20798b3e0988bca61efd349f/pytest_github_actions_annotate_failures-0.4.0-py3-none-any.whl";
      hash = "sha256:285fed86e16b0b7a8eac6acdcde31913798fb739b15ef5b86895b4f5e32bf237";
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
    version = "2.33.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d7/8e/7540e8a2036f79a125c1d2ebadf69ed7901608859186c856fa0388ef4197/requests-2.33.1-py3-none-any.whl";
      hash = "sha256:4e6d1ef462f3626a1f0a0a9c42dd93c63bad33f9f1c1937509b8c5c8718ab56a";
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
    version = "0.30.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ce/81/9a91c0111ce1758c92516a3e44776920b579d9a7c09b2b06b642d4de3f0f/rpds_py-0.30.0-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:47e77dc9822d3ad616c3d5759ea5631a75e5809d5a28707744ef79d7a1bcfcad";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ruff" = {
    version = "0.15.12";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e8/39/c61d193b8a1daaa8977f7dea9e8d8ba866e02ea7b65d32f6861693aa4c12/ruff-0.15.12-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:83b2f4f2f3b1026b5fb449b467d9264bf22067b600f7b6f41fc5958909f449d0";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "s3transfer" = {
    version = "0.16.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/03/19/90d7d4ed51932c022d53f1d02d564b62d10e272692a1f9b76425c1ad2a02/s3transfer-0.16.1-py3-none-any.whl";
      hash = "sha256:61bcd00ccb83b21a0fe7e91a553fff9729d46c83b4e0106e7c314a733891f7c2";
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
    version = "4.43.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/82/c7/0c55fbb0275fc368676ea50514ce7d7839d799a8b3ff8425f380186c7626/selenium-4.43.0-py3-none-any.whl";
      hash = "sha256:4f97639055dcfa9eadf8ccf549ba7b0e49c655d4e2bde19b9a44e916b754e769";
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
    version = "2.58.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fa/eb/d875669993b762556ae8b2efd86219943b4c0864d22204d622a9aee3052b/sentry_sdk-2.58.0-py2.py3-none-any.whl";
      hash = "sha256:688d1c704ddecf382ea3326f21a67453d4caa95592d722b7c780a36a9d23109e";
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
    version = "24.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/08/2c/ca6dd598b384bc1ce581e24aaae0f2bed4ccac57749d5c3befbb5e742081/service_identity-24.2.0-py3-none-any.whl";
      hash = "sha256:6b047fbd8a84fd0bb0d55ebce4031e400562b9196e1e0d3e0fe2b8a59f6d4a85";
      platformTags = [ "any" ];
    };
    dependencies = {
      "attrs" = [  ];
      "cryptography" = [  ];
      "pyasn1" = [  ];
      "pyasn1-modules" = [  ];
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
    version = "82.0.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9d/76/f789f7a86709c6b087c5a2f52f911838cad707cc613162401badc665acfe/setuptools-82.0.1-py3-none-any.whl";
      hash = "sha256:a59e362652f08dcd477c78bb6e7bd9d80a7995bc73ce773050228a348ce2e5bb";
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
    version = "0.5.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/49/4b/359f28a903c13438ef59ebeee215fb25da53066db67b305c125f1c6d2a25/sqlparse-0.5.5-py3-none-any.whl";
      hash = "sha256:12a08b3bf3eec877c519589833aed092e2444e68240a3577e8e26148acc7b1ba";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "std-uritemplate" = {
    version = "2.0.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/64/97/b4f2f442fee92a1406f08b4fbc990bd7d02dc84b3b5e6315a59fa9b2a9f4/std_uritemplate-2.0.8-py3-none-any.whl";
      hash = "sha256:839807a7f9d07f0bad1a88977c3428bd97b9ff0d229412a0bf36123d8c724257";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "stevedore" = {
    version = "5.7.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/69/06/36d260a695f383345ab5bbc3fd447249594ae2fa8dfd19c533d5ae23f46b/stevedore-5.7.0-py3-none-any.whl";
      hash = "sha256:fd25efbb32f1abb4c9e502f385f0018632baac11f9ee5d1b70f88cc5e22ad4ed";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "structlog" = {
    version = "25.5.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a8/45/a132b9074aa18e799b891b91ad72133c98d8042c70f6240e4c5f9dabee2f/structlog-25.5.0-py3-none-any.whl";
      hash = "sha256:a8453e9b9e636ec59bd9e79bbd4a72f025981b3ba0f5837aebf48f02f37a7f9f";
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
    version = "9.10.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/4a/97/4fdde5e54fcbb789aa1a70c371f2f33d7eb1e58e8a6131fdbd8a98490976/twilio-9.10.5-py2.py3-none-any.whl";
      hash = "sha256:7972db54496fbf501b238f34d1f717f80ff22720313dc706632787aad5934997";
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
    version = "25.5.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/eb/66/ab7efd8941f0bc7b2bd555b0f0471bff77df4c88e0cc31120c82737fec77/twisted-25.5.0-py3-none-any.whl";
      hash = "sha256:8559f654d01a54a8c3efe66d533d43f383531ebf8d81d9f9ab4769d91ca15df7";
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
    version = "25.12.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/50/05/bdb6318120cac9bf97779674f49035e0595d894b42d4c43b60637bafdb1f/txaio-25.12.2-py3-none-any.whl";
      hash = "sha256:5f6cd6c6b397fc3305790d15efd46a2d5b91cdbefa96543b4f8666aeb56ba026";
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
    version = "4.3.0.20260421";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/75/7f/3f531b97832903d6c7014b3e43a0b85ba4f142c5a91a3289ac29c084ff9f/types_channels-4.3.0.20260421-py3-none-any.whl";
      hash = "sha256:48e1bd82369378bad17a63d3bfc5df6f10c9d4083e612a7292fed5524324890f";
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
    version = "7.1.0.20260409";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ba/97/cca7305de4d151452738a47d26fef88ce4acbd33ef36d0220e21b1cdf324/types_docker-7.1.0.20260409-py3-none-any.whl";
      hash = "sha256:83754caf2487e48ff18ff3b99bbd9e9c50565dce56374f61208388d6c95fbbeb";
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
    version = "1.5.7.20260409";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e3/98/e2480bc7fd0ae7f1cb44284122c18bc1f941102f12c98fdaeaabf1303a7d/types_jwcrypto-1.5.7.20260409-py3-none-any.whl";
      hash = "sha256:69470644242aa6c66c9aa730ba1dd975dbb23acc56c46f259cf75fb52133651a";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cryptography" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-ldap3" = {
    version = "2.9.13.20260408";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/63/0a/c5d5181786900a6dbcb86dd0ccdeab2ba62d75792caf9a340dfe30bdaadf/types_ldap3-2.9.13.20260408-py3-none-any.whl";
      hash = "sha256:5a9732300a6d2dcbb3a7733b91091f8c7169dc54e3ac95a09a8a0f7751b44d15";
      platformTags = [ "any" ];
    };
    dependencies = {
      "types-pyasn1" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-paramiko" = {
    version = "4.0.0.20260408";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d9/e2/cf451598a6a8820139d021b2be08a836b9b905d744bcc73b72172e7e10b3/types_paramiko-4.0.0.20260408-py3-none-any.whl";
      hash = "sha256:350bf53edb4eb88181be68854d598e1cc3a8764fe905d49913025b86e831adbc";
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
    version = "6.0.12.20260408";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1c/f0/c391068b86abb708882c6d75a08cd7d25b2c7227dab527b3a3685a3c635b/types_pyyaml-6.0.12.20260408-py3-none-any.whl";
      hash = "sha256:fbc42037d12159d9c801ebfcc79ebd28335a7c13b08a4cfbc6916df78fee9384";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-requests" = {
    version = "2.33.0.20260408";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/90/b8/78fd6c037de4788c040fdd323b3369804400351b7827473920f6c1d03c10/types_requests-2.33.0.20260408-py3-none-any.whl";
      hash = "sha256:81f31d5ea4acb39f03be7bc8bed569ba6d5a9c5d97e89f45ac43d819b68ca50f";
      platformTags = [ "any" ];
    };
    dependencies = {
      "urllib3" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "types-zxcvbn" = {
    version = "4.5.0.20260408";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c7/59/776d0db9b5fcd0db841727c16d4742ad6120da9ce93a09d030401432ebed/types_zxcvbn-4.5.0.20260408-py3-none-any.whl";
      hash = "sha256:5eff6991fa459590af1dd669b706d058ceeb599f175c5195864f81ada97d781a";
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
    version = "202603";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3e/6f/73a4d37deefb159556d39d654b5bad67b6874d1ad0b20b96fb5a04de3949/ua_parser_builtins-202603-py3-none-any.whl";
      hash = "sha256:67478397a68fac1a98fd0a31c416ea7c65a719141fc151d0211316f2cd337cc9";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "ujson" = {
    version = "5.12.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/64/2b/3e322bf82d926d9857206cd5820438d78392d1f523dacecb8bd899952f73/ujson-5.12.0-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:0e00cec383eab2406c9e006bd4edb55d284e94bb943fda558326048178d26961";
      platformTags = [ "manylinux_2_24_x86_64" "manylinux_2_28_x86_64" ];
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
    version = "2.6.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/39/08/aaaad47bc4e9dc8c725e68f9d04865dbcb2052843ff09c97b08904852d84/urllib3-2.6.3-py3-none-any.whl";
      hash = "sha256:bf272323e553dfb2e87d9bfd225ca7b0f467b919d7bbd355436d3fd37cb0acd4";
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
    version = "0.46.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/31/a3/5b1562db76a5a488274b2332a97199b32d0442aca0ed193697fd47786316/uvicorn-0.46.0-py3-none-any.whl";
      hash = "sha256:bbebbcbed972d162afca128605223022bedd345b7bc7855ce66deb31487a9048";
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
    version = "1.1.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b4/36/ded8aebea91919485b7bbabbd14f5f359326cb5ec218cd67074d1e426d74/watchfiles-1.1.1-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:5c85794a4cfa094714fb9c08d4a218375b2b95b8ed1666e8677c349906246c05";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
    dependencies = {
      "anyio" = [  ];
    };
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "wcwidth" = {
    version = "0.6.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/68/5a/199c59e0a824a3db2b89c5d2dade7ab5f9624dbf6448dc291b46d5ec94d3/wcwidth-0.6.0-py3-none-any.whl";
      hash = "sha256:1a3a1e510b553315f8e146c54764f4fb6264ffad731b3d78088cdb1478ffbdad";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "webauthn" = {
    version = "2.7.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/90/5b/f73513367a9d34b199de916b44306acfa4027b57f7e22200421212b1f763/webauthn-2.7.1-py3-none-any.whl";
      hash = "sha256:d57e9613c65e0c6a4db7ee715fb49ebdf3c4a6eb3979729eeb497c99105e8181";
      platformTags = [ "any" ];
    };
    dependencies = {
      "cbor2" = [  ];
      "cryptography" = [  ];
      "pyasn1" = [  ];
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
    version = "1.23.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/42/2b/fef67d616931055bf3d6764885990a3ac647d68734a2d6a9e1d13de437a2/yarl-1.23.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:1c57676bdedc94cd3bc37724cf6f8cd2779f02f6aba48de45feca073e714fe52";
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
    version = "3.23.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/08/8a/0861bec20485572fbddf3dfba2910e38fe249796cb73ecdeb74e07eeb8d3/zipp-3.23.1-py3-none-any.whl";
      hash = "sha256:0b3596c50a5c700c9cb40ba8d86d9f2cc4807e9bedb06bcdf7fac85633e444dc";
      platformTags = [ "any" ];
    };
    dependencies = {};
    optionalDependencies = {};
    dependencyGroups = {};
  };
  "zope-interface" = {
    version = "8.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d2/a7/e48c79b836f6f0a2c219288e2ec343517f90e95c93de5435a8a23918bf20/zope_interface-8.4-cp314-cp314-manylinux1_x86_64.manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:049ba3c7b38cc400ae08e011617635706e0f442e1d075db1b015246fcbf6091e";
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
      version = "82.0.1";
      format = "wheel";
      source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9d/76/f789f7a86709c6b087c5a2f52f911838cad707cc613162401badc665acfe/setuptools-82.0.1-py3-none-any.whl";
      hash = "sha256:a59e362652f08dcd477c78bb6e7bd9d80a7995bc73ce773050228a348ce2e5bb";
      platformTags = [ "any" ];
    };
    };
  };
}
