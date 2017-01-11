path = require 'path'
_ = require 'underscore-plus'

require('dotenv').config
  path: path.join(__dirname, '..', '.env')
  silent: true

require('dotenv').config
  path: path.join(atom.getConfigDirPath(), '.env')
  silent: true

module.exports = _.defaults
  host: process.env['IDE_WS_HOST']
  port: process.env['IDE_WS_PORT']
  path: process.env['IDE_WS_TERM_PATH']
,
  host: '0.0.0.0'
  port: 3000
  path: 'terminals'
