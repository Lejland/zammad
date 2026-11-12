# Zammad Customization Workspace

This project maintains a small, reviewable set of generic customizations for a
self-hosted Zammad installation. It is intended to make collaboration,
testing, upgrades, and deployment safer without placing environment-specific
data in source control.

The current customization line is based on Zammad 7.2.2. Runtime versions and
deployment configuration are managed outside this repository.

## Start Here

- Read [CUSTOMIZATIONS.md](CUSTOMIZATIONS.md) for the feature catalog and
  sanitized change history.
- Read [CONTRIBUTING.md](CONTRIBUTING.md) before creating a branch or merge
  request.
- Read the [SSO JIT and directory integration guide](doc/customization/sso_jit_and_directory_integration.md)
  before changing authentication or user-provisioning behavior.
- Read [AGENTS.md](AGENTS.md) when using an AI coding agent.
- Use the local [developer manual](doc/developer_manual/index.md) for the
  upstream application architecture and development setup.
- Report upstream product vulnerabilities according to
  [SECURITY.md](SECURITY.md). Do not put secrets or vulnerability details in a
  public issue.

## Repository Model

`integration/customizations` is the maintained integration baseline. New work
should branch from it and return through a reviewed merge request.

Suggested branch names:

- `feature/<short-description>` for new behavior.
- `fix/<short-description>` for corrections.
- `docs/<short-description>` for documentation-only changes.
- `maintenance/<short-description>` for tests, tooling, and upgrade work.

The bootstrap `main` branch is not the customization baseline. Project
maintainers should set `integration/customizations` as the default branch when
the project settings permit it.

## What Belongs Here

- Generic application code and focused automated tests.
- Idempotent setup scripts that contain no private values.
- Documentation for behavior, validation, rollback, and upgrade concerns.
- Issue and merge-request templates for collaborative work.

The repository must not contain company names, private domains, addresses,
credentials, branded assets, ticket data, database dumps, backups, uploaded
signatures, or production configuration. Use neutral examples such as
`support@example.com` and placeholders such as `<CHANNEL_ID>`.

## Development Quick Start

1. Clone this project and switch to `integration/customizations`.
2. Create a focused branch using the naming scheme above.
3. Follow the existing Rails, CoffeeScript, Vue, and test conventions in
   `AGENTS.md` and the relevant file under `.dev/agent_docs/`.
4. Run the smallest relevant test set; do not rely only on manual testing.
5. Open a merge request with scope, test evidence, deployment impact, and a
   rollback note.

Common focused commands:

```bash
RAILS_ENV=test VITE_TEST_MODE=1 bundle exec rspec spec/path/to/file_spec.rb
pnpm test --run app/frontend/path/to/file.spec.ts
bundle exec rubocop app/path/to/file.rb
```

Consult the local developer manual before installing dependencies or starting
services. The complete upstream test suite is intentionally not the default
for small customization changes.

## Deployment Boundary

A merge is not a production deployment. Application changes must first be
validated in a non-production environment, backed up, and promoted using the
separate maintenance process. Database values, credentials, service addresses,
and environment-specific settings remain outside Git.

Before accepting an application update:

1. Compare the customization branch with the exact upstream release.
2. Resolve and review every overlap with customized files.
3. Run focused tests and build production frontend assets on a test system.
4. Create and verify a rollback backup.
5. Complete the functional checks described in `CUSTOMIZATIONS.md`.

Never treat an ordinary package update as safe when it can replace files under
the application directory.

## Upstream and License

This project is based on the Zammad open-source helpdesk. Product information,
documentation, and community resources are available from
[zammad.org](https://zammad.org/) and [docs.zammad.org](https://docs.zammad.org/).

Zammad and these modifications are distributed under the GNU Affero General
Public License v3. See [LICENSE](LICENSE) and the existing source-file notices.
