# Development Workflow

## Project Boundary

Issues, branches, reviews, and merge requests are managed in this project.
`integration/customizations` is the customization baseline. Do not configure
repository mirroring or add a second code-host remote to this checkout.

Application code and generic setup scripts belong in Git. Runtime credentials,
environment-specific settings, operational data, backups, and branding do not.

## Before the Lifecycle: Define the Work

An issue should explain the problem, expected behavior, acceptance criteria,
and relevant constraints before implementation begins. Large changes should be
split into independently testable tasks. Bugs may enter the lifecycle directly
when reproduction steps and expected behavior are clear.

The shared planning and review rules are in
`.dev/agent_docs/story_planning_rules.md` and
`.dev/agent_docs/code_review_rules.md`.

## Lifecycle

### 1. Understand

Read the issue thoroughly before writing code. Clarify ambiguous scope,
acceptance criteria, permissions, privacy, accessibility, deployment impact,
and edge cases.

Identify which stack is affected: CoffeeScript frontend, Vue 3 frontend, REST,
GraphQL, Rails services, mail processing, or deployment tooling. State the
scope explicitly and avoid unrelated exploration.

### 2. Research

Inspect existing patterns in the affected area and read the relevant reference
file from `AGENTS.md`. Check `CUSTOMIZATIONS.md` and recent history for overlap
with existing custom behavior.

If research changes the scope, update the issue or tell the user before
continuing.

### 3. Plan

List the affected files, tests, migration or asset-build needs, risks, and
rollback approach. Present a plan before non-trivial implementation.

### 4. Branch

Create a branch from the current `integration/customizations` baseline:

- `feature/<short-description>`
- `fix/<short-description>`
- `docs/<short-description>`
- `maintenance/<short-description>`

Do not make customization changes on the bootstrap `main` branch. Do not
rewrite or force-push shared history.

### 5. Implement

Follow existing application patterns and keep the change focused. Preserve
authorization, translations, accessibility, and unchanged workflows. New
non-Markdown source files require the established copyright header.

Generic setup scripts must be idempotent. Do not hard-code private values.

### 6. Test

Run the smallest relevant automated tests and add coverage for new behavior or
regressions. Record exact commands and results. Do not use production as the
first test environment.

### 7. Review

Review the complete diff for correctness, security, privacy, accessibility,
upgrade conflicts, and unintended generated files. Resolve findings and rerun
affected tests before committing.

### 8. Commit

Use a concise imperative subject that describes the actual change. Keep each
commit coherent and avoid private issue numbers, hostnames, addresses, or
operational values in commit messages.

### 9. Merge Request

Push only after the user or maintainer authorizes it. Open a merge request in
this project using the appropriate template. Include test evidence, manual
verification, deployment impact, and rollback guidance. Human review is
required before merge.

### 10. Deploy

A merge is not deployment authorization. Promote the reviewed integration
commit through the separate maintenance workflow: verified backup,
non-production validation, source-drift check, controlled deployment, and
post-deployment health and functional checks.

## Rules

- Do not push directly to `integration/customizations` during normal feature
  work.
- Never push to an upstream project repository.
- Never configure automatic repository mirroring.
- Never commit secrets, private configuration, branded assets, ticket data,
  logs, database dumps, or backups.
- Never run broad destructive commands against a deployment.
- Keep package updates and application upgrades separate from feature work.
