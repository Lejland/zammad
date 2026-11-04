# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'Dashboard ticket history', authenticated_as: :authenticate, searchindex: true, type: :system do
  let(:group)          { create(:group) }
  let(:other_group)    { create(:group) }
  let(:agent)          { create(:agent, groups: [group]) }
  let!(:ticket)        { create(:ticket, title: 'Dashboard ticket history result', group: group) }
  let!(:hidden_ticket) { create(:ticket, title: 'Inaccessible dashboard ticket', group: other_group) }

  def authenticate
    ticket
    hidden_ticket
    searchindex_model_reload([Ticket])
    agent
  end

  before do
    visit 'dashboard'
    find('.js-dashboard-tabs [data-area="ticket-history-widgets"]').click
  end

  it 'shows accessible tickets and switches back to My Stats' do
    within '.ticket-history-widgets' do
      expect(page).to have_link(ticket.number)
      expect(page).to have_text(ticket.title)
      expect(page).to have_no_text(hidden_ticket.title)
    end

    find('.js-dashboard-tabs [data-area="stat-widgets"]').click

    expect(page).to have_css('.stat-widgets:not(.hidden)')
    expect(page).to have_css('.ticket-history-widgets.hidden', visible: :all)
  end

  it 'opens the normal search after confirming a query' do
    within '.ticket-history-widgets' do
      field = find('.js-ticket-history-search')
      field.set('printer issue')
      field.send_keys(:enter)
    end

    expect(page).to have_current_path(%r{/#search/printer%20issue}, url: true)
  end
end
