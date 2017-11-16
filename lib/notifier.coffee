https = require 'https'
querystring = require 'querystring'
{EventEmitter} = require 'events'
AtomSocket = require 'atom-socket'
atomHelper = require './atom-helper'
path = require 'path'
io = require 'socket.io-client'
remote = require 'remote'
localStorage = require './local-storage'
{Notification} = require 'atom'
BrowserWindow = remote.BrowserWindow

module.exports =
class Notifier extends EventEmitter
  constructor: (authToken) ->
    @authToken     = authToken
    @notifRegistry = []
    @notifTitles = {}
    @notificationTypes = ['submission']

  activate: ->
    try
      @userInfo =  JSON.parse(localStorage.get('commit-live:user-info'))
      @socket = io.connect(@userInfo.servers.notification , reconnect: true)
      @socket.on 'connect', =>
        @socket.emit 'join', room: @userInfo.username
        # console.log 'socket.io is connected, listening for notification'

      @socket.on 'my_response', (msg) ->
        # console.log "Got message from websocket server :)"
        # console.log msg
        # if msg.data == 'ping'
        #   console.log "Got ping packet from websocket server :)"

        if msg.data != 'ping'
          try
            rawData = JSON.parse(msg.data)
            # console.log rawData
            if rawData.type == 'notify_ide'
              if rawData.message.type == 'testCasesPassed'
                atom.notifications.addSuccess(rawData.title, {
                  description: 'Perfect! You have passed the test cases!',
                  dismissable: false
                });

              if rawData.message.type == 'testCasesFailed'
                atom.notifications.addError(rawData.title, {
                  description: 'Uh-oh! You still have to pass the test cases!',
                  dismissable: false
                });

              if rawData.message.type == 'forked'
                atom.notifications.addSuccess(rawData.title, {
                  description: 'Bingo! You have forked the project successfully!',
                  dismissable: false
                });

              if rawData.message.type == 'submittedPr'
                atom.notifications.addSuccess(rawData.title, {
                  description: 'Good work! You have submitted successfully!',
                  dismissable: false
                });

            if rawData.type == 'pop_image'
              win = new BrowserWindow(
                show: false,
                width: parseInt(rawData.width),
                height: parseInt(rawData.height),
                resizable: true,
                useContentSize : true
              )
              win.setSkipTaskbar(true)
              win.setMenuBarVisibility(false)
              win.setTitle(rawData.title)
              win.loadURL(rawData.url)
              win.show()

          catch error
            console.log 'Notification message from websocket contains invali JSON string'

    catch err
        console.log err

  deactivate: ->
    @socket.disconnect()
