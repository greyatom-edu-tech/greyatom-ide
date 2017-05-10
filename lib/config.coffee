path = require 'path'
_ = require 'underscore-plus'

require('dotenv').config
  path: path.join(__dirname, '..', '.env')
  silent: true

require('dotenv').config
  path: path.join(atom.getConfigDirPath(), '.env')
  silent: true

module.exports = _.defaults
  commitLive: process.env['IDE_COMMIT_LIVE']
  commitLiveApi: process.env['IDE_COMMIT_LIVE_API']
,
  commitLive: 'http://app.greyatom.com'
  commitLiveApi: 'http://api.greyatom.com'
