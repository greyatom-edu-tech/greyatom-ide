localStorage = require './local-storage'
{CompositeDisposable, Notification} = require 'atom'
Terminal = require './terminal'
TerminalView = require './views/terminal'
StatusView = require './views/status'
{EventEmitter} = require 'events'
Updater = require './updater'
ProjectSearch = require './project-search'
bus = require('./event-bus')()
Notifier = require './notifier'
atomHelper = require './atom-helper'
startInstance = require './instance'
auth = require './auth'
loginWithGithub = require('./auth').loginWithGithub
remote = require 'remote'
BrowserWindow = remote.BrowserWindow
localStorage = require './local-storage'
{$} = require 'atom-space-pen-views'

toolBar = null;

module.exports =
  token: require('./token')

  activate: (state) ->
    @checkForV1WindowsInstall()
    @registerWindowsProtocol()

    @subscriptions = new CompositeDisposable
    @subscribeToLogin()
    # atom.config.set('tool-bar.visible', false)

    atom.project.commitLiveIde = activateIde: =>
      @activateIDE(state)

    @authenticateUser()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'commit-live:toggle-dashboard': () =>
        @showDashboard()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'commit-live:login-with-github': () =>
        loginWithGithub()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'commit-live:connect-to-project': () =>
        atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:hide')
        preReqPopup = new Notification("info", "Fetching Prerequisites...", {dismissable: true})
        atom.notifications.addNotification(preReqPopup)
        auth().then =>
          preReqPopup.dismiss()
          setTimeout =>
            @studentServer = JSON.parse(localStorage.get('commit-live:user-info')).servers.student
            serverStatus = JSON.parse(localStorage.get('commit-live:user-info')).serverStatus
            if serverStatus == 2
              spinUpPopup = new Notification("info", "Spining up your server...", {dismissable: true})
              atom.notifications.addNotification(spinUpPopup)
              startInstance().then =>
                spinUpPopup.dismiss()
                atom.notifications.addSuccess 'Your server is ready now!'
                setTimeout =>
                  @studentServer = JSON.parse(localStorage.get('commit-live:user-info')).servers.student
                  @connectToFileTreeInFiveSeconds()
                , 0
              .catch =>
                spinUpPopup.dismiss()
                @showSessionExpired()
                @logout()
            else
              if atom.project and atom.project.remoteftp
                if atom.project.remoteftp.isConnected()
                  @showCodingScreen()
                else
                  atom.project.remoteftp.connectToStudentFTP()
          , 0
        .catch =>
          preReqPopup.dismiss()
          @showSessionExpired()
          @logout()

    @projectSearch = new ProjectSearch()
    @activateUpdater()

  showDashboard: () ->
    dashboardView = $('.commit-live-settings-view')
    if !dashboardView.length
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:show-dashboard')
      if atom.project.remoteftp.isConnected()
        atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-tree-view:toggle')
        atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live:toggle-terminal')

  showCodingScreen: () ->
    treeView = $('.greyatom-tree-view-view')
    terminalView = $('.commit-live-terminal-view')
    atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-tree-view:toggle') if !treeView.length
    if terminalView.length && terminalView.is(':hidden')
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live:toggle-terminal')

  showSessionExpired: () ->
    sessionExpiredNotify = new Notification("info", "Commit Live IDE: Please Login Again", {
      dismissable: false,
      description: 'Your session has expired!'
    });
    atom.notifications.addNotification(sessionExpiredNotify)

  connectToFileTreeInFiveSeconds: () ->
    waitTime = 10 # seconds
    launchPopup = null
    intervalVar = setInterval ->
      if launchPopup
        launchPopup.dismiss()
        launchPopup = null
      if waitTime == 0
        if atom.project and atom.project.remoteftp
          atom.project.remoteftp.connectToStudentFTP()
        clearInterval(intervalVar)
        return
      launchPopup = new Notification("info", "Connecting in #{waitTime}...", {dismissable: true})
      atom.notifications.addNotification(launchPopup)
      waitTime = waitTime - 1
    , 1000

  authenticateUser: () ->
    authPopup = new Notification("info", "Commit Live IDE: Authenticating...", {dismissable: true})
    atom.notifications.addNotification(authPopup)
    @waitForAuth = auth().then =>
      authPopup.dismiss()
      setTimeout ->
        atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:show-dashboard')
        atom.notifications.addSuccess 'Commit Live IDE: You have successfully logged in.'
      , 0
    .catch =>
      authPopup.dismiss()
      @logout()

  activateIDE: (state) ->
    @isTerminalWindow = (localStorage.get('popoutTerminal') == 'true')
    if @isTerminalWindow
      window.resizeTo(750, 500)
      localStorage.delete('popoutTerminal')

    @isRestartAfterUpdate = (localStorage.get('restartingForUpdate') == 'true')
    if @isRestartAfterUpdate
      Updater.didRestartAfterUpdate()
      localStorage.delete('restartingForUpdate')

    @activateTerminal()
    @activateStatusView(state)
    @activateEventHandlers()
    @activateSubscriptions()
    @activateNotifier()
    # @termView.sendClear()

  activateTerminal: ->
    @term = new Terminal
      host: @studentServer.host
      port: @studentServer.port
      path: @studentServer.terminal_path
      id: @token.getID()
      token: @token.get()

    @termView = new TerminalView(@term, null, @isTerminalWindow)
    @termView.toggle()

  activateStatusView: (state) ->
    @statusView = new StatusView state, @term, {@isTerminalWindow}

    @addStatusBar(item: @statusView, priority: 5000)
    bus.on 'terminal:popin', () =>
      @statusView.onTerminalPopIn()
      @termView.showAndFocus()

    @statusView.on 'terminal:popout', =>
      @termView.toggle()

  activateEventHandlers: ->
    atomHelper.trackFocusedWindow()

    # listen for commit-live:open event from other render processes (url handler)
    bus.on 'commit-live:open', (lab) =>
      console.log "inside bus.on " , lab.slug
      @termView.openLab(lab.slug)
      atom.getCurrentWindow().focus()

    # tidy up when the window closes
    atom.getCurrentWindow().on 'close', =>
      @cleanup()
      if @isTerminalWindow
        bus.emit('terminal:popin', Date.now())

  activateSubscriptions: ->
    @subscriptions.add atom.commands.add 'atom-workspace',
      'commit-live:open': (e) => @termView.openLab(e.detail.path)
      'commit-live:toggle-terminal': () => @termView.toggle()
      'commit-live:toggle-focus': => @termView.toggleFocus()
      'commit-live:focus': => @termView.fullFocus()
      'commit-live:toggle:debugger': => @term.toggleDebugger()
      'commit-live:reset': => @term.reset()
      # 'application:update-ile': -> (new Updater).checkForUpdate()

    atom.config.onDidChange 'greyatom-ide.notifier', ({newValue}) =>
      if newValue then @activateNotifier() else @notifier.deactivate()

    openPath = localStorage.get('commitLiveOpenLabOnActivation')
    if openPath
      localStorage.delete('commitLiveOpenLabOnActivation')
      @termView.openLab(openPath)

  activateNotifier: ->
    if atom.config.get('greyatom-ide.notifier')
      @notifier = new Notifier(@token.get())
      @notifier.activate()

  activateUpdater: ->
    if !@isRestartAfterUpdate
      Updater.checkForUpdate()

  deactivate: ->
    localStorage.delete('disableTreeView')
    localStorage.delete('terminalOut')
    @termView = null
    @statusView = null
    @subscriptions.dispose()
    @projectSearch.destroy()
    # if toolBar
    #   toolBar.removeItems();
    #   toolBar = null;

  subscribeToLogin: ->
    @subscriptions.add atom.commands.add 'atom-workspace',
      'commit-live:log-in-out': => @logInOrOut()

  cleanup: ->
    atomHelper.cleanup()

  consumeToolBar: (getToolBar) ->
    # toolBar = getToolBar('greyatom-ide');
    # toolBar.addButton({
    #   icon: 'play',
    #   callback: 'application:about',
    #   tooltip: 'Test',
    #   iconset: 'fa'
    # })
    # toolBar.addButton({
    #   icon: 'eject',
    #   callback: 'application:about',
    #   tooltip: 'Submit',
    #   iconset: 'fa'
    # })
    # toolBar.addButton({
    #   icon: 'exchange',
    #   callback: 'commit-live:get-all-projects',
    #   tooltip: 'Switch Project',
    #   iconset: 'fa'
    # })

  consumeStatusBar: (statusBar) ->
    @addStatusBar = statusBar.addRightTile

  logInOrOut: ->
    if @token.get()?
      @logout()
    else
      atomHelper.resetPackage()

  logout: ->
    localStorage.delete('commit-live:user-info')
    localStorage.delete('commit-live:last-opened-project')
    @token.unset()
    @token.unsetID()
    atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:hide')
    atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:show-login')

  checkForV1WindowsInstall: ->
    require('./windows')

  registerWindowsProtocol: ->
    if process.platform == 'win32'
      require('./protocol')
