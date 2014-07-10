config = require '../config'

module.exports = (app) ->

  app.get '/', (req, res) ->
    res.json urls:
      xbox: config.base_url + '/xbox'
      playstation: config.base_url + '/playstation'
      steam: config.base_url + '/steam'