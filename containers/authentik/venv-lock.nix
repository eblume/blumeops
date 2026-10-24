# venv-lock.nix — GENERATED — do not edit by hand.
#
# Regenerate:  mise run generate-authentik-venv-lock --write
# Freshness:   the `generate-authentik-venv-lock` prek hook (Lint job) fails
#              when this file drifts from the pinned authentik rev's resolved
#              closure (a changed uv.lock without regeneration).
#
# Provenance (the exact inputs this file was resolved from):
#   authentik         version/2026.2.6 (c5fdbafb9b56…)  sha256-1OSG3kfsxXYD1riuBgE+MxmkkbktsZAH5kRcjyBb7xM=
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
      tag = "version/2026.2.6";
      hash = "sha256-1OSG3kfsxXYD1riuBgE+MxmkkbktsZAH5kRcjyBb7xM=";
      sha = "c5fdbafb9b569fbeb15bda701e8fbdd8a10a4996";
    };
    trio = {
      "build-system-pkgs" = { url = "https://forge.ops.eblu.me/mirrors/build-system-pkgs.git"; rev = "a17819c85163988e063806ffc4f6d2716bc8ead8"; };
      "pyproject-nix" = { url = "https://forge.ops.eblu.me/mirrors/pyproject.nix.git"; rev = "ddc400a6883b042646d0940e65971bb7f7e96107"; };
      "uv2nix" = { url = "https://forge.ops.eblu.me/mirrors/uv2nix.git"; rev = "7aba73a3d85454f1118f8cf9de97979b4d26bcac"; };
    };
    nixpkgs = { rev = "c3eea5b2156db11c7eeeada3dc737711255b253e"; };
    python = "3.14";
  };

  # 258 venv packages, sorted by name.
  #   source.type: "wheel" -> { url, hash, platformTags }
  #               "sdist" -> { url, hash }
  #               "git"   -> { url, rev }
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
  };
  "aiohttp" = {
    version = "3.13.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e3/d1/e30e537a15f53485b61f5be525f2157da719819e8377298502aebac45536/aiohttp-3.13.3-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:bbe7d4cecacb439e2e2a8a1a7b935c25b812af7a5fd26503a66dadf428e79ec1";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
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
  };
  "anyio" = {
    version = "4.12.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/38/0e/27be9fdef66e72d64c0cdc3cc2823101b80585f8119b5c112c2e8f5f7dab/anyio-4.12.1-py3-none-any.whl";
      hash = "sha256:d405828884fc140aa80a3c667b8beed277f1dfedec42ba031bd6ac3db606ab6c";
      platformTags = [ "any" ];
    };
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
  };
  "asgiref" = {
    version = "3.11.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/91/be/317c2c55b8bbec407257d45f5c8d1b6867abc76d12043f2d3d58c538a4ea/asgiref-3.11.0-py3-none-any.whl";
      hash = "sha256:1db9021efadb0d9512ce8ffaf72fcef601c7b73a8807a1bb2ef143dc6b14846d";
      platformTags = [ "any" ];
    };
  };
  "asn1crypto" = {
    version = "1.5.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c9/7f/09065fd9e27da0eda08b4d6897f1c13535066174cc023af248fc2a8d5e5a/asn1crypto-1.5.1-py2.py3-none-any.whl";
      hash = "sha256:db4e40728b728508912cbb3d44f19ce188f218e9eba635821bb4b68564f8fd67";
      platformTags = [ "any" ];
    };
  };
  "async-generator" = {
    version = "1.10";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/71/52/39d20e03abd0ac9159c162ec24b93fbcaa111e8400308f2465432495ca2b/async_generator-1.10-py3-none-any.whl";
      hash = "sha256:01c7bf666359b4967d2cda0000cc2e4af16a0ae098cbffcb8472fb9e8ad6585b";
      platformTags = [ "any" ];
    };
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
  };
  "aws-cdk-asset-awscli-v1" = {
    version = "2.2.263";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/29/af/02481a85fdd0b8a2a1fd9b84925591e1113a7a61b014dabe9d3f92dd6a67/aws_cdk_asset_awscli_v1-2.2.263-py3-none-any.whl";
      hash = "sha256:185150757d4216ea982d7b35596de5b3d767776be00cd78cacce02eaa08f8851";
      platformTags = [ "any" ];
    };
  };
  "aws-cdk-asset-node-proxy-agent-v6" = {
    version = "2.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8d/86/1817a6da223aa80aeb94a504f07f930170284694b18f6053729e9930cc6a/aws_cdk.asset_node_proxy_agent_v6-2.1.0-py3-none-any.whl";
      hash = "sha256:24a388b69a44d03bae6dbf864c4e25ba650d4b61c008b4568b94ffbb9a69e40e";
      platformTags = [ "any" ];
    };
  };
  "aws-cdk-cloud-assembly-schema" = {
    version = "48.20.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/13/08/17a35f0b668451484f2254f5e50a0105958bffe90da11c41b7629972e6a9/aws_cdk_cloud_assembly_schema-48.20.0-py3-none-any.whl";
      hash = "sha256:f5b6cf661cac8690add9461de13aeae3f3742eec71c066032bd045b08d0b7c3e";
      platformTags = [ "any" ];
    };
  };
  "aws-cdk-lib" = {
    version = "2.238.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5c/b9/47cb90169841bbbe74e2e30967132d8930a70e05340454caaa3e31b129ab/aws_cdk_lib-2.238.0-py3-none-any.whl";
      hash = "sha256:6602d6678597c649d80ff884972c3fa67a98fd6cacb56adcb77cd8fc4a735d43";
      platformTags = [ "any" ];
    };
  };
  "azure-core" = {
    version = "1.38.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fc/d8/b8fcba9464f02b121f39de2db2bf57f0b216fe11d014513d666e8634380d/azure_core-1.38.0-py3-none-any.whl";
      hash = "sha256:ab0c9b2cd71fecb1842d52c965c95285d3cfb38902f6766e4a471f1cd8905335";
      platformTags = [ "any" ];
    };
  };
  "azure-identity" = {
    version = "1.25.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/83/7b/5652771e24fff12da9dde4c20ecf4682e606b104f26419d139758cc935a6/azure_identity-1.25.1-py3-none-any.whl";
      hash = "sha256:e9edd720af03dff020223cd269fa3a61e8f345ea75443858273bcb44844ab651";
      platformTags = [ "any" ];
    };
  };
  "bandit" = {
    version = "1.9.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e0/0b/8bdc52111c83e2dc2f97403dc87c0830b8989d9ae45732b34b686326fb2c/bandit-1.9.3-py3-none-any.whl";
      hash = "sha256:4745917c88d2246def79748bde5e08b9d5e9b92f877863d43fab70cd8814ce6a";
      platformTags = [ "any" ];
    };
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
  };
  "black" = {
    version = "26.1.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1b/87/670dd888c537acb53a863bc15abbd85b22b429237d9de1b77c0ed6b79c42/black-26.1.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:53c62883b3f999f14e5d30b5a79bd437236658ad45b2f853906c7cbe79de00af";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
  };
  "blessed" = {
    version = "1.25.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7c/2c/e9b6dd824fb6e76dbd39a308fc6f497320afd455373aac8518ca3eba7948/blessed-1.25.0-py3-none-any.whl";
      hash = "sha256:e52b9f778b9e10c30b3f17f6b5f5d2208d1e9b53b270f1d94fc61a243fc4708f";
      platformTags = [ "any" ];
    };
  };
  "boto3" = {
    version = "1.42.26";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fd/0c/094a63b0ab893995b1f2e7ddb5425e11f97403feb90cea0eb770c8905487/boto3-1.42.26-py3-none-any.whl";
      hash = "sha256:f116cfbe7408e0a9153da363f134d2f1b5008f17ee86af104f0ce59a62be1833";
      platformTags = [ "any" ];
    };
  };
  "botocore" = {
    version = "1.42.26";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/61/43/5993eab2114c0de7bbc21985b745aafe3b912f98fc63726c2a54680bb69d/botocore-1.42.26-py3-none-any.whl";
      hash = "sha256:71171c2d09ac07739f4efce398b15a4a8bc8769c17fb3bc99625e43ed11ad8b7";
      platformTags = [ "any" ];
    };
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
  };
  "cachetools" = {
    version = "7.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/28/df/2dd32cce20cbcf6f2ec456b58d44368161ad28320729f64e5e1d5d7bd0ae/cachetools-7.0.0-py3-none-any.whl";
      hash = "sha256:d52fef60e6e964a1969cfb61ccf6242a801b432790fe520d78720d757c81cbd2";
      platformTags = [ "any" ];
    };
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
  };
  "certifi" = {
    version = "2026.1.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e6/ad/3cc14f097111b4de0040c83a525973216457bbeeb63739ef1ed275c1c021/certifi-2026.1.4-py3-none-any.whl";
      hash = "sha256:9943707519e4add1115f44c2bc244f782c0249876bf51b6599fee1ffbedd685c";
      platformTags = [ "any" ];
    };
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
  };
  "charset-normalizer" = {
    version = "3.4.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/67/ff/f6b948ca32e4f2a4576aa129d8bed61f2e0543bf9f5f2b7fc3758ed005c9/charset_normalizer-3.4.4-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:ecaae4149d99b1c9e7b88bb03e3221956f68fd6d50be2ef061b2381b61d20838";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
  };
  "click" = {
    version = "8.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/98/78/01c019cdb5d6498122777c1a43056ebb3ebfeef2076d9d026bfe15583b2b/click-8.3.1-py3-none-any.whl";
      hash = "sha256:981153a64e25f12d547d3426c367a4857371575ee7ad18df2a6183ab0545b2a6";
      platformTags = [ "any" ];
    };
  };
  "codespell" = {
    version = "2.4.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/20/01/b394922252051e97aab231d416c86da3d8a6d781eeadcdca1082867de64e/codespell-2.4.1-py3-none-any.whl";
      hash = "sha256:3dadafa67df7e4a3dbf51e0d7315061b80d265f9552ebd699b3dd6834b47e425";
      platformTags = [ "any" ];
    };
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
  };
  "constructs" = {
    version = "10.4.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cd/a1/0cbba03ce3c1377a788192163f2614f396a8614cf5022ac54bdc2085c078/constructs-10.4.5-py3-none-any.whl";
      hash = "sha256:e63d6675ba2e8a9076db8df1d4c7af78efdb96182ba28abe938384ba321e4b81";
      platformTags = [ "any" ];
    };
  };
  "coverage" = {
    version = "7.13.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/06/90/2cdab0974b9b5bbc1623f7876b73603aecac11b8d95b85b5b86b32de5eab/coverage-7.13.4-cp314-cp314-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:0dd7ab8278f0d58a0128ba2fca25824321f05d059c1441800e934ff2efa52129";
      platformTags = [ "manylinux1_x86_64" "manylinux_2_28_x86_64" "manylinux_2_5_x86_64" ];
    };
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
  };
  "cryptography" = {
    version = "46.0.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/63/e7/471ab61099a3920b0c77852ea3f0ea611c9702f651600397ac567848b897/cryptography-46.0.5-cp311-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:4d7e3d356b8cd4ea5aff04f129d5f66ebdc7b6f8eae802b93739ed520c47c79b";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
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
  };
  "django" = {
    version = "5.2.15";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/92/b5/38140b1643c00d5c46ce69c78e6980fd285aee223100319631bedee4f5e7/django-5.2.15-py3-none-any.whl";
      hash = "sha256:0eb4a9bb1853a35b0286dbc6d916bd352c8c2687195a7f2d6f80cefd840e4970";
      platformTags = [ "any" ];
    };
  };
  "django-countries" = {
    version = "7.6.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7e/46/b6931858e5161e5d9166bfcfde3af0b7d60ba89e4f7dd8f033e591c68794/django_countries-7.6.1-py3-none-any.whl";
      hash = "sha256:1ed20842fe0f6194f91faca21076649513846a8787c9eb5aeec3cbe1656b8acc";
      platformTags = [ "any" ];
    };
  };
  "django-cte" = {
    version = "3.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ee/8a/5fdf282b8496e485b007d48ac211a0e2b203b8623e67c32ed2cf65faedc4/django_cte-3.0.0-py3-none-any.whl";
      hash = "sha256:3eabb89b68d328a6a97c695a21f45ed6ee7a6602193670db74e70c2e17bf2cd5";
      platformTags = [ "any" ];
    };
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
  };
  "django-stubs" = {
    version = "5.2.9";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0d/05/4c9c419b7051eb4b350100b086be6df487f968ab672d3d370f8ccf7c3746/django_stubs-5.2.9-py3-none-any.whl";
      hash = "sha256:2317a7130afdaa76f6ff7f623650d7f3bf1b6c86a60f95840e14e6ec6de1a7cd";
      platformTags = [ "any" ];
    };
  };
  "django-stubs-ext" = {
    version = "5.2.9";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9b/f7/0d5f7d7e76fe972d9f560f687fdc0cab4db9e1624fd90728ca29b4ed7a63/django_stubs_ext-5.2.9-py3-none-any.whl";
      hash = "sha256:230c51575551b0165be40177f0f6805f1e3ebf799b835c85f5d64c371ca6cf71";
      platformTags = [ "any" ];
    };
  };
  "django-tenants" = {
    version = "3.10.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/92/96/43691f2b1ebd70a934c11fed8b2d71d9ee97279428a3e2f618945bfc178c/django_tenants-3.10.0-py3-none-any.whl";
      hash = "sha256:15a9fc6080321d1f159ffa4334eb90f0438ed75658df7e963b1ad68f641add11";
      platformTags = [ "any" ];
    };
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
  };
  "djangorestframework" = {
    version = "3.16.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b0/ce/bf8b9d3f415be4ac5588545b5fcdbbb841977db1c1d923f7568eeabe1689/djangorestframework-3.16.1-py3-none-any.whl";
      hash = "sha256:33a59f47fb9c85ede792cbf88bde71893bcda0667bc573f784649521f1102cec";
      platformTags = [ "any" ];
    };
  };
  "djangorestframework-stubs" = {
    version = "3.16.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ea/e9/d9c363b08d07d975c21793fe821b2020dfd3627ac4ce19c5c12df94ce9d0/djangorestframework_stubs-3.16.8-py3-none-any.whl";
      hash = "sha256:c5bf61def0f330a071dd5f470f05710189d06c467b3f3e186b32c5a23d4952fb";
      platformTags = [ "any" ];
    };
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
  };
  "dramatiq" = {
    version = "1.17.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ee/36/925c7afd5db4f1a3f00676b9c3c58f31ff7ae29a347282d86c8d429280a5/dramatiq-1.17.1-py3-none-any.whl";
      hash = "sha256:951cdc334478dff8e5150bb02a6f7a947d215ee24b5aedaf738eff20e17913df";
      platformTags = [ "any" ];
    };
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
  };
  "drf-spectacular" = {
    version = "0.28.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fb/66/c2929871393b1515c3767a670ff7d980a6882964a31a4ca2680b30d7212a/drf_spectacular-0.28.0-py3-none-any.whl";
      hash = "sha256:856e7edf1056e49a4245e87a61e8da4baff46c83dbc25be1da2df77f354c7cb4";
      platformTags = [ "any" ];
    };
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
  };
  "duo-client" = {
    version = "5.5.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7a/4b/dd927d3111e1f4c78c1f5944d3b64b4fb6ab655487c23100a3feff5cdaa4/duo_client-5.5.0-py3-none-any.whl";
      hash = "sha256:4fbf1e97a2b25ef64e9f88171ab817162cf45bafc1c63026af4883baf8892a12";
      platformTags = [ "any" ];
    };
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
  };
  "fido2" = {
    version = "2.1.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e2/ab/d0fa89cc4b982800dd88daa799612f11642bf9393851715d9eaeba3cfcac/fido2-2.1.1-py3-none-any.whl";
      hash = "sha256:f85c16c8084abf6530b6c6ec3a0cf8575943321842e06916686943a8b784182c";
      platformTags = [ "any" ];
    };
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
  };
  "gevent" = {
    version = "25.9.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/dd/65/b9a4526d4a4edce26fe4b3b993914ec9dc64baabad625a3101e51adb17f3/gevent-25.9.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256:b5a67a0974ad9f24721034d1e008856111e0535f1541499f72a733a73d658d1c";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
  };
  "google-api-core" = {
    version = "2.29.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/77/b6/85c4d21067220b9a78cfb81f516f9725ea6befc1544ec9bd2c1acd97c324/google_api_core-2.29.0-py3-none-any.whl";
      hash = "sha256:d30bc60980daa36e314b5d5a3e5958b0200cb44ca8fa1be2b614e932b75a3ea9";
      platformTags = [ "any" ];
    };
  };
  "google-api-python-client" = {
    version = "2.189.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/04/44/3677ff27998214f2fa7957359da48da378a0ffff1bd0bdaba42e752bc13e/google_api_python_client-2.189.0-py3-none-any.whl";
      hash = "sha256:a258c09660a49c6159173f8bbece171278e917e104a11f0640b34751b79c8a1a";
      platformTags = [ "any" ];
    };
  };
  "google-auth" = {
    version = "2.47.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/db/18/79e9008530b79527e0d5f79e7eef08d3b179b7f851cfd3a2f27822fbdfa9/google_auth-2.47.0-py3-none-any.whl";
      hash = "sha256:c516d68336bfde7cf0da26aab674a36fedcf04b37ac4edd59c597178760c3498";
      platformTags = [ "any" ];
    };
  };
  "google-auth-httplib2" = {
    version = "0.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/99/d5/3c97526c8796d3caf5f4b3bed2b05e8a7102326f00a334e7a438237f3b22/google_auth_httplib2-0.3.0-py3-none-any.whl";
      hash = "sha256:426167e5df066e3f5a0fc7ea18768c08e7296046594ce4c8c409c2457dd1f776";
      platformTags = [ "any" ];
    };
  };
  "googleapis-common-protos" = {
    version = "1.72.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c4/ab/09169d5a4612a5f92490806649ac8d41e3ec9129c636754575b3553f4ea4/googleapis_common_protos-1.72.0-py3-none-any.whl";
      hash = "sha256:4299c5a82d5ae1a9702ada957347726b167f9f8d1fc352477702a1e851ff4038";
      platformTags = [ "any" ];
    };
  };
  "greenlet" = {
    version = "3.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b8/14/bab308fc2c1b5228c3224ec2bf928ce2e4d21d8046c161e44a2012b5203e/greenlet-3.3.0-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:5773edda4dc00e173820722711d043799d3adb4f01731f40619e07ea2750b955";
      platformTags = [ "manylinux_2_24_x86_64" "manylinux_2_28_x86_64" ];
    };
  };
  "gssapi" = {
    version = "1.11.1";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/23/52/c1e90623c259a42ab0587078bb04f959867b970add46ff66750ead8fc7c5/gssapi-1.11.1.tar.gz";
      hash = "sha256:2049ee4b1d0c363163a1344b7282a363f9f4094e51d2c36de0cf01d4735e0ae2";
    };
  };
  "gunicorn" = {
    version = "25.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5e/84/117f39896ded517149be72d16c02252885690e9b0d1b84281944928f61aa/gunicorn-25.0.3-py3-none-any.whl";
      hash = "sha256:aca364c096c81ca11acd4cede0aaeea91ba76ca74e2c0d7f879154db9d890f35";
      platformTags = [ "any" ];
    };
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
  };
  "httplib2" = {
    version = "0.31.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f0/d8/1b05076441c2f01e4b64f59e5255edc2f0384a711b6d618845c023dc269b/httplib2-0.31.1-py3-none-any.whl";
      hash = "sha256:d520d22fa7e50c746a7ed856bac298c4300105d01bc2d8c2580a9b57fb9ed617";
      platformTags = [ "any" ];
    };
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
  };
  "idna" = {
    version = "3.11";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0e/61/66938bbb5fc52dbdf84594873d5b51fb1f7c7794e9c0f5bd885f30bc507b/idna-3.11-py3-none-any.whl";
      hash = "sha256:771a87f49d9defaf64091e6e6fe9c18d4833f140bd19464795bc32d966ca37ea";
      platformTags = [ "any" ];
    };
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
  };
  "importlib-resources" = {
    version = "6.5.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a4/ed/1f1afb2e9e7f38a545d628f864d562a5ae64fe6f7a10e28ffb9b185b4e89/importlib_resources-6.5.2-py3-none-any.whl";
      hash = "sha256:789cfdc3ed28c78b67a06acb8126751ced69a3d5f79c095a98298cd8a760ccec";
      platformTags = [ "any" ];
    };
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
  };
  "invoke" = {
    version = "2.2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/32/4b/b99e37f88336009971405cbb7630610322ed6fbfa31e1d7ab3fbf3049a2d/invoke-2.2.1-py3-none-any.whl";
      hash = "sha256:2413bc441b376e5cd3f55bb5d364f973ad8bdd7bf87e53c79de3c11bf3feecc8";
      platformTags = [ "any" ];
    };
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
  };
  "jmespath" = {
    version = "1.0.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/31/b4/b9b800c45527aadd64d5b442f9b932b00648617eb5d63d2c7a6587b7cafc/jmespath-1.0.1-py3-none-any.whl";
      hash = "sha256:02e2e4cc71b5bcab88332eebf907519190dd9e6e82107fa7f83b1003a6252980";
      platformTags = [ "any" ];
    };
  };
  "jsii" = {
    version = "1.126.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a2/7d/f058cfdc20e1536b09d165303b1996d24504fbe105b0aba62c865e60bdc9/jsii-1.126.0-py3-none-any.whl";
      hash = "sha256:0bb3d5423fd62a499f9ce83e98668b48424ac6ef39472bff90cdf4650aa41b41";
      platformTags = [ "any" ];
    };
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
  };
  "jsonpointer" = {
    version = "3.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/71/92/5e77f98553e9e75130c78900d000368476aed74276eb8ae8796f65f00918/jsonpointer-3.0.0-py2.py3-none-any.whl";
      hash = "sha256:13e088adc14fca8b6aa8177c044e12701e6ad4b28ff10e65f2267a90109c9942";
      platformTags = [ "any" ];
    };
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
  };
  "jwcrypto" = {
    version = "1.5.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cd/58/4a1880ea64032185e9ae9f63940c9327c6952d5584ea544a8f66972f2fda/jwcrypto-1.5.6-py3-none-any.whl";
      hash = "sha256:150d2b0ebbdb8f40b77f543fb44ffd2baeff48788be71f67f03566692fd55789";
      platformTags = [ "any" ];
    };
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
  };
  "librt" = {
    version = "0.7.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/db/01/5cbdde0951a5090a80e5ba44e6357d375048123c572a23eecfb9326993a7/librt-0.7.8-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:7e03bea66af33c95ce3addf87a9bf1fcad8d33e757bc479957ddbc0e4f7207ac";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
  };
  "lxml" = {
    version = "6.0.2";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/aa/88/262177de60548e5a2bfc46ad28232c9e9cbde697bd94132aeb80364675cb/lxml-6.0.2.tar.gz";
      hash = "sha256:cd79f3367bd74b317dda655dc8fcfa304d9eb6e4fb06b7168c5cf27f96e0cd62";
    };
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
  };
  "markdown2" = {
    version = "2.5.4";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b8/06/2697b5043c3ecb720ce0d243fc7cf5024c0b5b1e450506e9b21939019963/markdown2-2.5.4-py3-none-any.whl";
      hash = "sha256:3c4b2934e677be7fec0e6f2de4410e116681f4ad50ec8e5ba7557be506d3f439";
      platformTags = [ "any" ];
    };
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
  };
  "maxminddb" = {
    version = "3.0.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/4f/4b/323ec8abe811702bcea537a0aa5e83442f48f1974084bdb048b75424536c/maxminddb-3.0.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:c6b86dedb1ae681376bcc31bec37d7d674c86ff05687738ab333f18988f17c3a";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
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
  };
  "microsoft-kiota-abstractions" = {
    version = "1.9.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3d/03/9a6678f2ab11d9feaa7739eab1e3cf4d38f9abc46a47f48f32083bf2f1c7/microsoft_kiota_abstractions-1.9.8-py3-none-any.whl";
      hash = "sha256:bb3243ce776dc0197cb006289a6f0b8a0db699b3885206adde7e6a76c17904a1";
      platformTags = [ "any" ];
    };
  };
  "microsoft-kiota-authentication-azure" = {
    version = "1.9.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3d/6f/62167e5f1a941f5fd12476da43f13a8aac16f634481e317bdba31381da84/microsoft_kiota_authentication_azure-1.9.8-py3-none-any.whl";
      hash = "sha256:953e184cdbfcc6d1c6da18477458856c7ff8a69087896cf638b72b34785b036d";
      platformTags = [ "any" ];
    };
  };
  "microsoft-kiota-http" = {
    version = "1.9.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a3/b9/f42d80428d9486657b333be4206c793404fffbb452dfb6cb7c7659f6a9bf/microsoft_kiota_http-1.9.8-py3-none-any.whl";
      hash = "sha256:d632a8283bce707b0efa75517a0da92cdd0d81204246f06b164f4e72d99eb20a";
      platformTags = [ "any" ];
    };
  };
  "microsoft-kiota-serialization-form" = {
    version = "1.9.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/33/f8/7fc118a80d222dfb05530cfda94c0e776c1bfb9e6504a27e4ffb20fba425/microsoft_kiota_serialization_form-1.9.8-py3-none-any.whl";
      hash = "sha256:5ef2e8d9c13717e52addacb11a0967702918b6e94b082ac36b8fe6f883854972";
      platformTags = [ "any" ];
    };
  };
  "microsoft-kiota-serialization-json" = {
    version = "1.9.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/99/f3/5805a337c2485e74598f96a102e116691b4844ccf5fe1f6ef3bf4fd06331/microsoft_kiota_serialization_json-1.9.8-py3-none-any.whl";
      hash = "sha256:9990c109950c58aee96d0a46f25560631ba4c51439448262a9ebc5f7e5b4aa4d";
      platformTags = [ "any" ];
    };
  };
  "microsoft-kiota-serialization-multipart" = {
    version = "1.9.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fd/69/11760cc57a57b38a32844b23e63b69f5adf1fedb20b894f46eb4fd7016a8/microsoft_kiota_serialization_multipart-1.9.8-py3-none-any.whl";
      hash = "sha256:2d1402b578cece154150aed812237609fced571f78149ad08193b4f592928354";
      platformTags = [ "any" ];
    };
  };
  "microsoft-kiota-serialization-text" = {
    version = "1.9.8";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6f/e5/bd382327e7ddaaa091f1f323d760408213136f41940d074b2ffffd9a1127/microsoft_kiota_serialization_text-1.9.8-py3-none-any.whl";
      hash = "sha256:dd89ae49693623c0e1d8f07414aa7d71b34959a5253131b8b63d81920f08c6b1";
      platformTags = [ "any" ];
    };
  };
  "msal" = {
    version = "1.34.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c2/dc/18d48843499e278538890dc709e9ee3dea8375f8be8e82682851df1b48b5/msal-1.34.0-py3-none-any.whl";
      hash = "sha256:f669b1644e4950115da7a176441b0e13ec2975c29528d8b9e81316023676d6e1";
      platformTags = [ "any" ];
    };
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
  };
  "msgraph-sdk" = {
    version = "1.54.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3f/7a/d9eed36c7f309eb6c81c5b72b5b8bad40203487414ad2b9e371febc79885/msgraph_sdk-1.54.0-py3-none-any.whl";
      hash = "sha256:2b9894fd9f21ed9a71188e3d68bd1a9a58b2d1077e96ee4cb10a9f3d9d59a58e";
      platformTags = [ "any" ];
    };
  };
  "multidict" = {
    version = "6.7.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b4/63/2ab26e4209773223159b83aa32721b4021ffb08102f8ac7d689c943fded1/multidict-6.7.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:18706cc31dbf402a7945916dd5cddf160251b6dab8a2c5f3d6d5a55949f676b3";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
  };
  "mypy" = {
    version = "1.19.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/32/2a/66ba933fe6c76bd40d1fe916a83f04fed253152f451a877520b3c4a5e41e/mypy-1.19.1-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:28902ee51f12e0f19e1e16fbe2f8f06b6637f482c459dd393efddd0ec7f82045";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
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
  };
  "opencontainers" = {
    version = "0.0.14";
    fmt = "git";
    source = {
      type = "git";
      url = "https://github.com/vsoch/oci-python";
      rev = "ceb4fcc090851717a3069d78e85ceb1e86c2740c";
    };
  };
  "opentelemetry-api" = {
    version = "1.39.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cf/df/d3f1ddf4bb4cb50ed9b1139cc7b1c54c34a1e7ce8fd1b9a37c0d1551a6bd/opentelemetry_api-1.39.1-py3-none-any.whl";
      hash = "sha256:2edd8463432a7f8443edce90972169b195e7d6a05500cd29e6d13898187c9950";
      platformTags = [ "any" ];
    };
  };
  "opentelemetry-sdk" = {
    version = "1.39.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7c/98/e91cf858f203d86f4eccdf763dcf01cf03f1dae80c3750f7e635bfa206b6/opentelemetry_sdk-1.39.1-py3-none-any.whl";
      hash = "sha256:4d5482c478513ecb0a5d938dcc61394e647066e0cc2676bee9f3af3f3f45f01c";
      platformTags = [ "any" ];
    };
  };
  "opentelemetry-semantic-conventions" = {
    version = "0.60b1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/7a/5e/5958555e09635d09b75de3c4f8b9cae7335ca545d77392ffe7331534c402/opentelemetry_semantic_conventions-0.60b1-py3-none-any.whl";
      hash = "sha256:9fa8c8b0c110da289809292b0591220d3a7b53c1526a23021e977d68597893fb";
      platformTags = [ "any" ];
    };
  };
  "orjson" = {
    version = "3.11.6";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/32/a7/573fec3df4dc8fc259b7770dc6c0656f91adce6e19330c78d23f87945d1e/orjson-3.11.6-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:6dddf9ba706294906c56ef5150a958317b09aa3a8a48df1c52ccf22ec1907eac";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
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
  };
  "packaging" = {
    version = "26.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b7/b9/c538f279a4e237a006a2c98387d081e9eb060d203d8ed34467cc0f0b9b53/packaging-26.0-py3-none-any.whl";
      hash = "sha256:b36f1fef9334a5588b4166f8bcd26a14e521f2b55e6b9de3aaa80d3ff7a37529";
      platformTags = [ "any" ];
    };
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
  };
  "pathspec" = {
    version = "1.0.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/32/2b/121e912bd60eebd623f873fd090de0e84f322972ab25a7f9044c056804ed/pathspec-1.0.3-py3-none-any.whl";
      hash = "sha256:e80767021c1cc524aa3fb14bedda9c34406591343cc42797b386ce7b9354fb6c";
      platformTags = [ "any" ];
    };
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
  };
  "platformdirs" = {
    version = "4.5.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cb/28/3bfe2fa5a7b9c46fe7e13c97bda14c895fb10fa2ebf1d0abb90e0cea7ee1/platformdirs-4.5.1-py3-none-any.whl";
      hash = "sha256:d03afa3963c806a9bed9d5125c8f4cb2fdaf74a55ab60e5d59b3fde758104d31";
      platformTags = [ "any" ];
    };
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
  };
  "prometheus-client" = {
    version = "0.24.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/22/dd/50260b80759f90e3be66f094e0cd1fdef680b18d9f91edc9ae1b627624ba/prometheus_client-0.24.0-py3-none-any.whl";
      hash = "sha256:4ab6d4fb5a1b25ad74b58e6271857e356fff3399473e599d227ab5d0ce6637f0";
      platformTags = [ "any" ];
    };
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
  };
  "proto-plus" = {
    version = "1.27.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cd/24/3b7a0818484df9c28172857af32c2397b6d8fcd99d9468bd4684f98ebf0a/proto_plus-1.27.0-py3-none-any.whl";
      hash = "sha256:1baa7f81cf0f8acb8bc1f6d085008ba4171eaf669629d1b6d1673b21ed1c0a82";
      platformTags = [ "any" ];
    };
  };
  "protobuf" = {
    version = "6.33.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9b/53/a9443aa3ca9ba8724fdfa02dd1887c1bcd8e89556b715cfbacca6b63dbec/protobuf-6.33.5-cp39-abi3-manylinux2014_x86_64.whl";
      hash = "sha256:cbf16ba3350fb7b889fca858fb215967792dc125b35c7976ca4818bee3521cf0";
      platformTags = [ "manylinux2014_x86_64" ];
    };
  };
  "psycopg" = {
    version = "3.3.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8c/51/2779ccdf9305981a06b21a6b27e8547c948d85c41c76ff434192784a4c93/psycopg-3.3.2-py3-none-any.whl";
      hash = "sha256:3e94bc5f4690247d734599af56e51bae8e0db8e4311ea413f801fef82b14a99b";
      platformTags = [ "any" ];
    };
  };
  "psycopg-c" = {
    version = "3.3.2";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/48/f5/13c6bf88f6ccadc2930066cc5369cee431fc2c87a1ddb621fc27cfe7d8f3/psycopg_c-3.3.2.tar.gz";
      hash = "sha256:a65927731d394cc77bbf85d02d0311d7843616a4a627f3e816e94ad3a052ef83";
    };
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
  };
  "py-ubjson" = {
    version = "0.16.1";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/1d/c7/28220d37e041fe1df03e857fe48f768dcd30cd151480bf6f00da8713214a/py-ubjson-0.16.1.tar.gz";
      hash = "sha256:b9bfb8695a1c7e3632e800fb83c943bf67ed45ddd87cd0344851610c69a5a482";
    };
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
  };
  "pycparser" = {
    version = "2.23";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a0/e3/59cd50310fc9b59512193629e1984c1f95e5c8ae6e5d8c69532ccc65a7fe/pycparser-2.23-py3-none-any.whl";
      hash = "sha256:e5c6e8d3fbad53479cab09ac03729e0a9faf2bee3db8208a550daf5af81a5934";
      platformTags = [ "any" ];
    };
  };
  "pydantic" = {
    version = "2.12.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/5a/87/b70ad306ebb6f9b585f114d0ac2137d792b48be34d732d60e597c2f8465a/pydantic-2.12.5-py3-none-any.whl";
      hash = "sha256:e561593fccf61e8a20fc46dfc2dfe075b8be7d0188df33f221ad1f0139180f9d";
      platformTags = [ "any" ];
    };
  };
  "pydantic-core" = {
    version = "2.41.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/4c/d2/ef2074dc020dd6e109611a8be4449b98cd25e1b9b8a303c2f0fca2f2bcf7/pydantic_core-2.41.5-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:22f0fb8c1c583a3b6f24df2470833b40207e907b90c928cc8d3594b76f874375";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
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
  };
  "pygments" = {
    version = "2.19.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c7/21/705964c7812476f378728bdf590ca4b771ec72385c533964653c68e86bdc/pygments-2.19.2-py3-none-any.whl";
      hash = "sha256:86540386c03d588bb81d44bc3928634ff26449851e99741617ecb9037ee5ec0b";
      platformTags = [ "any" ];
    };
  };
  "pyjwt" = {
    version = "2.11.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6f/01/c26ce75ba460d5cd503da9e13b21a33804d38c2165dec7b716d06b13010c/pyjwt-2.11.0-py3-none-any.whl";
      hash = "sha256:94a6bde30eb5c8e04fee991062b534071fd1439ef58d2adc9ccb823e7bcd0469";
      platformTags = [ "any" ];
    };
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
  };
  "pyopenssl" = {
    version = "25.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/d1/81/ef2b1dfd1862567d573a4fdbc9f969067621764fbb74338496840a1d2977/pyopenssl-25.3.0-py3-none-any.whl";
      hash = "sha256:1fda6fc034d5e3d179d39e59c1895c9faeaf40a79de5fc4cbbfbe0d36f4a77b6";
      platformTags = [ "any" ];
    };
  };
  "pyparsing" = {
    version = "3.3.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8b/40/2614036cdd416452f5bf98ec037f38a1afb17f327cb8e6b652d4729e0af8/pyparsing-3.3.1-py3-none-any.whl";
      hash = "sha256:023b5e7e5520ad96642e2c6db4cb683d3970bd640cdf7115049a6e9c3682df82";
      platformTags = [ "any" ];
    };
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
  };
  "pytest" = {
    version = "9.0.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3b/ab/b3226f0bd7cdcf710fbede2b3548584366da3b19b5021e74f5bde2a8fa3f/pytest-9.0.2-py3-none-any.whl";
      hash = "sha256:711ffd45bf766d5264d487b917733b453d917afd2b0ad65223959f59089f875b";
      platformTags = [ "any" ];
    };
  };
  "pytest-django" = {
    version = "4.11.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/be/ac/bd0608d229ec808e51a21044f3f2f27b9a37e7a0ebaca7247882e67876af/pytest_django-4.11.1-py3-none-any.whl";
      hash = "sha256:1b63773f648aa3d8541000c26929c1ea63934be1cfa674c76436966d73fe6a10";
      platformTags = [ "any" ];
    };
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
  };
  "pytest-github-actions-annotate-failures" = {
    version = "0.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6d/73/7b0b15cb8605ee967b34aa1d949737ab664f94e6b0f1534e8339d9e64ab2/pytest_github_actions_annotate_failures-0.3.0-py3-none-any.whl";
      hash = "sha256:41ea558ba10c332c0bfc053daeee0c85187507b2034e990f21e4f7e5fef044cf";
      platformTags = [ "any" ];
    };
  };
  "pytest-randomly" = {
    version = "4.0.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/33/3e/a4a9227807b56869790aad3e24472a554b585974fe7e551ea350f50897ae/pytest_randomly-4.0.1-py3-none-any.whl";
      hash = "sha256:e0dfad2fd4f35e07beff1e47c17fbafcf98f9bf4531fd369d9260e2f858bfcb7";
      platformTags = [ "any" ];
    };
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
  };
  "python-dotenv" = {
    version = "1.2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/14/1b/a298b06749107c305e1fe0f814c6c74aea7b2f1e10989cb30f544a1b3253/python_dotenv-1.2.1-py3-none-any.whl";
      hash = "sha256:b81ee9561e9ca4004139c6cbba3a238c32b03e4894671e181b671e8cb8425d61";
      platformTags = [ "any" ];
    };
  };
  "python-kadmin-rs" = {
    version = "0.7.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/0b/51/391a3d8ee99aeb2466efe499e52ef6a7479d7ac426635d92cd050a5fe3f9/python_kadmin_rs-0.7.0-cp314-cp314-manylinux_2_28_x86_64.whl";
      hash = "sha256:82107ee5ea3dc1a3b716323687febc64ed2fa462ebd986565fba7394add04792";
      platformTags = [ "manylinux_2_28_x86_64" ];
    };
  };
  "pytokens" = {
    version = "0.3.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/84/25/d9db8be44e205a124f6c98bc0324b2bb149b7431c53877fc6d1038dddaf5/pytokens-0.3.0-py3-none-any.whl";
      hash = "sha256:95b2b5eaf832e469d141a378872480ede3f251a5a5041b8ec6e581d3ac71bbf3";
      platformTags = [ "any" ];
    };
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
  };
  "requests" = {
    version = "2.32.5";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1e/db/4254e3eabe8020b458f1a747140d32277ec7a271daf1d235b70dc0b4e6e3/requests-2.32.5-py3-none-any.whl";
      hash = "sha256:2462f94637a34fd532264295e186976db0f5d453d1cdd31473c85a6a161affb6";
      platformTags = [ "any" ];
    };
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
  };
  "rich" = {
    version = "14.2.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/25/7a/b0178788f8dc6cafce37a212c99565fa1fe7872c70c6c9c1e1a372d9d88f/rich-14.2.0-py3-none-any.whl";
      hash = "sha256:76bc51fe2e57d2b1be1f96c524b890b816e334ab4c1e45888799bfaab0021edd";
      platformTags = [ "any" ];
    };
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
  };
  "rsa" = {
    version = "4.9.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/64/8d/0133e4eb4beed9e425d9a98ed6e081a55d195481b7632472be1af08d2f6b/rsa-4.9.1-py3-none-any.whl";
      hash = "sha256:68635866661c6836b8d39430f97a996acbd61bfa49406748ea243539fe239762";
      platformTags = [ "any" ];
    };
  };
  "ruff" = {
    version = "0.15.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8a/d9/0e3a81467a120fd265658d127db648e4d3acfe3e4f6f5d4ea79fac47e587/ruff-0.15.0-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256:bcbca3d40558789126da91d7ef9a7c87772ee107033db7191edefa34e2c7f1b4";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" ];
    };
  };
  "s3transfer" = {
    version = "0.16.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fc/51/727abb13f44c1fcf6d145979e1535a35794db0f6e450a0cb46aa24732fe2/s3transfer-0.16.0-py3-none-any.whl";
      hash = "sha256:18e25d66fed509e3868dc1572b3f427ff947dd2c56f844a5bf09481ad3f3b2fe";
      platformTags = [ "any" ];
    };
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
  };
  "selenium" = {
    version = "4.40.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/9d/74/eb9d6540aca1911106fa0877b8e9ef24171bc18857937a6b0ffe0586c623/selenium-4.40.0-py3-none-any.whl";
      hash = "sha256:c8823fc02e2c771d9ad9a0cf899cee7de1a57a6697e3d0b91f67566129f2b729";
      platformTags = [ "any" ];
    };
  };
  "sentry-sdk" = {
    version = "2.52.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ca/63/2c6daf59d86b1c30600bff679d039f57fd1932af82c43c0bde1cbc55e8d4/sentry_sdk-2.52.0-py2.py3-none-any.whl";
      hash = "sha256:931c8f86169fc6f2752cb5c4e6480f0d516112e78750c312e081ababecbaf2ed";
      platformTags = [ "any" ];
    };
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
  };
  "setuptools" = {
    version = "80.9.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a3/dc/17031897dae0efacfea57dfd3a82fdd2a2aeb58e0ff71b77b87e44edc772/setuptools-80.9.0-py3-none-any.whl";
      hash = "sha256:062d34222ad13e0cc312a4c02d73f059e86a4acbfbdea8f8f76b28c99f306922";
      platformTags = [ "any" ];
    };
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
  };
  "stevedore" = {
    version = "5.6.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f4/40/8561ce06dc46fd17242c7724ab25b257a2ac1b35f4ebf551b40ce6105cfa/stevedore-5.6.0-py3-none-any.whl";
      hash = "sha256:4a36dccefd7aeea0c70135526cecb7766c4c84c473b1af68db23d541b6dc1820";
      platformTags = [ "any" ];
    };
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
  };
  "tenacity" = {
    version = "9.1.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/e5/30/643397144bfbfec6f6ef821f36f33e57d35946c44a2352d3c9f0ae847619/tenacity-9.1.2-py3-none-any.whl";
      hash = "sha256:f77bf36710d8b73a50b2dd155c97b870017ad21afe6ab300326b0371b3b05138";
      platformTags = [ "any" ];
    };
  };
  "trio" = {
    version = "0.32.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/41/bf/945d527ff706233636c73880b22c7c953f3faeb9d6c7e2e85bfbfd0134a0/trio-0.32.0-py3-none-any.whl";
      hash = "sha256:4ab65984ef8370b79a76659ec87aa3a30c5c7c83ff250b4de88c29a8ab6123c5";
      platformTags = [ "any" ];
    };
  };
  "trio-typing" = {
    version = "0.10.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/89/ff/9bd795273eb14fac7f6a59d16cc8c4d0948a619a1193d375437c7f50f3eb/trio_typing-0.10.0-py3-none-any.whl";
      hash = "sha256:6d0e7ec9d837a2fe03591031a172533fbf4a1a95baf369edebfc51d5a49f0264";
      platformTags = [ "any" ];
    };
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
  };
  "twilio" = {
    version = "9.10.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/ec/cd/7ed6a38615e85e6d5821220afe750998ff28d35074c8f60ccc702b2bdc67/twilio-9.10.1-py2.py3-none-any.whl";
      hash = "sha256:14ecba426bea509c6422a139d5dc6b63c4e82271c665d0730f67db0225de5e1d";
      platformTags = [ "any" ];
    };
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
  };
  "types-certifi" = {
    version = "2021.10.8.3";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/b5/63/2463d89481e811f007b0e1cd0a91e52e141b47f9de724d20db7b861dcfec/types_certifi-2021.10.8.3-py3-none-any.whl";
      hash = "sha256:b2d1e325e69f71f7c78e5943d410e650b4707bb0ef32e4ddf3da37f54176e88a";
      platformTags = [ "any" ];
    };
  };
  "types-channels" = {
    version = "4.3.0.20250822";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cb/52/4e3094e43d460feacb9051ec4c3498f8272f69d92b772647211478b25079/types_channels-4.3.0.20250822-py3-none-any.whl";
      hash = "sha256:d3fc0a1467c8cc901686826408c8a673822e07aa79cbe1a6d21946e7e55d9ddf";
      platformTags = [ "any" ];
    };
  };
  "types-docker" = {
    version = "7.1.0.20260109";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/8f/0d/cdf37dcd0cd4c942a1634daf3ae3a99833791c7a316bff4d4ce04a30652e/types_docker-7.1.0.20260109-py3-none-any.whl";
      hash = "sha256:001a5a377d3fb287b7279cf4265b8ba3857e7d4203a16ab03e6e512f68f2f3d4";
      platformTags = [ "any" ];
    };
  };
  "types-jwcrypto" = {
    version = "1.5.0.20251102";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/cf/15/e305c0ae6aaca68842c73fee5080eadd51a702a1562f05d9653d6e9b5a94/types_jwcrypto-1.5.0.20251102-py3-none-any.whl";
      hash = "sha256:506c93a09c6a988fc5a56bfe92f0cf80b31a0acee98bd6e807277bb0c6f8c1d0";
      platformTags = [ "any" ];
    };
  };
  "types-ldap3" = {
    version = "2.9.13.20251121";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a9/28/05989820ae4694b15acf9fe26c73901fda117d99720954e969b5ec498399/types_ldap3-2.9.13.20251121-py3-none-any.whl";
      hash = "sha256:20356bf413cb178898f5b171463b44b82044b8b69f9331e09950009cfef05e48";
      platformTags = [ "any" ];
    };
  };
  "types-paramiko" = {
    version = "4.0.0.20250822";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/79/a1/b3774ed924a66ee2c041224d89c36f0c21f4f6cf75036d6ee7698bf8a4b9/types_paramiko-4.0.0.20250822-py3-none-any.whl";
      hash = "sha256:55bdb14db75ca89039725ec64ae3fa26b8d57b6991cfb476212fa8f83a59753c";
      platformTags = [ "any" ];
    };
  };
  "types-pyasn1" = {
    version = "0.6.0.20250914";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6c/9d/5eb611d0db5b980cbb7d3eaca5baf187d5346f6371fdb6c708847539cea6/types_pyasn1-0.6.0.20250914-py3-none-any.whl";
      hash = "sha256:68ffeef3c28e1ed120b8b81a242f238f137543e68d466d84a97edcf3e4203b5b";
      platformTags = [ "any" ];
    };
  };
  "types-pyyaml" = {
    version = "6.0.12.20250915";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/bd/e0/1eed384f02555dde685fff1a1ac805c1c7dcb6dd019c916fe659b1c1f9ec/types_pyyaml-6.0.12.20250915-py3-none-any.whl";
      hash = "sha256:e7d4d9e064e89a3b3cae120b4990cd370874d2bf12fa5f46c97018dd5d3c9ab6";
      platformTags = [ "any" ];
    };
  };
  "types-requests" = {
    version = "2.32.4.20260107";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/1c/12/709ea261f2bf91ef0a26a9eed20f2623227a8ed85610c1e54c5805692ecb/types_requests-2.32.4.20260107-py3-none-any.whl";
      hash = "sha256:b703fe72f8ce5b31ef031264fe9395cac8f46a04661a79f7ed31a80fb308730d";
      platformTags = [ "any" ];
    };
  };
  "types-urllib3" = {
    version = "1.26.25.14";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/11/7b/3fc711b2efea5e85a7a0bbfe269ea944aa767bbba5ec52f9ee45d362ccf3/types_urllib3-1.26.25.14-py3-none-any.whl";
      hash = "sha256:9683bbb7fb72e32bfe9d2be6e04875fbe1b3eeec3cbb4ea231435aa7fd6b4f0e";
      platformTags = [ "any" ];
    };
  };
  "types-zxcvbn" = {
    version = "4.5.0.20250809";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/6b/e0/0af4e865c28da104fa6ec45a2a336521fe34cbe606ef2ab6984b14d96e2c/types_zxcvbn-4.5.0.20250809-py3-none-any.whl";
      hash = "sha256:2cd151a5b35a976ae22017b5caed8f99d5e1be455cf9f9497cd86419073bc9cb";
      platformTags = [ "any" ];
    };
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
  };
  "ua-parser" = {
    version = "1.0.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/94/37/be6dfbfa45719aa82c008fb4772cfe5c46db765a2ca4b6f524a1fdfee4d7/ua_parser-1.0.1-py3-none-any.whl";
      hash = "sha256:b059f2cb0935addea7e551251cbbf42e9a8872f86134163bc1a4f79e0945ffea";
      platformTags = [ "any" ];
    };
  };
  "ua-parser-builtins" = {
    version = "202601";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/fd/82/aab481e2fc6dee0a13ce35c750e97dbe3f270fb327089c99a8f5e6900e0c/ua_parser_builtins-202601-py3-none-any.whl";
      hash = "sha256:f5dc93b0f53724dcd5c3eb79edb0aea281cb304a2c02a9436cbeb8cfb8bc4ad1";
      platformTags = [ "any" ];
    };
  };
  "ujson" = {
    version = "5.11.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/55/7a/4572af5324ad4b2bfdd2321e898a527050290147b4ea337a79a0e4e87ec7/ujson-5.11.0-cp314-cp314-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:f278b31a7c52eb0947b2db55a5133fbc46b6f0ef49972cd1a80843b72e135aba";
      platformTags = [ "manylinux_2_24_x86_64" "manylinux_2_28_x86_64" ];
    };
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
  };
  "uvicorn" = {
    version = "0.40.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/3d/d8/2083a1daa7439a66f3a48589a57d576aa117726762618f6bb09fe3798796/uvicorn-0.40.0-py3-none-any.whl";
      hash = "sha256:c6c8f55bc8bf13eb6fa9ff87ad62308bbbc33d0b67f84293151efe87e0d5f2ee";
      platformTags = [ "any" ];
    };
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
  };
  "watchdog-gevent" = {
    version = "0.2.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/00/a9/54b88e150b77791958957e2188312477d09fc84820fc03f8b3a7569d10b0/watchdog_gevent-0.2.1-py3-none-any.whl";
      hash = "sha256:e8114658104a018f626ee54052335407c1438369febc776c4b4c4308ed002350";
      platformTags = [ "any" ];
    };
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
  };
  "wcwidth" = {
    version = "0.2.14";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/af/b5/123f13c975e9f27ab9c0770f514345bd406d0e8d3b7a0723af9d43f710af/wcwidth-0.2.14-py2.py3-none-any.whl";
      hash = "sha256:a7bb560c8aee30f9957e5f9895805edd20602f2d7f720186dfd906e82b4982e1";
      platformTags = [ "any" ];
    };
  };
  "webauthn" = {
    version = "2.7.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/73/b1/3f380d02552f1d75d3db789f761a1ee0dafd6181ebc07dd4b9ded61225a4/webauthn-2.7.0-py3-none-any.whl";
      hash = "sha256:2ecfee7959b09ebeaaffee9f8982ecdbbdc369a11766d20d4bc0637b36e235b7";
      platformTags = [ "any" ];
    };
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
  };
  "xmlsec" = {
    version = "1.3.17";
    fmt = "sdist";
    source = {
      type = "sdist";
      url = "https://files.pythonhosted.org/packages/49/14/538b75379e6ab8f688f14d8663e2ab138d9c778bac4999d155b5f33c71c1/xmlsec-1.3.17.tar.gz";
      hash = "sha256:f3fac9ae679f66585925cc00c5f6839ae36c1d03157619571dee18acc05b9c01";
    };
  };
  "yarl" = {
    version = "1.22.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/f5/e7/d8c5a7752fef68205296201f8ec2bf718f5c805a7a7e9880576c67600658/yarl-1.22.0-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256:bca03b91c323036913993ff5c738d0842fc9c60c4648e5c8d98331526df89784";
      platformTags = [ "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_28_x86_64" ];
    };
  };
  "zipp" = {
    version = "3.23.0";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/2e/54/647ade08bf0db230bfea292f893923872fd20be6ac6f53b2b936ba839d75/zipp-3.23.0-py3-none-any.whl";
      hash = "sha256:071652d6115ed432f5ce1d34c336c0adfd6a884660d1e9712a256d3d3bd4b14e";
      platformTags = [ "any" ];
    };
  };
  "zope-event" = {
    version = "6.1";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/c2/b0/956902e5e1302f8c5d124e219c6bf214e2649f92ad5fce85b05c039a04c9/zope_event-6.1-py3-none-any.whl";
      hash = "sha256:0ca78b6391b694272b23ec1335c0294cc471065ed10f7f606858fc54566c25a0";
      platformTags = [ "any" ];
    };
  };
  "zope-interface" = {
    version = "8.2";
    fmt = "wheel";
    source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/02/cc/b321c51d6936ede296a1b8860cf173bee2928357fe1fff7f97234899173f/zope_interface-8.2-cp314-cp314-manylinux1_x86_64.manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_5_x86_64.whl";
      hash = "sha256:aae807efc7bd26302eb2fea05cd6de7d59269ed6ae23a6de1ee47add6de99b8c";
      platformTags = [ "manylinux1_x86_64" "manylinux2014_x86_64" "manylinux_2_17_x86_64" "manylinux_2_5_x86_64" ];
    };
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
      version = "80.9.0";
      format = "wheel";
      source = {
      type = "wheel";
      url = "https://files.pythonhosted.org/packages/a3/dc/17031897dae0efacfea57dfd3a82fdd2a2aeb58e0ff71b77b87e44edc772/setuptools-80.9.0-py3-none-any.whl";
      hash = "sha256:062d34222ad13e0cc312a4c02d73f059e86a4acbfbdea8f8f76b28c99f306922";
      platformTags = [ "any" ];
    };
    };
  };
}
