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
  commitLive: 'https://app.commit.live/'
  commitLiveApi: 'https://api.commit.live/'
