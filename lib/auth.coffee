url = require 'url'
http = require 'http'
remote = require 'remote'
shell = require 'shell'
path = require 'path'
_token = require './token'
localStorage = require './local-storage'
BrowserWindow = remote.require('browser-window')

workspaceView = atom.views.getView(atom.workspace)

console.log "atom.appVersion"
console.log atom.appVersion

confirmOauthToken = (token) ->
  return new Promise (resolve, reject) ->
    try
      authRequest = http.get
        host: 'api.myjson.com'
        # port : 7000
        path: '/bins/c4vbn'
        # path: '/api/v1/users/me?ile_version=' + atom.appVersion
        # headers:
        #   'Authorization': 'Bearer ' + token
      , (response) ->
        body = ''

        response.on 'data', (d) ->
          body += d

        response.on 'error', reject

        response.on 'end', ->
          try
            parsed = JSON.parse(body)
            console.log("PARSED", parsed)
            if parsed.email
              localStorage.set('commit-live:user-info', body)
              resolve parsed
            else
              resolve false
          catch
            reject false

      authRequest.on 'error', (err) ->
        reject err

    catch err
      reject err

githubLogin = () ->
  new Promise (resolve, reject) ->
    win = new BrowserWindow(show: false, width: 440, height: 660, resizable: false)
    webContents = win.webContents

    win.setSkipTaskbar(true)
    win.setMenuBarVisibility(false)
    win.setTitle('Sign in to Github to get started with the Commit Live')

    # show window only if login is required
    webContents.on 'did-finish-load', -> win.show()

    # hide window immediately after login
    webContents.on 'will-navigate', (e, url) ->
      win.hide() if url.match(/learn\.co\/users\/auth\/github\/callback/)

    webContents.on 'did-get-redirect-request', (e, oldURL, newURL) ->
      return unless newURL.match(/ide_token/)
      token = url.parse(newURL, true).query.ide_token
      confirmOauthToken(token).then (res) ->
        return unless res?
        _token.set(token)
        win.destroy()
        resolve()

    if not win.loadURL('https://learn.co/ide/token?ide_config=true')
      promptManualEntry()

window.commitLiveSignIn = () ->
  new Promise (resolve, reject) ->
    win = new BrowserWindow(show: false, width: 400, height: 600, resizable: false)
    {webContents} = win

    win.setSkipTaskbar(true)
    win.setMenuBarVisibility(false)
    win.setTitle('Welcome to the Commit Live')

    webContents.on 'did-finish-load', ->
      console.log "finished loading"
      console.log arguments
      win.show()

    webContents.on 'new-window', (e, url) ->
      console.log "in new-window"
      # e.preventDefault()
      # win.destroy()
      # shell.openExternal(url)

    webContents.on 'will-navigate', (e, tokenUrl) ->
      console.log "will-navigate"
      console.log tokenUrl
      if tokenUrl.match(/ide_token/)
        token = url.parse(tokenUrl, true).query.ide_token
        if token?.length
          confirmOauthToken(token).then (res) ->
            return unless res
            _token.set(token)
            if atom.project and atom.project.remoteftp
              atom.project.remoteftp.connectToStudentFTP()
            resolve()
        # console.log('TOKEN:', token)
        # _token.set(token)
        # resolve()
      # if url.match(/github_sign_in/)
        # win.destroy()
        # githubLogin().then(resolve)

    webContents.on 'did-get-redirect-request', (e, oldURL, newURL) ->
      console.log("oldURL", oldURL )
      console.log("newURL", newURL )
      if newURL.match(/ide_token/)
        console.log "/ide_token/"
        token = url.parse(newURL, true).query.ide_token
        console.log('TOKEN:', token)
        _token.set(token)
        resolve()
        #if token?.length
          #confirmOauthToken(token).then (res) ->
          #  return unless res
          #  _token.set(token)
          #  resolve()
      if newURL.match(/github_sign_in/)
        console.log "/github_sign_in/"
        win.destroy()
        githubLogin().then(resolve)

    #if not win.loadURL('https://learn.co/ide/sign_in?ide_onboard=true')
    if not win.loadURL('http://35.154.96.42:7000/signin/')
      win.destroy()
      #githubLogin.then(resolve)

promptManualEntry = ->
  oauthPrompt = document.createElement 'div'
  oauthPrompt.setAttribute 'style', 'width:100%; text-align: center;'

  oauthLabel = document.createElement 'div'
  oauthLabel.setAttribute 'style', 'margin-top: 12px; font-weight: bold; font-size: 12px;'
  oauthLabel.appendChild document.createTextNode 'Please enter your Learn OAuth Token'
  tokenLinkDiv = document.createElement 'div'
  tokenText = document.createTextNode 'Get your token here: '
  tokenLink = document.createElement 'a'
  tokenLink.title = 'https://learn.co/ide/token'
  tokenLink.href = 'https://learn.co/ide/token'
  tokenLink.setAttribute 'style', 'text-decoration: underline;'
  tokenLink.appendChild document.createTextNode 'https://learn.co/ide/token'
  tokenLinkDiv.appendChild tokenText
  tokenLinkDiv.appendChild tokenLink
  oauthPrompt.appendChild oauthLabel
  oauthLabel.appendChild tokenLinkDiv

  invalidLabel = document.createElement 'label'
  invalidLabel.setAttribute 'style', 'opacity: 0;'
  invalidLabel.appendChild document.createTextNode 'Invalid token. Please try again.'
  oauthPrompt.appendChild invalidLabel
  input = document.createElement 'input'
  input.setAttribute 'style', 'width: 100%; text-align: center;'
  input.classList.add 'native-key-bindings'
  oauthPrompt.appendChild input

  panel = atom.workspace.addModalPanel item: oauthPrompt
  input.focus()

  input.addEventListener 'keypress', (e) =>
    if e.which is 13
      token = input.value.trim()
      confirmOauthToken(token).then (res) ->
        if res
          _token.set(token)
          panel.destroy()
          atom.commands.dispatch(workspaceView, 'commit-live:toggle-terminal')
          return true
        else
          invalidLabel.setAttribute 'style', 'color: red; opacity: 100;'

githubLogout = ->
  win = new BrowserWindow(show: false)
  win.webContents.on 'did-finish-load', -> win.show()
  win.loadURL('https://github.com/logout')

commitliveLogout = ->
  win = new BrowserWindow(show: false)
  win.webContents.on 'did-finish-load', -> win.destroy()
  win.loadURL('https://learn.co/sign_out')

window.logout = ->
  _token.unset()
  commitliveLogout()
  githubLogout()

module.exports = ->
  existingToken = _token.get()

  if !existingToken
    commitLiveSignIn()
  else
    confirmOauthToken(existingToken)
