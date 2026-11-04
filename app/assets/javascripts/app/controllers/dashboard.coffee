class App.Dashboard extends App.Controller
  clueAccess: true
  events:
    'click .js-dashboard-tabs .tab': 'toggle'
    'click .js-intro': 'clues'
    'keyup .js-dashboard-search-input': 'searchKeyup'

  constructor: ->
    super

    if !@permissionCheck('ticket.agent')
      @clueAccess = false
      return

    # render page
    @render()

    # rerender view, e. g. on language change
    @controllerBind('ui:rerender', =>
      return if !@authenticateCheck()
      @render()
    )

    @mayBeClues()

  render: ->

    localEl = $( App.view('dashboard')(
      head:    __('Dashboard')
      isAdmin: @permissionCheck('admin')
    ) )

    new App.DashboardStats(
      el: localEl.find('.stat-widgets')
    )

    new App.DashboardActivityStream(
      el:    localEl.find('.js-activityContent')
      limit: 25
    )

    @ticketHistoryController?.release()
    @ticketHistoryController?.releaseController()
    @ticketHistoryController = new App.DashboardTicketHistory(
      el:          localEl.find('.ticket-history-widgets')
      searchInput: localEl.find('.js-dashboard-search-input')
    )

    @html localEl

  mayBeClues: =>
    return if @Config.get('after_auth')
    return if !@clueAccess
    return if !@shown
    return if @Config.get('switch_back_to_possible')
    preferences = @Session.get('preferences')
    @clueAccess = false

    # If the initial clue has been already completed by the user, show the rest of the clues.
    if preferences['intro']
      for clue in _.sortBy(App.Config.get('Clues'), 'prio')
        continue if preferences[clue.preference_key] # skip already completed clues
        continue if clue.config_key and not App.Config.get(clue.config_key) # skip clues about inactive features
        continue if clue.permission and not _.every(clue.permission, (permission) -> App.User.current()?.permission(permission)) # skip clues without required permissions

        new clue.controller(
          appEl: @appEl
          onComplete: =>
            App.Ajax.request(
              id:          'preferences'
              type:        'PUT'
              url:         "#{@apiPath}/users/preferences"
              data:        JSON.stringify("#{clue.preference_key}": true)
              processData: true
            )
        )

        return # show only one clue at a time

      return

    @clues()

  clues: (e) =>
    @clueAccess = false
    if e
      e.preventDefault()

    # Initial clue has its own controller, so it can be triggered via a route change later.
    @navigate '#clues'

  active: (state) =>
    return @shown if state is undefined
    @shown = state
    if state
      @mayBeClues()

  url: ->
    '#dashboard'

  show: (params) =>
    if @permissionCheck('ticket.agent')
      @title __('Dashboard')
      @navupdate '#dashboard'
    # in case of being only customer, redirect to default router
    else if @permissionCheck('ticket.customer')
      @navigate '#ticket/view', { hideCurrentLocationFromHistory: true }
    # in case of being only admin, redirect to admin interface (show no empty white content page)
    else if @permissionCheck('admin')
      @navigate '#manage', { hideCurrentLocationFromHistory: true }
    # fallback for user who is neither admin nor customer
    else
      @navigate '#welcome', { hideCurrentLocationFromHistory: true }

  changed: ->
    false

  toggle: (e) =>
    @$('.js-dashboard-tabs .tab').removeClass('active')
    $(e.currentTarget).addClass('active')
    target = $(e.currentTarget).data('area')
    @$('.tab-content').addClass('hidden')
    @$(".tab-content.#{target}").removeClass('hidden')

    if target is 'ticket-history-widgets'
      @ticketHistoryController?.load(true)

  searchKeyup: (e) =>
    @ticketHistoryController?.searchKeyup(e)

class DashboardRouter extends App.ControllerPermanent
  @requiredPermission: ['*']

  constructor: (params) ->
    super

    # check authentication
    @authenticateCheckRedirect()

    App.TaskManager.execute(
      key:        'Dashboard'
      controller: 'Dashboard'
      params:     {}
      show:       true
      persistent: true
    )

App.Config.set('dashboard', DashboardRouter, 'Routes')
App.Config.set('Dashboard', { controller: 'Dashboard', permission: ['*'] }, 'permanentTask')
App.Config.set('Dashboard', { prio: 100, parent: '', name: __('Dashboard'), target: '#dashboard', key: 'Dashboard', permission: ['ticket.agent'], class: 'dashboard' }, 'NavBar')
