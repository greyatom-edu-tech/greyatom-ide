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
    console.log 'response'
    console.log response
    if response.data.email
      localStorage.set('commit-live:user-info', JSON.stringify(response.data))
      return response
    else
      return false

githubLogin = () ->
  new Promise (resolve, reject) ->
    win = new BrowserWindow(autoHideMenuBar: true, show: false, width: 440, height: 660, resizable: false)
    webContents = win.webContents

    win.setSkipTaskbar(true)
    win.setMenuBarVisibility(false)
    win.setTitle('Sign in to Github to get started with the Learn IDE')

    # show window only if login is required
    webContents.on 'did-finish-load', -> win.show()

    # hide window immediately after login
    webContents.on 'will-navigate', (e, url) ->
      win.hide() if url.match("#{learnCo}/users/auth/github/callback")

    webContents.on 'did-get-redirect-request', (e, oldURL, newURL) ->
      return unless newURL.match(/ide_token/)
      token = url.parse(newURL, true).query.ide_token
      confirmOauthToken(token).then (res) ->
        return unless res?
        localStorage.set('didCompleteGithubLogin')
        _token.set(token)
        win.destroy()
        resolve()

    if not win.loadURL("#{learnCo}/ide/token?ide_config=true")
      atom.notifications.warning 'Learn IDE: connectivity issue',
        detail: "The editor is unable to connect to #{learnCo}. Are you connected to the internet?"
        buttons: [
          {text: 'Try again', onDidClick: -> learnSignIn()}
        ]

commitLiveSignIn = () ->
  new Promise (resolve, reject) ->
    win = new BrowserWindow(autoHideMenuBar: true, show: false, width: 400, height: 600, resizable: false)
    {webContents} = win

    win.setSkipTaskbar(true)
    win.setMenuBarVisibility(false)
    win.setTitle('Welcome to the Commit.Live')

    webContents.on 'did-finish-load', -> win.show()

    webContents.on 'new-window', (e, url) ->
      e.preventDefault()
      # win.destroy()
      # shell.openExternal(url)

    # webContents.on 'will-navigate', (e, url) ->
    #   if url.match(/github_sign_in/)
    #     win.destroy()
    #     githubLogin().then(resolve)

    webContents.on 'did-get-redirect-request', (e, oldURL, newURL) ->
      if newURL.match("accessToken")
        console.log "m here "
        token = url.parse(newURL, true).query.accessToken
        userId = url.parse(newURL, true).query.userId
        if token?.length
          win.destroy()
          confirmOauthToken(token,userId).then (res) ->
            return unless res
            _token.set(token)
            _token.setID(userId)
            if atom.project and atom.project.remoteftp
              atom.project.remoteftp.connectToStudentFTP()
            resolve()
      # if newURL.match(/github_sign_in/)
      #   win.destroy()
      #   githubLogin().then(resolve)
    console.log "#{commitLive}/logout"
    if not win.loadURL("#{commitLive}/logout")
      win.destroy()
      githubLogin.then(resolve)

module.exports = ->
  existingToken = _token.get()
  existingId = _token.getID()

  if !existingToken
    commitLiveSignIn()
  else
    confirmOauthToken(existingToken,existingId).then =>
      if atom.project and atom.project.remoteftp
        atom.project.remoteftp.connectToStudentFTP()
