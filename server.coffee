prettyjson = require 'prettyjson'
app = require './app'
winston = require 'winston'
config = require './config'

host_port = process.env.NODE_PORT or= 5000

puts = (d) -> console.log prettyjson.render d

winston.cli()


app.listen host_port, ->
  console.log "Server listening on port %d in %s mode", app.address().port, app.settings.env
