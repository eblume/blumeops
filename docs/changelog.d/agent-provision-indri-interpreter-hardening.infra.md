provision-indri's CI apply pins the ansible module interpreter to the
uvx venv python (the mise shim on the runner's PATH dies under sudo's
env_reset), and the forgejo-runner plist (nix-darwin copy and the role's
rollback re-write) gains `ExitTimeOut`/`AbandonProcessGroup` so a
generation switch that reloads the runner mid-job cannot kill the
in-flight job or the detached darwin-rebuild.
