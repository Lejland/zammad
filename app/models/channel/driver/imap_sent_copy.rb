# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Channel::Driver::ImapSentCopy < Channel::Driver::Imap
  def append(options, mail)
    folder = options[:folder].presence || 'Sent'

    setup_connection(options.merge(folder: folder))

    Timeout.timeout(self.class::DEFAULT_TIMEOUT) do
      @imap.append(
        Net::IMAP.encode_utf7(folder),
        mail.encoded,
        [:Seen],
        mail.date || Time.zone.now,
      )
    end
  ensure
    disconnect
  end

  private

  def setup_connection_server_log(server_settings)
    settings = [
      "#{server_settings[:user]}/#{server_settings[:host]} port=#{server_settings[:port]}",
      "ssl=#{server_settings[:ssl_or_starttls] == :ssl}",
      "starttls=#{server_settings[:ssl_or_starttls] == :starttls}",
      "folder=#{server_settings[:folder]}",
      "auth_type=#{server_settings.fetch(:auth_type, 'LOGIN')}",
      "ssl_verify=#{server_settings[:ssl_verify]}"
    ]

    Rails.logger.info "storing sent email via imap (#{settings.join(',')})"
  end
end
