# Contributing

Thank you for helping improve this Zammad customization project. The goal is
to keep every change understandable, testable, upgradeable, and safe to share
with other contributors.

## Before You Start

1. Read [CUSTOMIZATIONS.md](CUSTOMIZATIONS.md) and check for overlapping work.
2. Open or update an issue with the problem, expected behavior, and acceptance
   criteria.
3. Confirm whether the change affects generic source code or private runtime
   configuration. Only generic source code belongs here.
4. Identify the relevant application stack and read its instructions in
   `AGENTS.md` and `.dev/agent_docs/`.

For security-sensitive findings, follow [SECURITY.md](SECURITY.md) instead of
opening a normal issue.

## Branches and Commits

Branch from `integration/customizations` and keep one concern per branch.

Use one of these prefixes:

- `feature/`
- `fix/`
- `docs/`
- `maintenance/`

Write concise, imperative commit subjects. Keep generated files with the
change that requires them, and avoid mixing formatting-only edits with
behavior changes.

Do not force-push shared branches, rewrite published history, or push directly
to the integration branch. Use a merge request and request human review.

## Implementation Expectations

- Follow existing Zammad patterns instead of introducing parallel frameworks.
- Preserve permissions, accessibility, translations, and existing workflows.
- Add focused automated coverage for new behavior and regressions.
- Keep setup scripts idempotent so a second run is safe.
- Document configuration, validation, failure behavior, and rollback.
- Keep environment-specific values out of defaults, fixtures, screenshots, and
  test output.

Markdown files are exempt from the source copyright header. Other new source
files must retain the project's established copyright header.

## Testing

Run the smallest useful set locally and record the exact commands and results
in the merge request. Examples:

```bash
RAILS_ENV=test VITE_TEST_MODE=1 bundle exec rspec spec/path/to/file_spec.rb
pnpm test --run app/frontend/path/to/file.spec.ts
bundle exec rubocop app/path/to/file.rb
```

For user-interface changes, also verify keyboard access, labels, focus,
attachment behavior where relevant, and the supported light/dark presentation.
For mail changes, test MIME content, recipients, headers, inline images,
attachments, duplicate delivery, and failure handling.

## Merge Request Checklist

A merge request should include:

- A linked issue or a clear reason for the change.
- A concise description of behavior before and after.
- The affected customization and files.
- Automated test commands and results.
- Manual verification steps when applicable.
- Security, privacy, accessibility, and upgrade considerations.
- Deployment prerequisites and a rollback approach.
- Screenshots only when they contain no private or operational data.

At least one other person should review application changes before merge.

## Deployment and Release Safety

Merging code does not authorize deployment. Promotion to a running system uses
the separate maintenance workflow and must include a verified backup,
non-production validation, source-drift checks, and post-deployment health
checks.

Do not commit or request:

- Passwords, tokens, cookies, private keys, certificates, or SSH material.
- Organization names, private domains, email addresses, hostnames, or IPs.
- User, customer, supplier, or ticket information.
- Database dumps, logs, backups, exported messages, or screenshots with data.
- Uploaded signatures, logos, icons, or other branded assets.
- Production configuration or private environment files.

If private data is accidentally committed, stop work and notify a maintainer;
deleting it in a later commit is not sufficient remediation.

## Upstream Updates

Application upgrades must be prepared against the exact release tag in a
dedicated branch. Review conflicts in every customized file, update the
customization catalog and runtime overlay manifest as needed, run focused and
upstream-relevant tests, and rehearse deployment on a clone before production.
