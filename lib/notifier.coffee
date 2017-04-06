https = require 'https'
querystring = require 'querystring'
{EventEmitter} = require 'events'
AtomSocket = require 'atom-socket'
atomHelper = require './atom-helper'
path = require 'path'
io = require 'socket.io-client'
remote = require 'remote'
localStorage = require './local-storage'
BrowserWindow = remote.require('browser-window')

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
      @socket = io.connect('http://35.154.206.75:5000/' , reconnect: true)
      @socket.on 'connect', =>
        @socket.emit 'join', room: @userInfo.username
        console.log 'socket.io is connected, listening for notification'

      @socket.on 'my_response', (msg) ->
        console.log 'msg from websocket'
        console.log msg
        if msg.data == 'ping'
          console.log "Got ping packet from websocket server :)"

        if msg.data != 'ping'
          try
            rawData = JSON.parse(msg.data)
            console.log rawData
            if rawData.type == 'notify_ide'
              if rawData.message.type == 'test_case_pass'
                notif = new Notification rawData.title,
                  body: 'Test cases passed successfully'

                notif.onclick = ->
                  notif.close()

              if rawData.message.type == 'test_case_fail'
                notif = new Notification rawData.title,
                  body: 'Test cases failed'

                notif.onclick = ->
                  notif.close()

              if rawData.message.type == 'completed_reading'
                notif = new Notification rawData.title,
                  body: if rawData.message.value == 'true' then 'Reading completed successfully' else 'Reading not completed'

                notif.onclick = ->
                  notif.close()

              if rawData.message.type == 'lesson_forked'
                notif = new Notification rawData.title,
                  body: if rawData.message.value == 'true' then  'Forked successfully' else 'Forked failed'

                notif.onclick = ->
                  notif.close()

              if rawData.message.type == 'submitted_pull_request'
                notif = new Notification rawData.title,
                  body: if rawData.message.value == 'true' then 'Pull request submitted successfully' else 'Pull request failed'

                notif.onclick = ->
                  notif.close()

              if rawData.message.type == 'reviewed'
                notif = new Notification rawData.title,
                  body: if rawData.message.value == 'true' then 'Review completed successfully' else 'Review failed'

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

          catch error
            console.log 'Notification message from websocket contains invali JSON string'

    catch err
        console.log err

  deactivate: ->
    @socket.disconnect()
