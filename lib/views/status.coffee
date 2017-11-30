{View} = require 'atom-space-pen-views'
{ipcRenderer} = require 'electron'
{EventEmitter} = require 'events'

localStorage = require '../local-storage'

module.exports =
class StatusView extends View
  @content: ->
    @div class: 'commit-live-synced-fs-status', =>
      @div class: 'commit-live-status-icon inline-block icon-terminal', id: 'commit-live-status-icon', ' Commit Live'
      @div class: 'commit-live-popout-terminal-icon inline-block icon-link-external', id: 'commit-live-popout-terminal-icon'

  constructor: (state, termSocket, @options) ->
    super
    @socket = termSocket
    @activateEventHandlers()
    @activatePopoutIcon()

  on: ->
    @emitter || (@emitter = new EventEmitter)
    @emitter.on.apply(@emitter, arguments)

  activateEventHandlers: ->
    @socket.on 'open', =>
      icon = @statusIcon()
      icon.textContent = 'Commit Live'
      icon.dataset.status = 'good'

    @socket.on 'close', =>
      @displayDisconnected()

    @socket.on 'error', =>
      @displayDisconnected()

    @statusIcon().addEventListener 'click', (e) =>
      # TODO: have this based on the socket state itself instead of the view state
      if e.target.dataset.status == 'bad'
        @socket.reset()

  displayDisconnected: ->
    icon = @statusIcon()
    icon.textContent = ' Commit Live...reconnect?'
    icon.dataset.status = 'bad'

  activatePopoutIcon: ->
    if @options.isTerminalWindow
      @hidePopoutIcon()

    @popoutIcon().addEventListener 'click', =>
      @popoutTerminal()

  popoutTerminal: ->
    localStorage.set('popoutTerminal', true)
    localStorage.set('disableTreeView', true)
    ipcRenderer.send('command', 'application:new-window')
    @emitter.emit 'terminal:popout'
    @hidePopoutIcon()

  onTerminalPopIn: ->
    @showPopoutIcon()

  # ui elements

  statusIcon: ->
    @element.getElementsByClassName('commit-live-status-icon')[0]

  popoutIcon: ->
    @element.getElementsByClassName('commit-live-popout-terminal-icon')[0]

  showPopoutIcon: ->
    @popoutIcon().classList.remove('inactive')
    @popoutIcon().classList.add('active')

  hidePopoutIcon: ->
    @popoutIcon().classList.remove('active')
    @popoutIcon().classList.add('inactive')
