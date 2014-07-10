config = require '../config'
xbox_api = require '../lib/xbox_api'


# Create our user pool
xbox_api.connect config.users

module.exports = (app) ->
	
	queue = (method, args...) ->
		app.resque.enqueue 'xbox', method, args

	app.post "/xbox/:handle/profile", (req, res) ->
		handle = req.params.handle

		notifications = req.body.notifications
		metadata = req.body.metadata

		res.json
			queued: queue 'profile', handle, notifications, metadata
			notifications: notifications
			metadata: metadata

	app.post "/xbox/:handle/games", (req, res) ->
		handle = req.params.handle

		notifications = req.body.notifications
		metadata = req.body.metadata

		res.json
			queued: queue 'games', handle, notifications, metadata
			notifications: notifications
			metadata: metadata
	
	app.post "/xbox/:handle/recent", (req, res) ->
		handle = req.params.handle

		notifications = req.body.notifications
		metadata = req.body.metadata

		res.json
			queued: queue 'recent_games', handle, notifications, metadata
			notifications: notifications
			metadata: metadata
	
	
	app.post "/xbox/:handle/:game_id/achievements", (req, res) ->
		handle = req.params.handle
		game_id = req.params.game_id

		notifications = req.body.notifications
		metadata = req.body.metadata

		res.json
			queued: queue 'achievements', handle, game_id, notifications, metadata
			notifications: notifications
			metadata: metadata
				
	app.post "/xbox/:handle/friends", (req, res) ->
		handle = req.params.handle
		
		notifications = req.body.notifications
		metadata = req.body.metadata
		
		res.json
			queued: queue 'friends', handle, notifications, metadata
			notifications: notifications
			metadata: metadata

	app.post "/xbox/:handle/last_activity", (req, res) ->
		handle = req.params.handle
		
		notifications = req.body.notifications
		metadata = req.body.metadata
		
		res.json
			queued: queue 'last_activity', handle, notifications, metadata
			notifications: notifications
			metadata: metadata
			
