#!/bin/sh
# Validate the real template and ACL engine without production credentials or services.
set -eu
if [ "${1:-}" = inside ]; then
  mkdir -p /run/secrets
  authelia crypto pair rsa generate --directory /run/secrets --file.private-key oidc_jwks_rs256_key >/dev/null
  authelia crypto pair ecdsa generate --directory /run/secrets --file.private-key oidc_jwks_es256_key >/dev/null
  for client in jellyfin grafana beszel; do
    authelia crypto hash generate pbkdf2 --password dummy-test-client-password --iterations 310000 | sed 's/^Digest: //' > "/run/secrets/oidc_${client}_client_secret_digest"
  done
  printf '%s' dummy-hmac-secret-at-least-sixty-four-characters-long-for-isolated-test-only > /run/secrets/oidc_hmac_secret
  export X_AUTHELIA_CONFIG_FILTERS=template ACME_DOCKER_DOMAIN=atlas.intranet.enucatl.com
  export LAN_SUBNET=10.0.0.0/24 TRUSTED_WIFI_SUBNET=10.0.10.0/24 WG_SUBNET=10.0.200.0/24
  export IPV6_LAN_SUBNET=2001:db8::/64 IPV6_TRUSTED_WIFI_SUBNET=2001:db8:a::/64 IPV6_WG_SUBNET=2001:db8:c8::/64
  export SMTP_USERNAME=test@example.com SMTP_SENDER=test@example.com
  export AUTHELIA_AUTHENTICATION_BACKEND_LDAP_ADDRESS=ldaps://ipa.home.arpa AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD=dummy
  export AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET=dummy-reset-password-secret-at-least-thirty-two-characters
  export AUTHELIA_SESSION_SECRET=dummy-session-secret-at-least-thirty-two-characters
  export AUTHELIA_STORAGE_ENCRYPTION_KEY=dummy-storage-secret-at-least-thirty-two-characters AUTHELIA_STORAGE_POSTGRES_PASSWORD=dummy
  authelia config validate --config /config/configuration.yml
  check() {
    result=$(authelia access-control check-policy --config /config/configuration.yml --url "https://$1" --ip "$2" --username test --groups "$3")
    printf '%s\n' "$result" | grep -q "policy '$4'" || { printf '%s\n' "$result"; exit 1; }
    printf 'PASS %s %s %s => %s\n' "$1" "$2" "$3" "$4"
  }
  for domain in atlas.home.arpa atlas.intranet.enucatl.com; do
    check "grafana.$domain" 10.0.0.2 admins one_factor
    check "grafana.$domain" fd6b:d722:1738::2 admins one_factor
    check "grafana.$domain" fd6b:d722:1738:1e::2 admins deny
    check "grafana.$domain" 10.0.0.2 users deny
    check "grafana.$domain" 10.0.30.2 admins deny
    check "wolf.$domain" 10.0.0.2 wolf-operators one_factor
    check "grafana.$domain" 10.0.0.2 wolf-operators deny
    check "browser-use.$domain" 172.17.96.1 admins one_factor
    check "grindr-api-dev-tool.$domain" 172.17.96.1 admins one_factor
    check "browser-use.$domain" 172.17.96.2 admins deny
  done
  check grafana.example.com 10.0.0.2 admins deny
  exit 0
fi
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
docker run --rm --userns=host --network none --user 0:0 \
  --mount "type=bind,source=$repo/config/configuration.yml,target=/config/configuration.yml,readonly" \
  --mount "type=bind,source=$repo/tests/check-domains.sh,target=/check-domains.sh,readonly" \
  --entrypoint sh authelia/authelia:latest /check-domains.sh inside
