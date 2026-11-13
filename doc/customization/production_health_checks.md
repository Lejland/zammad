# Production Health Checks and Bad Gateway Recovery

An SSO redirect ending at `/auth/sso` with HTTP 502 does not necessarily mean
that identity validation or just-in-time provisioning failed. A reverse proxy
returns 502 when its application upstream is unavailable. Check the complete
service chain before changing authentication policy or user records.

## Reusable health check

Run the generic host-side check as root on a package-based deployment:

```bash
sudo script/custom/zammad_health_check.sh
```

It verifies:

- Zammad wrapper services and any discovered web, worker, and WebSocket instance
  units.
- The PostgreSQL wrapper and any discovered cluster instance unit.
- Configured application, database, and WebSocket listeners.
- That the PostgreSQL service account can open its TLS key, without displaying
  any key material.
- Current database migrations, the reverse-proxy response, the direct Rails
  upstream response, and the absence of failed systemd units.

The defaults match a common Debian/Ubuntu package layout. Override assumptions
with environment variables rather than editing the script:

```bash
sudo ZAMMAD_EXTRA_SERVICES="example-auth-adapter" \
  ZAMMAD_POSTGRES_TLS_KEY="/path/to/postgresql.key" \
  ZAMMAD_REQUIRED_PORTS="3000 5432 6042" \
  script/custom/zammad_health_check.sh
```

Do not store deployment values, hostnames, credentials, certificates, or private
paths in this repository.

## 502 investigation order

1. Confirm nginx or the selected reverse proxy is active.
2. Test the Rails upstream directly on loopback.
3. Check listening ports instead of relying only on wrapper-unit state.
4. Inspect failed units and the actual instance units below the wrappers.
5. Confirm the PostgreSQL cluster is active and listening.
6. If PostgreSQL reports a TLS-key permission error, compare its configured key
   path with the filesystem owner, group, mode, and parent-directory traversal.
   Test only whether the PostgreSQL service account can open the file; never
   print the key.
7. Restore the distribution-appropriate ownership and permissions, restart only
   the failed services, and rerun the complete check.

Some package layouts use active placeholder or wrapper units while their real
instance services have failed. Therefore an `active` top-level Zammad service is
not sufficient evidence that Rails, the worker, or WebSocket process is running.

Do not disable TLS, bypass SSO validation, delete users, or change roles merely
to clear a 502. Those actions do not repair an unavailable upstream.

## New-user verification

After infrastructure health is restored, verify JIT provisioning separately in
a disposable environment or a rollback-only database transaction:

- A new internal identity receives only the configured default role.
- The short login and full email identity are stored as intended.
- The account is active and verified.
- No account-notification mail job is enqueued.
- Existing agents and administrators retain every existing role.
- An identity outside the configured domain is rejected.

Also confirm the unauthenticated root route redirects to the SSO entry point and
that the SSO entry point redirects to the identity provider when no valid access
state is present.
