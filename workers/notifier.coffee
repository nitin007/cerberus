config = require '../config'
resque = require('coffee-resque').connect config.redis

Turbine = require '../lib/turbine'

send = (url, metadata, data) ->
  console.log "sending notification to #{url}"
  payload =
    metadata: metadata
    data: data
  new Turbine
    url: url
    method: 'post'
    json: payload
  , (err, res, body) ->
    console.error err
    console.log body


tasks =
  http: (notifications, metadata, data, done) ->
    unless notifications
      done()
    else
      send(url, metadata, data) for url in notifications.toString().split ','
      done()

worker = module.exports = resque.worker 'notify', tasks
