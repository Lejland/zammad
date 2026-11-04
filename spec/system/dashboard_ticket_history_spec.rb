# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'Dashboard ticket history', authenticated_as: :authenticate, searchindex: true, type: :system do
  let(:group)          { create(:group) }
  let(:other_group)    { create(:group) }
  let(:agent)          { create(:agent, groups: [group]) }
  let!(:ticket)        { create(:ticket, title: 'Dashboard ticket history result', group: group) }
  let!(:hidden_ticket) { create(:ticket, title: 'Inaccessible dashboard ticket', group: other_group) }
  let!(:result_user)   { create(:customer, firstname: 'Dashboard', lastname: 'History User') }

  def authenticate
    ticket
    hidden_ticket
    result_user
    searchindex_model_reload([Ticket, User])
    agent
  end

  before do
    visit 'dashboard'
    find('.js-dashboard-tabs [data-area="ticket-history-widgets"]').click
  end

  it 'shows sortable Ticket and User results and switches back to My Stats' do
    expect(find('.js-dashboard-search-input').value).to eq('')

    within '.ticket-history-widgets' do
      expect(page).to have_css('.js-ticket-history-tab[data-tab-content="Ticket"].active')
      expect(page).to have_css('.js-ticket-history-tab[data-tab-content="User"]')
      expect(page).to have_link(ticket.number)
      expect(page).to have_text(ticket.title)
      expect(page).to have_no_text(hidden_ticket.title)

      find('[data-column-key="title"] .js-sort').click
      expect(page).to have_css('.table-sort-arrow')

      find('.js-ticket-history-tab[data-tab-content="User"]').click
      expect(page).to have_text(result_user.firstname)
      expect(page).to have_text(result_user.lastname)

      find('[data-column-key="login"] .js-sort').click
      expect(page).to have_css('.table-sort-arrow')
    end

    find('.js-dashboard-tabs [data-area="stat-widgets"]').click

    expect(page).to have_css('.stat-widgets:not(.hidden)')
    expect(page).to have_css('.ticket-history-widgets.hidden', visible: :all)
    expect(find('.js-dashboard-search-input').value).to eq('')
  end

  it 'opens the normal search after confirming a query' do
    field = find('.js-dashboard-search-input')
    expect(field.value).to eq('')
    field.set('printer issue')
    field.send_keys(:enter)

    expect(page).to have_current_path(%r{/#search/printer%20issue}, url: true)
  end
end
