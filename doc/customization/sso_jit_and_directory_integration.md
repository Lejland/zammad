# SSO JIT and Directory Integration

This customization lets a trusted reverse proxy establish a Zammad session and,
when explicitly requested by that proxy, create or reconcile an internal user.
It contains no identity-provider client, token validator, LDAP password, private
endpoint, certificate, domain, or production role assignment.

## Tracked components

- `SessionsController#create_sso` keeps Zammad's standard SSO and trusted-proxy
  checks, then delegates identities marked for internal provisioning.
- `Service::User::SsoJitProvisioning` validates a configured email domain,
  matches an existing user by full email or short login, and creates a user only
  when no match exists.
- Focused service and request specs cover the security boundary and role policy.

The reverse-proxy validation adapter, identity-provider URLs, shared-cookie
details, TLS material, DNS, allowed proxy addresses, and runtime configuration
are deployment artifacts and must remain outside Git.

## Request contract

The reverse proxy must validate the identity before calling `/auth/sso`. It must
remove identity headers supplied by the browser and set its own trusted values:

- `X-Forwarded-User`: a normalized, lowercase email identity.
- `X-SSO-Provision: internal`: opt in to JIT provisioning.
- `X-SSO-Realname-B64`: optional URL-safe Base64 display name.

Requests without the provisioning marker retain Zammad's standard behavior and
can sign in only an existing user. Configure Zammad's SSO trusted-IP setting so
only the reverse proxy can reach this contract, and prevent direct access to the
application upstream.

## Private runtime policy

The service reads `/etc/zammad-sso/provisioning.json`. Create this file during
deployment with restrictive ownership and keep it out of source control. Its
schema is:

```json
{
  "enabled": true,
  "email_domain": "example.com",
  "default_role": "Customer",
  "customer_role": "Customer",
  "source": "sso",
  "promote_customer_only": false
}
```

Use values appropriate to the target deployment. `default_role` is assigned
only when a user is created. Existing users keep their current roles unless
`promote_customer_only` is deliberately enabled and they have only the role
named by `customer_role`. Privileged users therefore retain their roles under
the recommended `false` policy.

User saves run in Zammad's bulk-import context. This prevents normal account
creation or verification notifications from being queued. The state is restored
after every save, including failed saves.

## LDAP and directory boundary

This feature does not bind to LDAP and does not configure a Zammad LDAP source.
It expects the trusted SSO layer to have validated the identity. New users get
the email local part as their Zammad login, which aligns with common directory
`uid` mappings, while the complete email remains on the account.

If native LDAP synchronization is added later, configure it separately with
encrypted transport, a dedicated least-privilege account, explicit attribute
mapping, and a reviewed activation/deactivation policy. Never reuse an
application or DNS-management credential. Confirm how the importer handles
missing email attributes, role mapping, existing short logins, and inactive
accounts before enabling a schedule.

## External and recovery access

Public signup and local recovery login remain reverse-proxy deployment choices.
A deployment may expose short convenience routes such as `/signup` and `/login`
while keeping the site root SSO-first. Their concrete redirects and hostnames are
not part of this repository.

For SSO sessions, `DELETE /api/v1/signout` returns the relative handoff URL
`/auth/sso/logout`. The trusted reverse proxy should implement that exact route,
clear the application session cookie, and redirect to the identity provider logout
endpoint. Local-password, LDAP, SAML, and OIDC logout behavior is not changed by
this handoff.

Do not treat the mere presence of an application session cookie as proof that
the session is valid after logout. If the reverse proxy uses cookie presence to
let an established session load the application root, its SSO logout handoff
must expire that cookie.

If the identity provider changes its shared access-token format, a browser may
arrive with a cookie that the validation adapter correctly rejects. Avoid a
redirect loop by expiring only the rejected access cookie before redirecting to
a fresh SSO login. Continue to fail closed if the replacement token is missing,
invalid, expired, or revoked.

## Verification

1. Run the focused specs:

   ```bash
   RAILS_ENV=test VITE_TEST_MODE=1 bundle exec rspec \
     spec/services/service/user/sso_jit_provisioning_spec.rb \
     spec/requests/session_sso_jit_spec.rb
   ```

2. In a disposable environment, verify a new identity receives only the
   configured default role and no notification job is queued.
3. Verify an existing customer, agent, and administrator keep their roles.
4. Verify an unmarked request cannot create a user.
5. Verify a browser-supplied identity header cannot bypass the trusted proxy.
6. Verify invalid, expired, or revoked SSO state is denied by the adapter.
7. Verify SSO logout clears both the application session and SSO access cookie,
   then requires a fresh SSO login on the next visit.
8. Verify a rejected legacy-format access cookie is replaced through SSO rather
   than causing a redirect loop or exposing the application.
9. Verify local recovery access and external signup according to deployment
   policy.

For an SSO redirect that reaches `/auth/sso` but returns HTTP 502, verify the
application and database service chain before changing authentication settings.
See [Production Health Checks and Bad Gateway Recovery](production_health_checks.md).

## Rollback

Disable provisioning in the private runtime policy first. Restore the previous
controller and service files, restart the application services, and verify
standard existing-user SSO plus local recovery access. Disabling JIT does not
delete users that were already created.
