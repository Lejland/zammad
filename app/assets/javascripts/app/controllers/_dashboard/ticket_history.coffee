# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class App.DashboardTicketHistory extends App.Controller
  @ticketSearchColumns: [ 'number', 'title', 'customer', 'group', 'owner', 'created_at' ]
  @pageSize: 50

  elements:
    '.js-ticket-history-search': 'searchInput'

  events:
    'keyup .js-ticket-history-search': 'searchKeyup'
    'click .js-page': 'paginate'

  constructor: ->
    super

    @query = '*'
    @page = 0
    @totalCount = 0

    @globalSearch = new App.GlobalSearch(
      render: @renderResult
      limit: @constructor.pageSize
    )

    @render()
    @load()

  release: =>
    @globalSearch?.close()
    @table?.releaseController()

  render: ->
    @html App.view('dashboard/ticket_history')(
      query: @query
    )
    @$('.js-ticket-history-content').html App.view('generic/page_loading')()

  load: (force = false) =>
    @globalSearch.search(
      query:          @query
      object:         'Ticket'
      offset:         @page * @constructor.pageSize
      orderBy:        @orderBy
      orderDirection: @orderDirection
      delay:          -1
      force:          force
      callbackStart:  => @searchInput.addClass('loading')
      callbackStop:   => @searchInput.removeClass('loading')
    )

  renderResult: (result = {}) =>
    metadata = result.Ticket || {}
    items = metadata.items || []

    @totalCount = metadata.total_count || 0
    @renderCounter()
    @renderTickets(items)
    @renderPagination()

  renderCounter: ->
    @$('.js-ticket-history-counter').text(@totalCount)

  renderTickets: (items) ->
    @table?.releaseController()
    @table = undefined

    if _.isEmpty(items)
      @$('.js-ticket-history-content').html App.view('dashboard/ticket_history_empty')()
      return

    ticketIds = _.map(items, (item) -> item.id)

    @table = new App.TicketList(
      tableId:          'dashboard_ticket_history'
      el:               @$('.js-ticket-history-content')
      columns:          @constructor.ticketSearchColumns
      ticket_ids:       ticketIds
      checkbox:         false
      radio:            false
      orderBy:          @orderBy
      orderDirection:   @orderDirection
      sortClickCallback: @saveOrderBy
      pagerAjax:        true
    )

  renderPagination: ->
    pages = Math.ceil(@totalCount / @constructor.pageSize) - 1

    if (!pages && !@page) || @totalCount is 0
      @$('.js-ticket-history-pager').html('')
      return

    pager = App.view('generic/table_pager')(
      page:  @page
      pages: pages
    )

    @$('.js-ticket-history-pager').html(pager)

  paginate: (e) =>
    @preventDefaultAndStopPropagation(e)
    @page = parseInt($(e.currentTarget).attr('data-page'))
    @load(true)

  saveOrderBy: (table) =>
    return if !table

    @orderBy = table.orderBy
    @orderDirection = table.orderDirection
    @page = 0
    @load(true)

  searchKeyup: (e) =>
    if e.keyCode is 27
      @searchInput.val(@query)
      return

    return if e.keyCode isnt 13

    @preventDefaultAndStopPropagation(e)
    query = @searchInput.val().trim()
    return if !query

    @navigate "#search/#{encodeURIComponent(query)}"
