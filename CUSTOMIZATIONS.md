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

Status: deployed to a test environment after isolated runtime and health checks; controlled delivery verification is pending. Deployment configuration is intentionally not stored in Git.

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

## Upgrade procedure

1. Fetch the matching upstream Zammad release tag.
2. Rebase this feature branch onto that tag.
3. Resolve changes in the channel, SMTP, or IMAP drivers carefully.
4. Run focused tests and the upstream mail-channel test suite.
5. Back up the test deployment.
6. Deploy to the test system and complete the verification checklist.
7. Keep deployment-only configuration and private artifacts out of Git.
