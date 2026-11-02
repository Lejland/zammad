# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Channel::Driver::ImapSentCopy do
  subject(:driver) { described_class.new }

  let(:imap)    { instance_double(Net::IMAP, append: nil, disconnect: nil) }
  let(:mail)    { Mail.new(to: 'customer@example.com', from: 'support@example.com', subject: 'Test', body: 'Message') }
  let(:options) { { host: 'imap.example.com', user: 'support@example.com', password: 'secret', folder: 'Sent Items' } }

  before do
    allow(driver).to receive(:setup_connection).with(options).and_return(imap) do
      driver.instance_variable_set(:@imap, imap)
    end
  end

  it 'appends the serialized message to the encoded folder and marks it as seen' do
    driver.append(options, mail)

    expect(imap).to have_received(:append).with(
      Net::IMAP.encode_utf7('Sent Items'),
      mail.encoded,
      [:Seen],
      mail.date,
    )
  end

  it 'disconnects when appending fails' do
    allow(imap).to receive(:append).and_raise(StandardError, 'APPEND failed')

    expect { driver.append(options, mail) }.to raise_error(StandardError, 'APPEND failed')
    expect(imap).to have_received(:disconnect)
  end
end
