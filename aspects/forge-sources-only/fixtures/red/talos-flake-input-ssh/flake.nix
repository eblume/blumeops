{
  description = "fixture";

  inputs.hephaestus.url = "git+ssh://forgejo@forge.ops.eblu.me:2222/talos/hephaestus.git?ref=v1.0.0";

  outputs = { self, hephaestus }: { };
}
