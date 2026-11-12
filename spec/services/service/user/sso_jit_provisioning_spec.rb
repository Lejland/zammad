# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Service::User::SsoJitProvisioning, performs_jobs: true do
  subject(:service_result) { described_class.execute(login:, realname:) }

  let(:login)       { 'new.user@example.com' }
  let(:realname)    { 'New Example User' }
  let(:config_path) { Rails.root.join('tmp', "sso-jit-#{SecureRandom.hex(8)}.json") }
  let(:config) do
    {
      enabled:               true,
      email_domain:          'example.com',
      default_role:          'Customer',
      customer_role:         'Customer',
      source:                'sso',
      promote_customer_only: false,
    }
  end

  before do
    stub_const('Service::User::SsoJitProvisioning::CONFIG_PATH', config_path.to_s)
    config_path.write(JSON.generate(config))
  end

  after do
    config_path.delete if config_path.exist?
  end

  it 'creates a verified customer with a directory-aligned login', :aggregate_failures do
    expect { service_result }.not_to have_enqueued_job(NotificationMailerJob)

    expect(service_result).to have_attributes(
      login:     'new.user',
      email:     login,
      firstname: 'New',
      lastname:  'Example User',
      active:    true,
      verified:  true,
      source:    'sso',
    )
    expect(service_result.roles.map(&:name)).to contain_exactly('Customer')
  end

  it 'matches an existing customer by short login without changing roles', :aggregate_failures do
    existing_customer = create(:customer, login: 'new.user', email: '', verified: false)
    original_role_ids = existing_customer.role_ids.sort
    original_source = existing_customer.source

    expect(service_result).to eq(existing_customer)
    expect(service_result).to have_attributes(email: login, verified: true, source: original_source)
    expect(service_result.role_ids.sort).to eq(original_role_ids)
  end

  it 'preserves all roles on an existing administrator', :aggregate_failures do
    existing_admin = create(:admin, login: 'existing-admin', email: login)
    original_role_ids = existing_admin.role_ids.sort

    expect(service_result).to eq(existing_admin)
    expect(service_result.role_ids.sort).to eq(original_role_ids)
    expect(service_result.roles.map(&:name)).to include('Admin')
  end

  it 'rejects an identity outside the configured domain' do
    expect do
      described_class.execute(login: 'new.user@outside.example', realname:)
    end.to raise_error(Exceptions::Forbidden, 'SSO identity is not eligible for internal provisioning.')
  end

  it 'rejects provisioning when it is disabled' do
    config[:enabled] = false
    config_path.write(JSON.generate(config))

    expect { service_result }
      .to raise_error(Exceptions::Forbidden, 'SSO user provisioning is disabled.')
  end
end
