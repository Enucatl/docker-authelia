# authelia-config

## Security baseline

This compose project uses the shared [docker-compose-security-baseline](https://github.com/Enucatl/docker-compose-security-baseline) for common container hardening defaults, including capabilities, no-new-privileges, memory/swap, and PID limits.

## Jellyfin OIDC

Jellyfin at `https://jellyfin.atlas.home.arpa` uses client `jellyfin` directly;
its Traefik route has no Authelia ForwardAuth gate. The client requires PKCE
S256 and `client_secret_post`, with callback
`https://jellyfin.atlas.home.arpa/sso/OID/redirect/authelia`.

The `jellyfin` policy permits authenticated FreeIPA users with one-factor login
and explicitly denies the read-only `ldap_ro` service account. The ID token
includes `preferred_username`, `groups`, and `name`; Jellyfin maps `admins` group
membership to administration and grants other users viewing access. Android TV
signs in using Jellyfin Quick Connect after browser SSO.

The PBKDF2 client-secret digest is mounted from ignored
`secrets/oidc_jellyfin_client_secret_digest`; grant read access to remapped UID
101000. The corresponding raw secret is private in the Jellyfin stack, whose
SSO plugin stores it in its writable configuration volume. Rotate both together.
See [the Jellyfin setup](https://github.com/Enucatl/docker-jellyfin) for plugin
settings, backups, and client sign-in instructions.
