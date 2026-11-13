#!/usr/bin/env bash

set -Eeuo pipefail

ZAMMAD_ROOT="${ZAMMAD_ROOT:-/opt/zammad}"
ZAMMAD_COMMAND="${ZAMMAD_COMMAND:-zammad}"
ZAMMAD_HTTP_URL="${ZAMMAD_HTTP_URL:-http://127.0.0.1/}"
ZAMMAD_APP_URL="${ZAMMAD_APP_URL:-http://127.0.0.1:3000/}"
ZAMMAD_REQUIRED_PORTS="${ZAMMAD_REQUIRED_PORTS:-3000 5432 6042}"
ZAMMAD_REQUIRED_SERVICES="${ZAMMAD_REQUIRED_SERVICES:-zammad zammad-web zammad-websocket zammad-worker nginx postgresql elasticsearch redis-server}"
ZAMMAD_EXTRA_SERVICES="${ZAMMAD_EXTRA_SERVICES:-}"
ZAMMAD_POSTGRES_OS_USER="${ZAMMAD_POSTGRES_OS_USER:-postgres}"
ZAMMAD_POSTGRES_TLS_KEY="${ZAMMAD_POSTGRES_TLS_KEY:-/etc/ssl/private/ssl-cert-snakeoil.key}"

ok() { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command is missing: $1"
}

require_http_200() {
  local label="$1" url="$2" code
  code="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 10 "$url")" ||
    fail "$label did not respond: $url"
  [[ "$code" == 200 ]] || fail "$label returned HTTP $code: $url"
  ok "$label returned HTTP 200"
}

discover_instance_units() {
  local pattern
  for pattern in 'zammad-web-*.service' 'zammad-worker-*.service' 'zammad-websocket-*.service' 'postgresql@*.service'; do
    systemctl list-units --all --type=service --no-legend --plain "$pattern" 2>/dev/null |
      awk '{print $1}'
  done
}

main() {
  local unit port state
  local -A checked=()
  local -a units=()

  require_command curl
  require_command runuser
  require_command ss
  require_command systemctl
  require_command "$ZAMMAD_COMMAND"

  read -r -a units <<<"$ZAMMAD_REQUIRED_SERVICES $ZAMMAD_EXTRA_SERVICES"
  while IFS= read -r unit; do
    [[ -n "$unit" ]] && units+=("$unit")
  done < <(discover_instance_units)

  for unit in "${units[@]}"; do
    [[ -n "$unit" && -z "${checked[$unit]:-}" ]] || continue
    checked[$unit]=1
    state="$(systemctl is-active "$unit" 2>/dev/null || true)"
    [[ "$state" == active ]] || fail "Service is not active: $unit ($state)"
  done
  ok "Required wrapper and discovered instance services are active"

  for port in $ZAMMAD_REQUIRED_PORTS; do
    [[ "$port" =~ ^[0-9]+$ ]] || fail "Invalid required port: $port"
    ss -H -lnt | awk '{print $4}' | grep -Eq ":${port}$" ||
      fail "Required listener is missing: TCP $port"
  done
  ok "Required application and database listeners are active"

  if [[ -n "$ZAMMAD_POSTGRES_TLS_KEY" && -e "$ZAMMAD_POSTGRES_TLS_KEY" ]]; then
    runuser -u "$ZAMMAD_POSTGRES_OS_USER" -- sh -c \
      'exec 3<"$1"; exec 3<&-' sh "$ZAMMAD_POSTGRES_TLS_KEY" ||
      fail "PostgreSQL service user cannot open its configured TLS key"
    ok "PostgreSQL service user can open the TLS key"
  else
    warn "PostgreSQL TLS-key check skipped because the configured path does not exist"
  fi

  [[ -d "$ZAMMAD_ROOT" ]] || fail "Zammad root does not exist: $ZAMMAD_ROOT"
  (
    cd "$ZAMMAD_ROOT"
    "$ZAMMAD_COMMAND" run rake db:abort_if_pending_migrations >/dev/null 2>&1
  ) || fail "Pending or unreadable database migrations"
  ok "Database migrations are current"

  require_http_200 "Reverse proxy" "$ZAMMAD_HTTP_URL"
  require_http_200 "Rails upstream" "$ZAMMAD_APP_URL"

  local failed
  failed="$(systemctl --failed --no-legend --plain | wc -l)"
  [[ "$failed" -eq 0 ]] || fail "$failed failed systemd unit(s) detected"
  ok "No failed systemd units"
}

main "$@"
