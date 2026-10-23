pkgs.makeSetupHook
  {
    name = "evil-hook";
  }
  (
    pkgs.writeShellScript "evil-hook" ''
      postConfigureHooks+=(evilHook)
    ''
  )
