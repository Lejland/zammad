# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module ApplicationController::HasDownload
  extend ActiveSupport::Concern

  def send_data(...)
    super
    set_null_csp
    set_no_sniff
  end

  def send_file(...)
    super
    set_null_csp
    set_no_sniff
  end

  private

  def file_id
    @file_id ||= params[:id]
  end

  def download_file
    @download_file ||= ::ApplicationController::HasDownload::DownloadFile.new(file_id, disposition: sanitized_disposition)
  end

  def sanitized_disposition
    disposition = params.fetch(:disposition, 'inline')
    valid_disposition = %w[inline attachment]
    return disposition if valid_disposition.include?(disposition)

    raise Exceptions::Forbidden, "Invalid disposition #{disposition} requested. Only #{valid_disposition.join(', ')} are valid."
  end

  def ticket_download_filename(ticket = nil, filename = download_file.filename)
    return filename if ticket.blank?

    prefix = "Ticket-#{ticket.number}-"
    return filename if filename.start_with?(prefix)

    "#{prefix}#{filename}"
  end

  def ticket_for_download
    return if download_file.store_object&.name != 'Ticket::Article'

    article = Ticket::Article.find_by(id: download_file.o_id)
    return if article.blank?

    article.ticket
  end

  def set_null_csp
    request.content_security_policy = ActionDispatch::ContentSecurityPolicy.new.tap { |p| p.default_src :none }
  end

  # Ask the browser to honor the sent content type instead of MIME-sniffing it.
  def set_no_sniff
    response.set_header('X-Content-Type-Options', 'nosniff')
  end
end
