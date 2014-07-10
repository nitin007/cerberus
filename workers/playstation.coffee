config = require "../config"

resque = require('coffee-resque').connect config.redis
api  = require '../lib/psn2_api'

notify = (args...) ->
  resque.enqueue 'notify', 'http', args

tasks =
  games: (handle, notifications, metadata, done) ->
    api.games handle, (err, games) ->
      notify notifications, metadata, games
      done(games)

  profile: (handle, notifications, metadata, done) ->
    api.profile handle, (err, profile) ->
      notify notifications, metadata, profile
      done(profile)

  achievements: (handle, game, notifications, metadata, done) ->
    api.achievements handle, game, (err, achievements) ->
      notify notifications, metadata, achievements
      done(achievements)

  recent_games: (handle, notifications, metadata, done) ->
    api.recent_games handle, (err, games) ->
      notify notifications, metadata, games
      done(games)

  last_activity: (handle, notifications, metadata, done) ->
    api.last_activity handle, (err, last_activity) ->
      notify notifications, metadata, last_activity
      done(last_activity)

worker = module.exports = resque.worker 'playstation', tasks

# when running directly, start the worker
if require.main is module
  worker.start()
