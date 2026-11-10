# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Idempotently installs a ticket macro and native triggers for requesting ownership.
# Run with:
#   zammad run rails runner script/custom/needs_owner_alert.rb

TAG_NAME = 'ownership-alert-requested'
MACRO_NAME = 'Request ownership'
NOTIFY_TRIGGER_NAME = 'Ownership request: notify group agents'
OWNED_CLEANUP_TRIGGER_NAME = 'Ownership request: clear on owned tickets'
INACTIVE_CLEANUP_TRIGGER_NAME = 'Ownership request: clear on inactive tickets'

system_user_id = 1
active_state_ids = Ticket::State.active.by_category(:open).pluck(:id).map(&:to_s)

raise 'No active ticket states were found.' if active_state_ids.blank?

macro = Macro.find_or_initialize_by(name: MACRO_NAME)
macro.assign_attributes(
  perform:         {
    'ticket.tags' => {
      'operator' => 'add',
      'value'    => TAG_NAME,
    },
  },
  ux_flow_next_up: 'none',
  note:            'Requests an ownership alert for an active ticket that currently has no owner.',
  group_ids:       [],
  active:          true,
  updated_by_id:   system_user_id,
)
macro.created_by_id ||= system_user_id
macro.save!

notify_trigger = Trigger.find_or_initialize_by(name: NOTIFY_TRIGGER_NAME)
notify_trigger.assign_attributes(
  condition:                {
    'ticket.tags'     => {
      'operator' => 'contains all',
      'value'    => TAG_NAME,
    },
    'ticket.owner_id' => {
      'operator'         => 'is',
      'pre_condition'    => 'not_set',
      'value'            => '',
      'value_completion' => '',
    },
    'ticket.state_id' => {
      'operator' => 'is any of',
      'value'    => active_state_ids,
    },
  },
  perform:                  {
    'notification.email' => {
      'body'                => %q(<p>This ticket currently has no owner and needs an agent to take ownership.</p>
<p><strong>#{ticket.title}</strong></p>
<p><a href="#{config.http_type}://#{config.fqdn}/#ticket/zoom/#{ticket.id}">Open the ticket in Zammad</a></p>),
      'recipient'           => ['ticket_agents'],
      'subject'             => %q(Ownership requested: #{ticket.title}),
      'internal'            => 'true',
      'include_attachments' => 'false',
    },
    'ticket.tags'        => {
      'operator' => 'remove',
      'value'    => TAG_NAME,
    },
  },
  activator:                'action',
  execution_condition_mode: 'selective',
  note:                     'Emails agents with full access when an active ticket has no owner.',
  active:                   true,
  updated_by_id:            system_user_id,
)
notify_trigger.created_by_id ||= system_user_id
notify_trigger.save!

owned_cleanup_trigger = Trigger.find_or_initialize_by(name: OWNED_CLEANUP_TRIGGER_NAME)
owned_cleanup_trigger.assign_attributes(
  condition:                {
    'ticket.tags'     => {
      'operator' => 'contains all',
      'value'    => TAG_NAME,
    },
    'ticket.owner_id' => {
      'operator'         => 'is not',
      'pre_condition'    => 'not_set',
      'value'            => '',
      'value_completion' => '',
    },
  },
  perform:                  {
    'ticket.tags' => {
      'operator' => 'remove',
      'value'    => TAG_NAME,
    },
  },
  activator:                'action',
  execution_condition_mode: 'selective',
  note:                     'Clears an ownership request without email when the ticket already has an owner.',
  active:                   true,
  updated_by_id:            system_user_id,
)
owned_cleanup_trigger.created_by_id ||= system_user_id
owned_cleanup_trigger.save!

inactive_cleanup_trigger = Trigger.find_or_initialize_by(name: INACTIVE_CLEANUP_TRIGGER_NAME)
inactive_cleanup_trigger.assign_attributes(
  condition:                {
    'ticket.tags'     => {
      'operator' => 'contains all',
      'value'    => TAG_NAME,
    },
    'ticket.state_id' => {
      'operator' => 'is none of',
      'value'    => active_state_ids,
    },
  },
  perform:                  {
    'ticket.tags' => {
      'operator' => 'remove',
      'value'    => TAG_NAME,
    },
  },
  activator:                'action',
  execution_condition_mode: 'selective',
  note:                     'Clears an ownership request without email for closed, merged, or inactive tickets.',
  active:                   true,
  updated_by_id:            system_user_id,
)
inactive_cleanup_trigger.created_by_id ||= system_user_id
inactive_cleanup_trigger.save!

puts({
  macro:    { id: macro.id, name: macro.name },
  triggers: [
    { id: notify_trigger.id, name: notify_trigger.name },
    { id: owned_cleanup_trigger.id, name: owned_cleanup_trigger.name },
    { id: inactive_cleanup_trigger.id, name: inactive_cleanup_trigger.name },
  ],
}.to_json)
