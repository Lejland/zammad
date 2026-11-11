# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Service::User::SsoJitProvisioning
  CONFIG_PATH = '/etc/zammad-sso/provisioning.json'.freeze
  LOGIN_LOCALPART_PATTERN = /\A[A-Za-z0-9._-]{1,128}\z/

  def self.execute(...)
    new(...).execute
  end

  def initialize(login:, realname: nil)
    @login = login.to_s.strip.downcase
    @realname = realname.to_s.strip
  end

  def execute
    config = load_config
    raise Exceptions::Forbidden, 'SSO user provisioning is disabled.' if config['enabled'] != true

    validate_login!(config)

    user = identify_user
    return update_existing(user, config) if user.present?

    create_user(config)
  rescue ActiveRecord::RecordNotUnique
    user = identify_user
    raise if user.blank?

    update_existing(user, config)
  end

  private

  def load_config
    JSON.parse(File.read(CONFIG_PATH))
  rescue Errno::ENOENT, JSON::ParserError => e
    Rails.logger.error("SSO JIT provisioning configuration error: #{e.class}")
    raise Exceptions::Forbidden, 'SSO user provisioning is unavailable.'
  end

  def validate_login!(config)
    domain = config.fetch('email_domain').to_s.strip.downcase
    localpart, separator, login_domain = @login.rpartition('@')

    return if separator == '@' && login_domain == domain && LOGIN_LOCALPART_PATTERN.match?(localpart)

    raise Exceptions::Forbidden, 'SSO identity is not eligible for internal provisioning.'
  end

  def update_existing(user, config)
    attributes = {}
    attributes[:verified] = true if !user.verified
    attributes[:email] = @login if user.email.blank?

    customer_role = Role.lookup(name: config.fetch('customer_role'))
    default_role = Role.lookup(name: config.fetch('default_role'))
    ensure_roles_exist!(customer_role, default_role)

    customer_only = user.roles.one? && user.roles.first.id == customer_role.id
    if config.fetch('promote_customer_only', true) && customer_only
      attributes[:role_ids] = [default_role.id]
      attributes[:source] = config.fetch('source', 'sso') if user.source.blank? || user.source == 'signup'
    end

    save_without_notifications(user, attributes) if attributes.present?
    user
  end

  def create_user(config)
    default_role = Role.lookup(name: config.fetch('default_role'))
    raise Exceptions::Forbidden, 'SSO provisioning role is unavailable.' if default_role.blank?

    firstname, lastname = split_realname
    user = User.new(
      login:         login_localpart,
      email:         @login,
      firstname:     firstname,
      lastname:      lastname,
      active:        true,
      verified:      true,
      source:        config.fetch('source', 'sso'),
      role_ids:      [default_role.id],
      created_by_id: 1,
      updated_by_id: 1,
    )

    save_without_notifications(user)
    user
  end

  def split_realname
    value = @realname.gsub(/[[:cntrl:]]/, '').squish.first(256)
    return [@login.split('@', 2).first, '-'] if value.blank?

    firstname, lastname = value.split(/\s+/, 2)
    [firstname, lastname.presence || '-']
  end

  def identify_user
    User.identify(@login) || User.identify(login_localpart)
  end

  def login_localpart
    @login.split('@', 2).first
  end

  def ensure_roles_exist!(*roles)
    return if roles.all?(&:present?)

    raise Exceptions::Forbidden, 'SSO provisioning roles are unavailable.'
  end

  def save_without_notifications(user, attributes = {})
    previous_bulk_import_state = BulkImportInfo.enabled?
    BulkImportInfo.enable
    user.assign_attributes(attributes)
    user.save!
  ensure
    previous_bulk_import_state ? BulkImportInfo.enable : BulkImportInfo.disable
  end
end
