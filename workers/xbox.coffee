config = require "../config"

resque = require('coffee-resque').connect config.redis
api  = require '../lib/xbox_api'

api.connect config.users

notify = (args...) ->
  resque.enqueue 'notify', 'http', args

tasks =
  games: (handle, notifications, metadata, done) ->
    api.games handle, (err, games) ->
      delete games.data
      notify notifications, metadata, games
      done(games)

  profile: (handle, notifications, metadata, done) ->
    api.profile handle, (err, profile) ->
      notify notifications, metadata, profile
      done(profile)

  achievements: (handle, game, notifications, metadata, done) ->
    api.achievements handle, game, (err, achievements) ->
      delete achievements.data
      notify notifications, metadata, achievements
      done(achievements)

  recent_games: (handle, notifications, metadata, done) ->
    api.recent_games handle, (err, games) ->
      delete games.data
      notify notifications, metadata, games
      done(games)
  
  friends: (handle, notifications, metadata, done) ->
    api.friends handle, (err, friends) ->
      notify notifications, metadata, friends
      done(friends)
  
  last_activity: (handle, notifications, metadata, done) ->
    api.last_activity handle, (err, last_activity) ->
      notify notifications, metadata, last_activity
      done(last_activity)
      
worker = module.exports = resque.worker 'xbox', tasks

# when running directly, start the worker
if require.main is module
  worker.start()
