protocol = require 'register-protocol-win32'

protocol.install('greyatom-ide', "#{process.execPath} --url-to-open=\"%1\"")
