Give the jellyfin role's SSO-Auth extraction task a `creates:` guard on the
versioned plugin dir's `SSO-Auth.dll`. The `remote_src` unarchive always
reported changed, so every provision-indri run fired the "Reload jellyfin"
handler and restarted the service for no reason. A version bump moves the
dest dir, so the guard re-arms itself and the handler fires on the update
as intended.
