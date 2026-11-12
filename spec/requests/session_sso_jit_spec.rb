# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'SSO JIT provisioning', type: :request do
  before do
    Setting.set('auth_sso', true)
  end

  let(:user)  { create(:customer) }
  let(:login) { 'new.user@example.com' }

  it 'delegates a marked internal identity to the provisioning service' do
    realname = Base64.urlsafe_encode64('New Example User')
    allow(Service::User::SsoJitProvisioning).to receive(:execute).and_return(user)

    get '/auth/sso', headers: {
      'X-Forwarded-User'   => login,
      'X-SSO-Provision'    => 'internal',
      'X-SSO-Realname-B64' => realname,
    }

    expect(Service::User::SsoJitProvisioning)
      .to have_received(:execute)
      .with(login:, realname: 'New Example User')
    expect(response).to redirect_to('/#')
  end

  it 'keeps the standard existing-user lookup without the provisioning marker' do
    allow(Service::User::SsoJitProvisioning).to receive(:execute)

    get '/auth/sso', headers: { 'X-Forwarded-User' => user.login }

    expect(Service::User::SsoJitProvisioning).not_to have_received(:execute)
    expect(response).to redirect_to('/#')
  end
end
