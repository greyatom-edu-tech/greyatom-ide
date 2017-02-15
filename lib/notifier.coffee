https = require 'https'
querystring = require 'querystring'
{EventEmitter} = require 'events'
AtomSocket = require 'atom-socket'
atomHelper = require './atom-helper'
path = require 'path'
io = require 'socket.io-client'

module.exports =
class Notifier extends EventEmitter
  constructor: (authToken) ->
    @authToken     = authToken
    @notifRegistry = []
    @notifTitles = {}
    @notificationTypes = ['submission']

  activate: ->
    try
      @socket = io.connect('http://35.154.96.42:9000', reconnect: true)

      @socket.on 'connect', =>
        @socket.emit 'room', @authToken
        console.log 'socket.io is connected, listening for notification'

      @socket.on 'message', (msg) ->
        rawData = JSON.parse(msg)
        console.log rawData
        if rawData.type == 'notify_ide'
          notif = new Notification rawData.title,
            body: rawData.message

          notif.onclick = ->
            notif.close()

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

    catch err
        console.log err

  deactivate: ->
    @socket.disconnect()
