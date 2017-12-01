url = require 'url'
shell = require 'shell'
path = require 'path'
version = require './version'
fetch = require './fetch'
_token = require './token'
localStorage = require './local-storage'
{BrowserWindow} = require 'remote'
{Notification} = require 'atom'

confirmOauthToken = (token,userId) ->
  headers = new Headers(
    {'Authorization': token }
  )
  apiEndpoint = atom.config.get('greyatom-ide').apiEndpoint
  AUTH_URL = "#{apiEndpoint}/users/#{userId}"
  fetch(AUTH_URL, {headers}).then (response) ->
    console.log 'Get User Response'
    console.log response
    if response.data.email
      localStorage.set('commit-live:user-info', JSON.stringify(response.data))
      return response
    else
      return false

notifyPopup = null

hideNotify = () ->
  if notifyPopup
    notifyPopup.dismiss()

showNotify = (text) ->
  hideNotify()
  if text
    notifyPopup = new Notification("info", "Commit Live IDE: #{text}", {dismissable: true})
    atom.notifications.addNotification(notifyPopup)

commitLiveSignIn = () ->
  showNotify("Connecting to Github...")
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

    webContents.on 'did-finish-load', ->
      loadedUrl = webContents.getURL()
      if loadedUrl is "https://github.com/login/oauth/authorize"
        showNotify("Authenticating...")
        win.hide()
        return
      firstMatch = loadedUrl.startsWith('https://github.com/login?client_id=')
      secondMatch = loadedUrl.startsWith('https://github.com/login/oauth/authorize?client_id=')
      if firstMatch
        hideNotify()
        win.show()
      webContents.findInPage('Authorize') if secondMatch

    webContents.on 'found-in-page', (event, result) ->
      if result.matches
        hideNotify()
        webContents.stopFindInPage('clearSelection')
        win.focus()
        win.show()

    webContents.on 'close', ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:enable-login-btn')
      hideNotify()
      webContents = null
      win = null

    webContents.on 'new-window', (e, url) ->
      e.preventDefault()

    webContents.on 'did-get-redirect-request', (e, oldURL, newURL) ->
      win.hide()
      showNotify("Authenticating...") if oldURL is "https://github.com/session"
      if newURL.match("accessToken")
        token = url.parse(newURL, true).query.accessToken
        userId = url.parse(newURL, true).query.userId
        if token?.length
          win.destroy()
          confirmOauthToken(token,userId).then (res) ->
            return unless res
            _token.set(token)
            _token.setID(userId)
            hideNotify()
            atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:hide')
            atom.commands.dispatch(atom.views.getView(atom.workspace), 'commit-live-welcome:show-dashboard')
            atom.notifications.addSuccess 'Commit Live IDE: You have successfully logged in.'
            resolve()

    apiEndpoint = atom.config.get('greyatom-ide').apiEndpoint
    if not win.loadURL("#{apiEndpoint}/github/login")
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