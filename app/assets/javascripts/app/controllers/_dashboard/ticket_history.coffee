# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class App.DashboardTicketHistory extends App.Controller
  @ticketSearchColumns: [ 'number', 'title', 'customer', 'group', 'owner', 'created_at' ]
  @models: [ 'Ticket', 'User' ]
  @pageSize: 50

  events:
    'click .js-ticket-history-tab': 'showTab'
    'click .js-page': 'paginate'

  constructor: ->
    super

    @query = '*'
    @model = 'Ticket'
    @results = {}
    @states =
      Ticket:
        page:           0
        orderBy:        'created_at'
        orderDirection: 'DESC'
      User:
        page:           0
        orderBy:        'firstname'
        orderDirection: 'ASC'

    @globalSearch = new App.GlobalSearch(
      render: @renderResult
      limit: @constructor.pageSize
    )

    @render()
    @load(false, 'Ticket-User')

  release: =>
    @globalSearch?.close()
    @table?.releaseController()

  render: ->
    @html App.view('dashboard/ticket_history')()
    @renderLoading()

  load: (force = false, object = @model) =>
    state = @states[@model]

    @globalSearch.search(
      query:          @query
      object:         object
      offset:         state.page * @constructor.pageSize
      orderBy:        state.orderBy
      orderDirection: state.orderDirection
      delay:          -1
      force:          force
      callbackStart:  => @searchInput?.addClass('loading')
      callbackStop:   => @searchInput?.removeClass('loading')
    )

  renderResult: (result = {}, params = {}) =>
    requestedModels = (params.object || '').split('-')
    for model in requestedModels
      continue if !_.contains(@constructor.models, model)
      @results[model] = result[model] || { items: [], total_count: 0 }
      @renderCounter(model)

    @renderActive()

  renderCounter: (model) ->
    metadata = @results[model] || {}
    @$(".js-ticket-history-counter-#{model}").text(metadata.total_count || 0)

  renderActive: ->
    metadata = @results[@model]

    if !metadata?
      @renderLoading()
      return

    @renderTable(metadata.items || [])
    @renderPagination()

  renderLoading: ->
    @table?.releaseController()
    @table = undefined
    @$('.js-ticket-history-content').html App.view('generic/page_loading')()
    @$('.js-ticket-history-pager').html('')

  renderTable: (items) ->
    @table?.releaseController()
    @table = undefined

    if _.isEmpty(items)
      @$('.js-ticket-history-content').html App.view('dashboard/ticket_history_empty')()
      return

    if @model is 'Ticket'
      @renderTickets(items)
    else
      @renderUsers(items)

  renderTickets: (items) ->
    state = @states.Ticket
    ticketIds = _.map(items, (item) -> item.id)

    @table = new App.TicketList(
      tableId:          'dashboard_ticket_history'
      el:               @$('.js-ticket-history-content')
      columns:          @constructor.ticketSearchColumns
      ticket_ids:       ticketIds
      checkbox:         false
      radio:            false
      orderEnabled:     true
      orderBy:          state.orderBy
      orderDirection:   state.orderDirection
      sortClickCallback: @saveOrderBy
      pagerAjax:        true
    )

  renderUsers: (items) ->
    state = @states.User
    users = _.map(items, (item) -> App.User.fullLocal(item.id))

    openUser = (id) =>
      user = App.User.fullLocal(id)
      @navigate user.uiUrl()

    @table = new App.ControllerTable(
      tableId:          'dashboard_user_history'
      el:               @$('.js-ticket-history-content')
      model:            App.User
      objects:          users
      bindRow:
        events:
          'click': openUser
      orderBy:          state.orderBy
      orderDirection:   state.orderDirection
      sortClickCallback: @saveOrderBy
      pagerEnabled:     false
      orderEnabled:     true
      pagerAjax:        true
      clone:            false
      destroy:          false
    )

  showTab: (e) =>
    @preventDefaultAndStopPropagation(e)
    model = $(e.currentTarget).data('tab-content')
    return if !_.contains(@constructor.models, model)

    @$('.js-ticket-history-tab').removeClass('active')
    $(e.currentTarget).addClass('active')
    @model = model
    if @results[@model]?
      @renderActive()
    else
      @renderLoading()
      @load(true, @model)

  renderPagination: ->
    state = @states[@model]
    metadata = @results[@model] || {}
    totalCount = metadata.total_count || 0
    pages = Math.ceil(totalCount / @constructor.pageSize) - 1

    if (!pages && !state.page) || totalCount is 0
      @$('.js-ticket-history-pager').html('')
      return

    pager = App.view('generic/table_pager')(
      page:  state.page
      pages: pages
    )

    @$('.js-ticket-history-pager').html(pager)

  paginate: (e) =>
    @preventDefaultAndStopPropagation(e)
    state = @states[@model]
    state.page = parseInt($(e.currentTarget).attr('data-page'))
    @results[@model] = undefined
    @renderLoading()
    @load(true)

  saveOrderBy: (table) =>
    return if !table

    state = @states[@model]
    state.orderBy = table.orderBy
    state.orderDirection = table.orderDirection
    state.page = 0
    @load(true)

  searchKeyup: (e) =>
    if e.keyCode is 27
      @searchInput.val('')
      return

    return if e.keyCode isnt 13

    @preventDefaultAndStopPropagation(e)
    query = @searchInput.val().trim()
    return if !query

    @navigate "#search/#{encodeURIComponent(query)}"
