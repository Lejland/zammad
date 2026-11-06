# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe SignatureHtmlImport do
  describe SignatureHtmlImport::Converter do
    subject(:converted) { described_class.new(source).call }

    let(:png_data) do
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
    end

    context 'with safe signature HTML' do
      let(:source) do
        <<~HTML
          <!doctype html>
          <html>
            <body>
              <div>\#{user.firstname} \#{user.lastname}</div>
              <img src="data:image/png;base64,#{png_data}">
            </body>
          </html>
        HTML
      end

      it 'preserves placeholders and supported embedded images' do
        expect(converted).to include('#{user.firstname} #{user.lastname}')
        expect(converted).to include("data:image/png;base64,#{png_data}")
      end
    end

    context 'with a private image host' do
      let(:source) { '<html><body><img src="https://127.0.0.1/image.png"></body></html>' }

      it 'rejects the image URL' do
        expect { converted }.to raise_error(described_class::ImportError, /private or local image hosts/)
      end
    end

    context 'with an oversized source' do
      let(:source) { "<html><body>#{'x' * (described_class::MAX_SOURCE_SIZE + 1)}</body></html>" }

      it 'rejects the source' do
        expect { converted }.to raise_error(described_class::ImportError, /larger than 10 MB/)
      end
    end
  end

  describe 'signature model integration' do
    it 'stores the source metadata and imports its body' do
      signature = create(
        :signature,
        source_filename: 'signature.html',
        source_body:     '<html><body><p>#{user.firstname}</p></body></html>',
      )

      expect(signature.source_filename).to eq('signature.html')
      expect(signature.source_body).to include('#{user.firstname}')
      expect(signature.body).to include('#{user.firstname}')
    end
  end
end
