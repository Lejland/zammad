# Deployment Customizations

This fork tracks generic changes made for a self-hosted Zammad deployment. It intentionally contains no organization-specific branding or operational data.

## Repository privacy rules

Never commit any of the following:

- Organization names, domains, email addresses, hostnames, or IP addresses.
- Employee, customer, or supplier names and identifiers.
- Logos, icons, signature artwork, or other branded assets.
- Credentials, access tokens, cookies, certificates, or private keys.
- Ticket content, exported messages, logs, database dumps, or backups.
- Production configuration files or screenshots.
- Uploaded HTML signatures or embedded signature images.

Use neutral examples such as `support@example.com` and deployment placeholders such as `<EMAIL_ACCOUNT_CHANNEL_ID>`.

## Tracked code customizations

### Copy SMTP deliveries to an IMAP Sent folder

Status: deployed and verified end to end in a test environment. Deployment configuration is intentionally not stored in Git.

The feature is configured per classic email account. After SMTP accepts a message, Zammad appends the same serialized MIME message to the configured IMAP folder and marks it as seen.

Properties:

- Reuses the account's existing inbound IMAP connection settings and credentials.
- Does not store a second password.
- Runs only for SMTP channels whose inbound adapter is IMAP.
- Runs only after SMTP delivery succeeds.
- Does not report the customer delivery as failed if IMAP filing fails.
- Logs IMAP filing failures for administrators.
- Defaults to the folder name `Sent` when no folder is specified.

Generic console configuration:

```ruby
channel = Channel.find(<EMAIL_ACCOUNT_CHANNEL_ID>)
channel.preferences[:imap_sent_copy] = {
  enabled: true,
  folder:  'Sent',
}
channel.save!
```

Disable without removing the configuration:

```ruby
channel = Channel.find(<EMAIL_ACCOUNT_CHANNEL_ID>)
channel.preferences[:imap_sent_copy][:enabled] = false
channel.save!
```

Verification:

1. Confirm the configured folder exists and accepts IMAP `APPEND`.
2. Send a ticket reply to a controlled test recipient.
3. Confirm the recipient receives exactly one message.
4. Confirm the same message appears once in the configured Sent folder.
5. Confirm its Message-ID, subject, recipients, MIME body, inline images, and attachments match.
6. Review Zammad logs for `storing sent email via imap` or an IMAP filing error.

Rollback:

1. Disable `imap_sent_copy` on the affected channel.
2. Revert the feature commit or restore the pre-deployment source files.
3. Restart Zammad services.
4. Send one controlled test reply and confirm normal SMTP delivery.

## Sanitized deployment change history

The following entries describe deployment state at a high level. Database values and private artifacts are deliberately not versioned.

### 2026-10-27 — Email presentation and migration workflow

- Preserved the ticket reference in outbound subjects.
- Adjusted replies so recipients retain the prior conversation context.
- Aligned helpdesk-generated reply presentation with normal mailbox replies.
- Added HTML signature import support with placeholders and inline image handling.
- Kept signature content and branded assets outside this repository.
- Narrowed customer acknowledgement behavior for a gradual migration from a shared mailbox workflow.

### 2026-10-27 — Access, groups, and roles

- Created a support workflow with separate administrative, agent, customer, knowledge-reader, knowledge-editor, and team-lead responsibilities.
- Kept a local emergency administrator with no mailbox or operational group assignment.
- Disabled unnecessary email notifications for the emergency account.
- Added generic user profile fields needed for future directory synchronization.
- Kept deployment-specific role names, users, addresses, and assignments outside this repository.

### 2026-10-28 — Knowledge base

- Enabled a public knowledge base.
- Prepared a public FAQ category; Zammad displays it publicly after it contains at least one published answer.
- Kept an internal knowledge category restricted to authenticated internal readers.
- Created a separate knowledge-editor responsibility.

### 2026-11-02 — Sent-folder integration

- Added per-channel IMAP Sent-copy behavior for successfully delivered SMTP ticket mail.
- Reused existing inbound IMAP credentials and kept folder selection in the database.
- Added unit coverage for enablement, credential reuse, append behavior, seen state, disconnect behavior, and non-fatal filing errors.
- Created a private pre-deployment rollback backup outside the repository.
- Deployed the generic runtime files and enabled the feature for the target test channel.
- Verified source syntax, application services, the local web endpoint, driver loading, and private runtime configuration.
- Verified a controlled SMTP delivery succeeded and exactly one matching Message-ID was present in the IMAP Sent folder.

### 2026-11-02 — Date and time presentation

- Changed the default English interface locale from US to UK formatting.
- Updated active users explicitly using US English to use UK English.
- Kept full timestamp display enabled.
- Preserved the configured timezone and all stored date and time values.
- Created a private pre-change settings backup outside the repository.

### 2026-11-03 — Ticket classification field visibility

- Restored agent visibility for the request classification and service category fields on ticket creation and editing screens.
- Kept both fields hidden from customer screens.
- Preserved the existing field definitions, selectable values, and stored ticket values.
- Ran the supported object-manager migration and verified application health.
- Created a private pre-change attribute backup outside the repository.

### 2026-11-03 — Original-email HTML download filenames

- Added the ticket number to filenames produced by the original-email HTML download action.
- Used the generic format `Ticket-<number>-message.html`.
- Kept ordinary HTML attachments and raw email downloads unchanged.
- Added focused request coverage for both renamed and unaffected downloads.
- Created a private pre-deployment rollback backup outside the repository.
- Verified the deployed filename logic against an existing original-email attachment and confirmed application health.

### 2026-11-04 — Dashboard ticket history

- Replaced the visible First Steps dashboard tab with Ticket history for users who can access the agent dashboard.
- Reused the existing permission-aware wildcard search while keeping the shared Dashboard search field visually empty.
- Kept the shared search field visible on both My Stats and Ticket history.
- Added Ticket and User result tabs with independent remote sorting and pagination in pages of 50 results.
- Sorted Tickets by newest creation date and Users by first name by default.
- Used the standard Ticket and User table columns.
- Kept My Stats available as the default dashboard tab.
- Opened the normal full search after a non-empty shared Dashboard query is confirmed.
- Kept the existing global search behavior unchanged.
- Removed only obsolete First Steps browser coverage; the underlying First Steps backend code remains present.
- Changed no ticket records or database schema.
- Created private pre-deployment source and compiled-asset rollback backups outside the repository.

### 2026-11-06 — HTML signature import and spacing

- Added HTML and HTM file selection to the existing signature administration form.
- Preserved supported inline formatting, placeholders, and embedded PNG, JPEG, GIF, and WebP images.
- Downloaded supported remote images server-side and passed them through Zammad's existing rich-text attachment handling.
- Rejected executable markup, unsupported image data, oversized sources, oversized images, and private or local image hosts by default.
- Allowed deployment-specific private image hosts only through the `ZAMMAD_SIGNATURE_HTML_IMPORT_ALLOWED_PRIVATE_HOSTS` environment variable.
- Stored the imported source and filename so administrators can reopen and replace an uploaded signature.
- Reduced composer-added signature separation by one line without modifying stored signature HTML.
- Kept uploaded signatures, filenames, image assets, private hostnames, and branding outside the repository.

### 2026-11-06 — Ticket composer attachment icon

- Kept the existing Enter Note hint in the composer.
- Replaced the visible select-attachment text with an accessible paperclip control in the left action rail.
- Reused the existing file input, upload cache endpoint, progress display, cancellation, drag-and-drop handling, attachment limits, and completion callbacks.
- Kept attachment availability tied to the selected article type.
- Added focused browser coverage for icon visibility, accessibility, upload behavior, and translated labels.

### 2026-11-10 — Ticket-related download filenames

- Added the ticket number prefix to files downloaded from ticket articles, including attachments, raw email files,
  and original-email HTML exports.
- Used the generic format `Ticket-<number>-<original-filename>` and avoided adding the same prefix twice.
- Kept downloads unrelated to ticket articles unchanged.
- Added focused request coverage for the shared download helper and ticket article endpoints.

### 2026-11-10 — Ownership request alert

- Added an idempotent setup script for a Request ownership macro and native action triggers.
- Notified agents with access to the ticket group only when an active ticket has no owner.
- Removed the temporary request tag after notification and cleared it without email when a ticket is already owned or
  inactive.
- Kept recipients, ticket state identifiers, and trigger records in the application database rather than source control.

Generic installation command:

```bash
zammad run rails runner script/custom/needs_owner_alert.rb
```

### 2026-11-10 — Browser-managed mixed-language spell-check

- Kept native browser spell-check enabled in each ticket composer.
- Removed the per-composer language selector after confirming that browser dictionaries provide the reliable
  mixed-language behavior.
- Kept spell-check language preferences in the user's browser; no language choice or text is sent to the server by
  this customization.
- Preserved the composer attachment layout and upload behavior.

### 2026-11-11 - SSO JIT provisioning and directory alignment

- Extended the existing SSO endpoint with an explicit trusted-proxy marker for
  just-in-time user provisioning.
- Matched existing users by normalized email or directory-style short login and
  created only previously unknown identities.
- Assigned new users the privately configured default role while preserving all
  roles on existing agents and administrators.
- Saved new and reconciled users in bulk-import context so account onboarding or
  verification email is not queued.
- Kept token validation, reverse-proxy rules, identity-provider endpoints, TLS,
  domains, role values, and directory credentials outside this repository.
- Did not add or configure an LDAP source. Native LDAP synchronization remains a
  separate optional deployment concern requiring encrypted transport, dedicated
  credentials, attribute mapping, and lifecycle review.
- Documented optional short `/signup` and `/login` entry points without storing
  their deployment-specific host or redirect configuration.
- Added focused service and request coverage for new-user creation, existing-user
  matching, role preservation, domain rejection, the provisioning marker, and
  notification suppression.

See [SSO JIT and Directory Integration](doc/customization/sso_jit_and_directory_integration.md).

## Upgrade procedure

1. Fetch the matching upstream Zammad release tag.
2. Rebase this feature branch onto that tag.
3. Resolve changes in the channel, SMTP, or IMAP drivers carefully.
4. Run focused tests and the upstream mail-channel test suite.
5. Back up the test deployment.
6. Deploy to the test system and complete the verification checklist.
7. Keep deployment-only configuration and private artifacts out of Git.
