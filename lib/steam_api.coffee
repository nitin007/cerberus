
jsdom = require 'jsdom'
_ = require 'underscore'
logger = require("#{__dirname}/logger") 'steam'
prettyjson = require 'prettyjson'
Turbine = require "#{__dirname}/turbine"
qs = require 'querystring'
parser = require 'xml2json'

logger.cli()

# The `steam_api` connects to and scrapes data from
# Steam. Most of the time, we are able to use the
# Steam APIs, except for the game list.

class steam_api

  version: '0.1.0'

  # Prefix all api requests with this URL
  url_prefix: 'http://api.steampowered.com'

  # Cache the steam/app IDs in memory since finding them is expensive
  steam_ids = {}
  app_ids = {}

  # These are helper arrays that have the word versions of statuses
  user_status: 'offline busy away snooze'.split(' ')
  visibility_status: 'false private friends public'.split(' ')

  # This is required to actually get the data.
  # It can be requested here: http://steamcommunity.com/dev/apikey
  api_key: ''

  # Retrieve the profile information for a given player
  #
  profile: (player, cb =(->)) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - steam profile (#{player}) -"
    logger.profile profiler_identifier
    # The player may be a vanity name, so we convert it to a steam_id
    @resolveVanity player, (err, steam_id) =>
      if err
        
        if err.invalid?
          process.nextTick -> cb null, {invalid: true}
        else
          process.nextTick -> cb err, {}
        logger.profile profiler_identifier
        return

      query =
        key: @api_key
        steamids: steam_id
      url = @url_prefix + '/ISteamUser/GetPlayerSummaries/v0002/?' + qs.stringify(query)
      Turbine url: url, (err, res, body) ->
        if err
          logger.profile profiler_identifier
          logger.error 'enable to get steam profile', err
          return cb err, {}

        try
          json = JSON.parse body
          logger.profile profiler_identifier
          process.nextTick -> cb null, json.response.players[0]
        catch error
          logger.profile profiler_identifier
          process.nextTick -> cb error, {}
        
      
  # Retrieve the friends for a given player
  friends: (player, cb = (->) ) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - steam friends (#{player}) -"
    logger.profile profiler_identifier
    # The player may be a vanity name, so we convert it to a steam_id
    @resolveVanity player, (err, steam_id) =>
      if err
        logger.profile profiler_identifier
        logger.error 'unable to get steam friends', err
        return cb err, {}

      query =
        key: @api_key
        steamid: steam_id
        relationship: 'friend'
      url = @url_prefix + '/ISteamUser/GetFriendList/v0001/?' + qs.stringify(query)
      Turbine url, (err, res, body) =>
        if err
          logger.profile profiler_identifier
          logger.error 'unable to get steam friends', err
          return cb err, {}

        json = JSON.parse body
        friends = if json.friendslist then json.friendslist.friends else []
        friend_list = _.pluck(friends, 'steamid')

        query =
          key: @api_key
          steamids: friend_list.join(',')
        url = @url_prefix + '/ISteamUser/GetPlayerSummaries/v0002/?' + qs.stringify(query)

        Turbine url, (err, res, body) ->
          if err
            logger.profile profiler_identifier
            logger.error 'unable to get steam friends', err
            return cb err, {}

          json = JSON.parse body
          logger.profile profiler_identifier
          process.nextTick -> cb null, json.response.players
      
  
  # Get all games, with the recent ones at the top. The recent
  # games follows the ordering of the `recent_games` method.
  games: (player, cb = (->)) ->
    # collect recent games
    @recent_games player, (err, recent_games) =>
      if err
        logger.error 'unable to get steam games', err
        return cb err, {}

      # collection all the games
      @all_games player, (err, games_by_playtime) =>
        if err
          logger.error 'unable to get steam games', err
          return cb err, {}

        # This makes the recent games on the top, which may be
        # duplicated anywhere else in the collection
        every_game = _.union recent_games, games_by_playtime
        data = []
        for game in every_game
          exists_in_data = no
          for existing_game in data
            # appids are unique integers
            if existing_game.appid is game.appid
              exists_in_data = yes
              break
          unless exists_in_data
            data.push game

        process.nextTick -> cb null, data

  # Retreive the recent games
  #
  # Steam has an actual "recent games" tab to load the recent games
  # this gives us an easy way to view activity in the last 2 weeks
  recent_games: (player, cb = (->)) ->
    @resolveVanity player, (err, steam_id) =>
      if err
        logger.error 'unable to get steam games', err
        return cb err, {}
        
      @all_games steam_id, (err, recent_games) ->
        if err
          logger.error 'unable to get steam games', err
          return cb err, {}
        
        process.nextTick -> cb null, recent_games

      , "http://steamcommunity.com/profiles/#{steam_id}/games?tab=recent"

  # Retrieve the games for a given player
  #
  # Steam doesn't provide an API for this information, so
  # we are forced to scrape the player's public pages.
  # Thankfully, they have data in JSON embedded on the page.
  all_games: (player, cb = (->), alt_url = undefined) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - steam games (#{player}) -"
    logger.profile profiler_identifier
    # The player may be a vanity name, so we convert it to a steam_id
    @resolveVanity player, (err, steam_id) =>
      if err
        logger.profile profiler_identifier
        logger.error 'unable to get steam games', err
        return cb err, {}

      url = alt_url || "http://steamcommunity.com/profiles/#{steam_id}/games?tab=all"
      Turbine url, (err, res, body) ->
        if err
          logger.profile profiler_identifier
          logger.error 'unable to get steam games', err
          return cb err, {}

        data = {}
        if body?
          # Pull out the embedded JSON
          data = body.match(/rgGames = (.*);/)
          if data?.length > 0 
            data = data[1]
            json = JSON.parse data

            # Data gets normalized to appear the same across
            # all platforms
            normalized = []
            for game in json
              aname = game.friendlyURL + ""
              aname = if aname and aname.match(/\//) then aname.split('/')[1] else aname
              
              normalized.push
                appid: parseInt game.appid
                name: game.name
                tile: game.logo
                apiname: aname
                hours_played: game.hours_forever
                
            process.nextTick -> cb null, normalized
            
          else
            game_err =
              code: 502
              message: 'Unable to get games from STEAM'
            logger.error prettyjson.render game_err
            logger.profile profiler_identifier
            process.nextTick ->  cb(game_err, {})
        else
          game_err =
            code: 502
            message: 'Unable to get games from STEAM'
          logger.error prettyjson.render game_err
          logger.profile profiler_identifier
          process.nextTick -> cb(game_err, {})

  # Retrieve the news for a given application (usually a game)
  news: (app_id, cb = (->)) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - steam news (#{app_id}) -"
    logger.profile profiler_identifier

    query =
      appid: app_id
      key: @api_key
    url = @url_prefix + '/ISteamNews/GetNewsForApp/v0002/?' + qs.stringify(query)
    Turbine url, (err, res, body) ->
      if err
        logger.profile profiler_identifier
        logger.error 'unable to get steam news', err
        return cb err, {}

      try
        data = JSON.parse body
        logger.profile profiler_identifier
        process.nextTick -> cb null, data?.appnews.newsitems
      catch error
        process.nextTick -> cb null, {}

  # Retrieve the achievements for a given player and application
  achievements: (player, friendlyURL, cb = (->)) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - steam achievements (#{player}, #{friendlyURL}) -"
    logger.profile profiler_identifier

    # The player may be a vanity name, so we convert it to a steam_id
    @resolveVanity player, (err, steam_id) =>
      if err
        logger.error 'unable to get steam achievements', err
        logger.profile profiler_identifier
        return cb err, {}

      query =
        appid: friendlyURL
        key: @api_key
        steamid: steam_id
        
      url = @url_prefix + '/ISteamUserStats/GetSchemaForGame/v2?' + qs.stringify(query)
      # url = "http://steamcommunity.com/profiles/#{steam_id}/stats/#{friendlyURL}?xml=1"
      Turbine url, (err, res, body) ->
        if err
          logger.error 'unable to get steam achievements', err
          logger.profile profiler_identifier
          return cb err, {}
        try
          json = JSON.parse body
          data = []
          # achievements = json?.playerstats?.achievements.achievement or []
          achievements = json?.game?.availableGameStats?.achievements or []
        
          for achievement in achievements
            achieved = if achievement.closed is 1 or achievement.closed is "1" then yes else no
            data.push
              earned: achieved
              earned_date: if achieved then achievement.unlockTimestamp else undefined
              name: achievement.name
              tile: achievement.icon
              description: achievement.description
              apiname: achievement.name

          logger.info "Achievements for #{friendlyURL} - user: #{player} - count: #{achievements.length}"
          process.nextTick -> cb null, data
        catch error
          process.nextTick -> cb error, data

        logger.profile profiler_identifier
        
  # get last time the user was seen in the network
  last_activity: (player, cb = (->)) ->
    @resolveVanity player, (err, steam_id) =>
      if err
        logger.error 'unable to get last activity data', err
        return cb err, {}
        
      @profile steam_id, (err, profile) ->
        if err
          logger.error 'unable to get profile information for last_activity', err
          return cb err, {}
            
        process.nextTick -> cb null, {lastActivity: profile.lastlogoff, activity: ''}
  
  # Convert a vanity player id into a steam_id
  # If passed an actual steam_id, it will bypass
  # actually calling the API.
  resolveVanity: (player, cb = (->)) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - steam vanity (#{player}) -"
    logger.profile profiler_identifier

    # Cast the player to a string
    player = player + ''
    if player.match(/\d{17}/) 
      logger.profile profiler_identifier
      return cb null, player
    else
      if _.has steam_ids, player
        logger.profile profiler_identifier
        return cb null, steam_ids[player]

      query =
        vanityurl: player
        key: @api_key
      url = @url_prefix + '/ISteamUser/ResolveVanityURL/v0001/?' + qs.stringify(query)
      Turbine 
        url: url
      , (err, res, body) ->
        if err
          logger.profile profiler_identifier
          logger.error 'unable to resolve steam vanity', err
          cb(err, '')
          return
        
        if res.code != 200
          logger.error "call error http status #{res.code}"
          return cb null, ''
        
        json = JSON.parse body
        
        if json.response.message == 'No match'
          logger.debug 'no match found, invalid steam_id'
          process.nextTick -> cb {invalid: yes}, null
        else
          steam_ids[player] = json.response.steamid
          process.nextTick -> cb null, json.response.steamid

        logger.profile profiler_identifier

# Expose the steam_api to `require` calls
exports = module.exports = new steam_api
