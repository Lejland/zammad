# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddUploadedSourceToSignatures < ActiveRecord::Migration[7.2]
  def change
    add_column :signatures, :source_filename, :string, limit: 255, null: true
    add_column :signatures, :source_body, :text, limit: 10.megabytes + 1, null: true
  end
end
