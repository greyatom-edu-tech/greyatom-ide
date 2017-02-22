protocol = require 'register-protocol-win32'

protocol.install('commit-live', "#{process.execPath} --url-to-open=\"%1\"")
