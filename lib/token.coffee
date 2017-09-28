localStorage = require './local-storage'
bus = require('./event-bus')()

TOKEN_KEY = 'commit-live:token'
ID_KEY = 'commit-live:id'

module.exports = token = {
  get: ->
    localStorage.get(TOKEN_KEY)

  set: (value) ->
    localStorage.set(TOKEN_KEY, value)
    bus.emit(TOKEN_KEY, value)

  unset: ->
    localStorage.delete(TOKEN_KEY)
    bus.emit(TOKEN_KEY, undefined)

  observe: (callback) ->
    callback(token.get())
    bus.on(TOKEN_KEY, callback)

  getID: ->
    localStorage.get(ID_KEY)

  setID: (value) ->
    localStorage.set(ID_KEY, value)
    bus.emit(ID_KEY, value)

  unsetID: ->
    localStorage.delete(ID_KEY)
    bus.emit(ID_KEY, undefined)

  observeID: (callback) ->
    callback(geID.get())
    bus.on(ID_KEY, callback)
}
