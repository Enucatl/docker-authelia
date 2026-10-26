# authelia-config

## Security baseline

This compose project uses the shared [docker-compose-security-baseline](https://github.com/Enucatl/docker-compose-security-baseline) for common container hardening defaults, including capabilities, no-new-privileges, memory/swap, and PID limits.

## Jellyfin OIDC

Jellyfin on both `https://jellyfin.atlas.home.arpa` and
`https://jellyfin.atlas.intranet.enucatl.com` uses client `jellyfin` directly;
its Traefik route has no Authelia ForwardAuth gate. The client requires PKCE
S256 and `client_secret_post`, with `/sso/OID/redirect/authelia` callbacks
registered on both Jellyfin hostnames. Jellyfin uses
`https://authelia.atlas.intranet.enucatl.com` as its OIDC endpoint.

Authelia serves both `authelia.atlas.home.arpa` and
`authelia.atlas.intranet.enucatl.com`. Each domain has its own session cookie
and portal URL; browsers cannot share cookies between these domains. Specific
access policies and the admin wildcard apply equally to both namespaces.
Grafana and Beszel retain their existing `home.arpa` endpoints and callbacks.
The existing Vault certificates remain alongside the production ACME certificate.

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

## Verification

Run `tests/check-domains.sh` to validate the configuration and both namespaces'
access policies with the actual Authelia image in a disposable container. It
uses dummy credentials and does not connect to production services.

Deployed on 2026-10-26: both portals and their matching OIDC discovery issuers
respond over trusted HTTPS. Jellyfin's real login starts on both hostnames use
the new portal, retain their original callbacks and PKCE, and are accepted by
Authelia. Grafana and Beszel authorization starts retain the old portal.
Anonymous logout succeeds on both domains. No account login was performed;
authenticated cookie creation and session invalidation remain unverified.
Logging out of Jellyfin does not log out of Authelia, and each portal domain
has a separate browser session.
