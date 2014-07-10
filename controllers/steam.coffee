config = require '../config'
steam_api = require '../lib/steam_api'
_ = require 'underscore'

steam_api.api_key = config.steam_api_key

module.exports = (app) ->
  queue = (method, args...) ->
    app.resque.enqueue 'steam', method, args

  app.post '/steam/:handle/profile', (req, res) ->
    handle = req.params.handle
    
    notifications = req.body.notifications
    metadata = req.body.metadata

    res.json
      queued: queue 'profile', handle, notifications, metadata
      notifications: notifications
      metadata: metadata

  app.post '/steam/:handle/games', (req, res) ->
    handle = req.params.handle
    
    notifications = req.body.notifications
    metadata = req.body.metadata

    res.json
      queued: queue 'games', handle, notifications, metadata
      notifications: notifications
      metadata: metadata

  app.post '/steam/:handle/games/recent', (req, res) ->
    handle = req.params.handle
    
    notifications = req.body.notifications
    metadata = req.body.metadata

    res.json
      queued: queue 'recent_games', handle, notifications, metadata
      notifications: notifications
      metadata: metadata

  app.post '/steam/:handle/:game_id/achievements', (req, res) ->
    handle = req.params.handle
    game = req.params.game_id
    
    notifications = req.body.notifications
    metadata = req.body.metadata

    res.json
      queued: queue 'achievements', handle, game, notifications, metadata
      notifications: notifications
      metadata: metadata

  app.post '/steam/:handle/friends', (req,res) ->
    handle = req.params.handle

    notifications = req.body.notifications
    metadata = req.body.metadata
    
    res.json
      queued: queue 'friends', handle, notifications, metadata
      notifications: notifications
      metadata: metadata

  app.post "/steam/:handle/last_activity", (req, res) ->
    handle = req.params.handle
    
    notifications = req.body.notifications
    metadata = req.body.metadata
    
    res.json
      queued: queue 'last_activity', handle, notifications, metadata
      notifications: notifications
      metadata: metadata
