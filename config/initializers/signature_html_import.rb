# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Local Zammad extension: convert uploaded HTML signature sources into rich text
# before Zammad's normal sanitizer runs. Remote images are downloaded from
# public HTTPS hosts and converted to data URIs; HasRichText then stores them as
# CID attachments belonging to the signature.

require 'base64'
require 'ipaddr'
require 'net/http'
require 'resolv'
require 'uri'

# These are presentation-only properties used by trusted, administrator-owned
# signatures. They let inline signature rules override Zammad's generic
# outgoing-email table CSS without enabling positioning or executable CSS.
SAFE_SIGNATURE_STYLE_EXTENSIONS = {
  'table' => %w[display font-family line-height table-layout],
  'td'    => %w[font-family line-height],
  'img'   => %w[border display margin-bottom],
  'a'     => %w[color text-decoration],
}.freeze

SAFE_SIGNATURE_STYLE_EXTENSIONS.each do |tag, properties|
  Rails.application.config.html_sanitizer_css_properties_allowlist[tag] ||= []
  Rails.application.config.html_sanitizer_css_properties_allowlist[tag] |= properties
end

Rails.application.config.html_sanitizer_attributes_allowlist['a'] |= %w[style]

module SignatureHtmlImport
  MAX_SOURCE_SIZE      = 10.megabytes
  MAX_IMAGE_SIZE       = 2.megabytes
  MAX_TOTAL_IMAGE_SIZE = 8.megabytes
  MAX_REDIRECTS        = 3
  ALLOWED_PRIVATE_IMAGE_HOSTS = ENV
    .fetch('ZAMMAD_SIGNATURE_HTML_IMPORT_ALLOWED_PRIVATE_HOSTS', '')
    .split(/[,\s]+/)
    .map(&:downcase)
    .reject(&:blank?)
    .uniq.freeze

  IMAGE_TYPES = {
    "\x89PNG\r\n\x1A\n".b => 'image/png',
    "\xFF\xD8\xFF".b       => 'image/jpeg',
    'GIF87a'.b               => 'image/gif',
    'GIF89a'.b               => 'image/gif',
  }.freeze

  BLOCKED_NETWORKS = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
    172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16
    198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8 2001:db8::/32
  ].map { |network| IPAddr.new(network) }.freeze

  class ImportError < StandardError; end

  class Converter
    def initialize(source)
      @source = source.to_s
      @downloaded_bytes = 0
    end

    def call
      raise ImportError, 'The HTML source is larger than 10 MB.' if @source.bytesize > MAX_SOURCE_SIZE

      document = Nokogiri::HTML5.parse(@source)
      body = document.at_css('body')
      raise ImportError, 'The HTML source has no usable body.' if body.nil?

      body.css('img').each { |image| embed_image(image) }
      body.inner_html
    rescue Nokogiri::XML::SyntaxError => e
      raise ImportError, "The HTML could not be parsed: #{e.message}"
    end

    private

    def embed_image(image)
      source = image['src'].to_s.strip
      return if source.match?(%r{\Adata:image/(?:png|gif|jpe?g|webp);base64,}i)

      uri = parse_remote_uri(source)
      data, mime_type = download(uri)
      @downloaded_bytes += data.bytesize
      raise ImportError, 'The combined image size is larger than 8 MB.' if @downloaded_bytes > MAX_TOTAL_IMAGE_SIZE

      image['src'] = "data:#{mime_type};base64,#{Base64.strict_encode64(data)}"
      image.remove_attribute('srcset')
    rescue ImportError => e
      raise ImportError, "Image #{source.inspect} could not be imported: #{e.message}"
    end

    def parse_remote_uri(source)
      uri = URI.parse(source)
      raise ImportError, 'only absolute HTTP or HTTPS image URLs are supported.' if !uri.is_a?(URI::HTTP) || uri.host.blank?

      uri.scheme = 'https' if uri.scheme == 'http'
      uri
    rescue URI::InvalidURIError
      raise ImportError, 'the image URL is invalid.'
    end

    def download(uri, redirects_left = MAX_REDIRECTS)
      validate_public_host!(uri.host)

      response = request(uri)
      if response.is_a?(Net::HTTPRedirection)
        raise ImportError, 'too many redirects.' if redirects_left.zero?

        redirected = URI.join(uri, response.fetch('location'))
        raise ImportError, 'an image redirect changed to an unsupported protocol.' if redirected.scheme != 'https'

        return download(redirected, redirects_left - 1)
      end

      raise ImportError, "the image server returned HTTP #{response.code}." if !response.is_a?(Net::HTTPSuccess)

      data = response.body.to_s.b
      raise ImportError, 'the image is empty.' if data.empty?
      raise ImportError, 'the image is larger than 2 MB.' if data.bytesize > MAX_IMAGE_SIZE

      mime_type = detect_image_type(data)
      raise ImportError, 'the response is not a supported PNG, JPEG, GIF, or WebP image.' if mime_type.nil?

      [data, mime_type]
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise ImportError, e.message
    end

    def request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      http.max_retries = 0

      request = Net::HTTP::Get.new(uri.request_uri)
      request['User-Agent'] = 'Zammad Signature HTML Import'
      request['Accept'] = 'image/png,image/jpeg,image/gif,image/webp'

      http.request(request)
    end

    def validate_public_host!(host)
      return if ALLOWED_PRIVATE_IMAGE_HOSTS.include?(host.downcase)

      addresses = Resolv.getaddresses(host)
      raise ImportError, 'the image host could not be resolved.' if addresses.empty?

      addresses.each do |address|
        ip = IPAddr.new(address)
        raise ImportError, 'private or local image hosts are not allowed.' if BLOCKED_NETWORKS.any? { |network| network.include?(ip) }
      end
    rescue IPAddr::InvalidAddressError
      raise ImportError, 'the image host resolved to an invalid address.'
    end

    def detect_image_type(data)
      IMAGE_TYPES.each do |signature, mime_type|
        return mime_type if data.start_with?(signature)
      end

      return 'image/webp' if data.bytesize >= 12 && data.start_with?('RIFF') && data.byteslice(8, 4) == 'WEBP'

      nil
    end
  end

  module ModelExtension
    private

    def import_uploaded_html_source
      return if source_body.blank?

      remote_image_submitted = body.to_s.match?(%r{<img\b[^>]*\bsrc=["']https?://}i)
      return if !new_record? && !will_save_change_to_source_body? && !remote_image_submitted

      self.body = SignatureHtmlImport::Converter.new(source_body).call
    rescue SignatureHtmlImport::ImportError => e
      errors.add(:source_body, e.message)
      throw :abort
    end
  end
end

Rails.application.config.to_prepare do
  Signature.include(SignatureHtmlImport::ModelExtension) if !Signature.include?(SignatureHtmlImport::ModelExtension)

  callback_exists = Signature._validation_callbacks.any? do |callback|
    callback.filter == :import_uploaded_html_source
  end

  Signature.before_validation(:import_uploaded_html_source, prepend: true) if !callback_exists
end
