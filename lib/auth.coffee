url = require 'url'
shell = require 'shell'
path = require 'path'
version = require './version'
fetch = require './fetch'
_token = require './token'
localStorage = require './local-storage'
{commitLive, commitLiveApi} = require './config'
{BrowserWindow} = require 'remote'

confirmOauthToken = (token,userId) ->
  headers = new Headers(
    {'Authorization': token }
  )
  AUTH_URL = "#{commitLiveApi}/users/#{userId}"
  fetch(AUTH_URL, {headers}).then (response) ->
    console.log 'Get User Response'
    console.log response
    if response.data.email
      localStorage.set('commit-live:user-info', JSON.stringify(response.data))
      return response
    else
      return false

commitLiveSignIn = () ->
  new Promise (resolve, reject) ->
    win = new BrowserWindow(
      autoHideMenuBar: true, 
      show: false, 
      width: 400, 
      height: 600, 
      resizable: false,
      webPreferences: {
        partition: 'new:abc'
      }
    )
    {webContents} = win

    win.setSkipTaskbar(true)
    win.setMenuBarVisibility(false)
    win.setTitle('Welcome to the Commit.Live')

    webContents.on 'did-finish-load', -> win.show()

    webContents.on 'close', ->
      webContents = null
      win = null

    webContents.on 'new-window', (e, url) ->
      e.preventDefault()

    webContents.on 'did-get-redirect-request', (e, oldURL, newURL) ->
      if newURL.match("accessToken")
        token = url.parse(newURL, true).query.accessToken
        userId = url.parse(newURL, true).query.userId
        if token?.length
          win.destroy()
          confirmOauthToken(token,userId).then (res) ->
            return unless res
            _token.set(token)
            _token.setID(userId)
            atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:hide')
            atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:show-dashboard')
            atom.notifications.addSuccess 'Commit Live IDE: You have successfully logged in.'
            resolve()

    if not win.loadURL(commitLive)
      win.destroy()

showLoginScreen = () ->
  new Promise (resolve, reject) ->
    reject()

module.exports = ->
  existingToken = _token.get()
  existingId = _token.getID()

  if !existingToken
    showLoginScreen()
  else
    confirmOauthToken(existingToken,existingId)

module.exports.loginWithGithub = commitLiveSignIn