config = require '../config'
psn_api = require '../lib/psn_api'

module.exports = (app) ->
  queue = (method, args...) ->
    app.resque.enqueue 'playstation', method, args

  app.post '/playstation/:handle/profile', (req, res) ->
    handle = req.params.handle

    notifications = req.body.notifications
    metadata = req.body.metadata

    res.json
      queued: queue 'profile', handle, notifications, metadata
      notifications: notifications
      metadata: metadata

  app.post '/playstation/:handle/games', (req, res) ->
    handle = req.params.handle

    notifications = req.body.notifications
    metadata = req.body.metadata

    res.json
      queued: queue 'games', handle, notifications, metadata
      notifications: notifications 
      metadata: metadata
  
  app.post '/playstation/:handle/recent', (req, res) ->
    handle = req.params.handle
    
    notifications = req.body.notifications
    metadata = req.body.metadata
    
    res.json
      queued: queue 'recent_games', handle, notifications, metadata
      notifications: notifications 
      metadata: metadata
  
  app.post '/playstation/:handle/:game_id/achievements', (req, res) ->
    handle = req.params.handle
    game = req.params.game_id

    notifications = req.body.notifications
    metadata = req.body.metadata

    res.json
      queued: queue 'achievements', handle, game, notifications, metadata
      notifications: notifications
      metadata: metadata

  app.post "/playstation/:handle/last_activity", (req, res) ->
    handle = req.params.handle
    
    notifications = req.body.notifications
    metadata = req.body.metadata
    
    res.json
      queued: queue 'last_activity', handle, notifications, metadata
      notifications: notifications
      metadata: metadata
