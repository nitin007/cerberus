xbox_page = require "#{__dirname}/xbox_page"
querystring = require 'querystring'
jsdom = require 'jsdom'
_ = require 'underscore'
prettyjson = require 'prettyjson'
Turbine = require "#{__dirname}/turbine"
require 'datejs'
logger = require("#{__dirname}/logger") 'xbox'

# Add any helpers here
_.mixin
  w: (string) -> string.split ' '
  # Determine the page title of a given page.
  getTitle: (res) ->
    output = ''

    # Handle the response object vs body element
    if typeof res is 'object'
      body = res.body
    else
      body = res

    # If anything was actually found...
    if body?
      title = body.match(/<title>([^<]*)<\/title>/)
      if title? and title.length > 0
        output = title[1]
    
    return output
  
  parseActivity: (mtime) ->
    reg = /Last seen (.+) playing (.*)/
    ret = {lastActivity: '', activity: ''}

    if !mtime
      return ret
          
    ptime = mtime.match(reg)
    
    if ptime
      new_time = Date.parse ptime[1].replace(/^a/, 1)
      ret.lastActivity = parseInt(new_time.getTime() / 1000)
      ret.activity = ptime[2]
    else
      ret = ''
    
    return ret
  
# This `xbox_api` connects to and scrapes data from
# XBOX Live. It will handle authentication, and can
# even accept a pool of users for authenticated
# requests.
class xbox_api

  version: '0.1.0'
  debug: no
  
  # Create the user pool with as little as one user.
  # To create an actual user pool, the first parameter
  # should be an array of objects, with `name`, `password`, `gold`
  # keys.
  #
  #     [{name: 'test@example.com', password: '12345', gold: true}, {...}, {...}]
  #
  # This can be called as many times as needed, but the alternate
  # outlined above is probably easier.
  connect: (username, password = 'splinter', gold = no) ->
    xbox_page.user username, password, gold
    return

  # Retrieve the profile information for a given gamertag, which is:
  #
  # * gamertag
  # * gamerscore
  # * motto (if set, otherwise empty)
  # * avatar (url to the image)
  # * nickname (if set, otherwise empty)
  # * bio (if set, otherwise empty)
  # * presence (most recent entry)
  # * gamertile_small (url to the image)
  #
  # The callback should receive two arguments, `err` and `data`.
  # `err` will be `null` unless there is an error.
  profile: (gamertag, cb = (->), retries=0) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - xbox profile (#{gamertag}) -"
    logger.profile profiler_identifier

    url = '/en-US/Profile?' + querystring.stringify gamertag: gamertag
    
    # Here we use the `request` module, since it appears
    xbox_page.get 
      url: url
      gold: no
    , (err, res, body) ->
      
      if _.getTitle(res).toLowerCase() == 'page not found - xbox.com'
        data = {
          gamertag: gamertag
          invalid: yes
        }
        logger.profile profiler_identifier
        process.nextTick -> cb(null, data)
        return


      if err
        logger.profile profiler_identifier
        logger.error 'unable to get profile', prettyjson.render err
        process.nextTick -> cb(err, {})
        return

      logger.info "Getting #{url}"
      # Create the DOM with jQuery
      jsdom.env
        html: body
        scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
      , (dom_err, window) ->
        if dom_err
          logger.profile profiler_identifier
          logger.error 'unable to get profile', prettyjson.render err
          process.nextTick -> cb(err, {})
          return

        $ = window.jQuery

        # Unfortunately, all of this data is entirely
        # DOM dependant, and a source of future failure.
        data =
          gamertag: gamertag
          gamerscore: $('div.gamerScore[name!=MeBarGamerScore]').text()?.trim()
          motto: $('div.motto').text()?.trim()
          avatar: $('.xbox360Avatar img').attr('src')
          nickname: $('div.name div.value').text()?.trim()
          bio: $('div.bio div.value').text()?.trim()
          presence: $('.contextRail div.presence').text()?.trim()
          gamertile_small: $('img.gamerpic:first').attr('src')

        # Execute the callback
        logger.profile profiler_identifier
        process.nextTick -> 
          cb(null, data)
          return
        return
      return

    return

  # Retrieve the games for a given gamertag
  #
  # The callback should receive two arguments, `err` and `data`.
  # `err` will be `null` unless there is an error.
  games: (gamertag, cb = (->), retries = 0) ->

    profiler_identifier = "[#{process.pid}] #{Date.now()} - xbox games (#{gamertag}) -"
    logger.profile profiler_identifier

    url = '/en-US/Activity?' + querystring.stringify compareTo: gamertag
    xbox_page.get 
      url: url
      gold: no
    , (err, res, body) =>
      if err
        logger.profile profiler_identifier
        logger.error 'unable to get games', prettyjson.render err
        cb(err, {})
        return

      logger.info "Getting #{url}"
      # Create the DOM with jQuery
      jsdom.env
          html: res.body
          scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
        , (dom_err, window) =>
          if dom_err
            logger.profile profiler_identifier
            logger.error 'unable to get games', prettyjson.render err
            cb(err, {})
            return

          $ = window.jQuery


          # The token is a unique identifier that comes directly
          # from the page. Whenever communicating directly
          # with Microsoft's "internal" API, this token is needed.
          token = $('input[name=__RequestVerificationToken]').val()

          # Communicating directly with the "internal" API
          # gives us straight JSON, making things simpler.
          url = '/en-US/Activity/Summary'
          payload =
            '__RequestVerificationToken': token
            'compareTo': gamertag

          Turbine
            url: xbox_page.url_prefix + url
            method: 'post'
            form: payload
            jar: res.req.jar
          , (err, res, body) =>
            if err
              logger.profile profiler_identifier
              logger.error 'unable to get games', prettyjson.render err
              process.nextTick -> cb(err, {})
              return

            if _.getTitle(res).toLowerCase() == 'runtime error'
              logger.profile profiler_identifier
              logger.error 'xbox live unavailable', prettyjson.render err
              process.nextTick -> cb({code: 503, msg: 'xbox live unavailable'}, {})
              return

            json = JSON.parse(body)
            game_data = json?.Data
            data = {}
            if game_data?
              data = 
                data: game_data
                gamertag: game_data.Players[0].Gamertag
                gamertile_large: game_data.Players[0].Gamerpic
                gamerscore: game_data.Players[0].Gamerscore
                progress: game_data.Players[0].PercentComplete
                games: []

              # The game list can be polluted with games that belong
              # to the user that we are authenticated as, hence the filtering
              game_list = _.filter game_data.Games, (item) -> 
                item.Progress[data.gamertag].LastPlayed?
              
              # Once the list has been filtered, we can collect the games
              for game in game_list
                data.games.push
                  appid: game.Id
                  apiname: game.Id
                  name: game.Name
                  tile: game.BoxArt
                  total_points: game.PossibleScore
                  unlocked_points: game.Progress[data.gamertag].Score
                  unlocked_achievements: game.Progress[data.gamertag].Achievements
              
              # Execute the callback
              logger.profile profiler_identifier
              process.nextTick -> 
                cb(null, data.games)
                return
              return
            
            else
              # `game_data` is empty, so we retry a few times
              # just because we can.
              if retries < 5
                retries += 1
                logger.info "empty game data, retrying (attempt #{retries})"
                process.nextTick => 
                  @games gamertag, cb, retries

                  return
              else
                # Finally, we can give up and bubble the error
                # to the callback.

                game_err =
                  code: 502
                  message: 'Unable to get games from XBOX Live'
                logger.error prettyjson.render game_err
                logger.profile "xbox games (#{gamertag})"
                process.nextTick -> 
                  cb(game_err: err, {})
                  return
                return
              return
          return
        return
      return
    return
            
  # Retrieve the recent games for a given gamertag
  # similar to games implementation, the default sort order is "Recently Played"
  # 
  # This needs to be made "smarter" but it should work for now.
  #
  # The callback should receive two arguments, `err` and `data`.
  # `err` will be `null` unless there is an error.
  recent_games: (gamertag, cb = (->), retries = 0) ->
    @games gamertag, (err, recent_games) ->
      if err
        logger.error 'unable to get xbox recent games', err
        return cb err, {}
        
      process.nextTick -> cb null, _.first(recent_games, 5)


  # Retrieve the achievements for a given gamertag and game_id
  # The only real limitation here, is that the achievement icons
  # will all be in black and white since our user probably hasn't
  # actually earned these achievements.
  #
  # The callback should receive two arguments, `err` and `data`.
  # `err` will be `null` unless there is an error.
  achievements: (gamertag, game_id, cb = (->), retries = 0) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - xbox achievements (#{gamertag}) -"
    logger.profile profiler_identifier

    payload = 
      titleId: game_id
      compareTo: gamertag
    url = '/en-US/Activity/Details?' + querystring.stringify(payload)
    xbox_page.get 
      url: url
      gold: yes
    , (err, res, body) =>
      if err
        logger.profile profiler_identifier
        logger.error 'unable to get achievements', prettyjson.render err
        process.nextTick -> cb(err, {})
        return

      Turbine
        url: xbox_page.url_prefix + url
        jar: res.req.jar
      , (err, res, body) =>
        if err
          logger.profile profiler_identifier
          logger.error 'unable to get achievements', prettyjson.render err
          process.nextTick -> cb(err, {})
          return

        logger.info "Getting #{url}"
        # The data is actually JSON that is passed directly to
        # a function in the HTML. Unfortunately, there doesn't
        # seem to be a simple way to get this data directly other
        # than using a regular expression.
        achievement_data = body.match(/routes\.activity\.details\.load, (.*)\)\;/)
        data = {}
        
        if achievement_data?
          achievement_data = JSON.parse achievement_data[1]
          data =
            data: achievement_data
            gamertag: achievement_data.Players[0].Gamertag
            gamertile_large: achievement_data.Players[0].Gamerpic
            game_count: achievement_data.Players[0].gamecount
            percent_complete: achievement_data.Players[0].PercentComplete
            game_id: game_id
            achievements: []

          for achievement in achievement_data.Achievements

            data.achievements.push  
              id: achievement.Id
              apiname: "achievement_#{achievement.Id}"
              name: achievement.Name
              tile: achievement.TileUrl
              description: achievement.Description
              score: achievement.Score
              hidden: achievement.IsHidden
              earned: _.has(achievement.EarnDates, data.gamertag)
              earned_date: if _.has(achievement.EarnDates, data.gamertag)  
                  achievement.EarnDates[data.gamertag].EarnedOn.replace('/Date(', '').replace(')/', '')
                else undefined
          
          # Execute the callback
          logger.profile profiler_identifier
          process.nextTick -> 
            cb(null, data.achievements)
            return
          return

        else
          if retries < 10
            retries += 1
            logger.info "empty achievement data, retrying (attempt #{retries})"
            process.nextTick => 
              @achievements gamertag, game_id, cb, retries
              return
            return
          else
            ach_err =
              code: 502
              message: 'Unable to get achievements from XBOX Live'
            logger.error prettyjson.render ach_err
            logger.profile profiler_identifier
            process.nextTick -> 
              cb(ach_err: err, data)
              return
          return
        return
      return
    return
        
      

  # Retrieve the product detauls for a given game_id.
  # This includes available downloads, their costs, and ratings.
  #
  # The callback should receive two arguments, `err` and `data`.
  # `err` will be `null` unless there is an error.
  product: (game_id, cb =(->), retries = 0) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - xbox product (#{game_id}) -"
    logger.profile profiler_identifier

    url = "http://marketplace.xbox.com/en-US/Title/#{game_id}"
    xbox_page.get 
      url: url
      gold: no
    , (err, res, body) =>
      if err
        logger.profile profiler_identifier
        logger.error 'unable to get product', prettyjson.render err
        process.nextTick -> cb(err, {})
        return
      # We get forwarded to a product page, and from there we can make our real request
      
      logger.info "Getting #{url}"
      
      # If the response isn't what we expect, try again 
      # several times before giving up.
      unless _.has res.req, 'url'
        if retries < 5
          retries += 1
          logger.info "missing actual product url, retrying (attempt #{retries})"
          process.nextTick => @product game_id, cb, retries
          return
        else
          prod_err =
            code: 502
            message: 'Unable to get product from XBOX Live'
          logger.error prettyjson.render prod_err
          logger.profile profiler_identifier
          process.nextTick -> cb(prod_err: err, {})
          return
      
      logger.debug 'read landing page, attempting actual product page' if @debug
      xbox_page.get 
        url: res.req.url + '?nosplash=1&page=1&PageSize=500'
      , (err, res, body) ->
        if err
          logger.profile profiler_identifier
          logger.error 'unable to get product', prettyjson.render err
          process.nextTick -> cb(err, {})
          return

        logger.debug 'reached actual product page' if @debug
        jsdom.env
            html: body
            scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
          , (dom_err, window) ->
            if dom_err
              logger.profile profiler_identifier
              logger.error 'unable to get games', prettyjson.render err
              cb(err, {})
              return

            $ = window.jQuery

            # A simple helper to convert star ratings to numbers 0-5
            calculate_stars = (stars) ->
              rating = 0
              if stars
                rating += $(stars).find('.Star.Star4').length
                rating += $(stars).find('.Star.Star3').length * 0.75
                rating += $(stars).find('.Star.Star2').length * 0.5
                rating += $(stars).find('.Star.Star1').length * 0.25

              return rating

            data =
              title: $('#gameDetails h1').text()
              boxart: $('#ProductTitleZone .ProductBox img').attr('src') or ''
              rating_count: $('#ProductTitleZone .UserRatingStarStrip:first .ratingCount').text()?.replace(',','')
              rating: calculate_stars $('#ProductTitleZone .UserRatingStarStrip:first .UserRating')
              artwork: []
              downloads: []
            
            # Gather the artwork images
            $('#MediaControl .TabPage img:not(.Banner):not(.boxart)').each (i,e) ->
              data.artwork.push $(e).attr('src')
            
            # Gather the downloads
            $('ol.RelatedTiles li.firstgridchild').each (i,e)->
              download =
                tile: $(e).find('.RelatedIcon img').attr('src')
                name: $(e).find('h2 a').text()?.trim()
                rating: calculate_stars $(e).find('.UserRatingStarStrip:first .UserRating')
                rating_count: $(e).find('.UserRatingStarStrip:first .ratingCount').text()?.trim()
                release_date: $(e).find('.ReleaseDate').html()?.replace(/<label>.*<\/label>/, '').trim()
                file_size: $(e).find('.FileSize').html()
                description: $(e).find('.ProductDescription').text()?.trim()
                price: $(e).find('.ProductPrices .ProductPrice:first').text()

              # Here we have a collection of fixes to make the data more uniform
              
              download.price = 0 if download.price.toLowerCase() is 'free'
              download.description = '' if download.description.toLowerCase() is 'download this avatar item.'

              unless download.tile?
                download.tile = $(e).find('.RelatedIcon span').attr('title')

              if download.file_size?
                download.file_size = download.file_size?.replace(/<label>.*<\/label>/, '').trim()

              # With all that done, push the download into the data
              data.downloads.push download
            
            # Execute the callback
            logger.profile profiler_identifier
            process.nextTick -> cb(null, data)


  # Retrieve the list of friends from a gametag
  #
  # The callback should receive two arguments, `err` and `data`.
  # `err` will be `null` unless there is an error.
  friends: (gamertag, cb = (->), retries = 0) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - xbox friends (#{gamertag}) -"
    logger.profile profiler_identifier
    
    xbox_page.get
      url: "/en-US/Friends?" + querystring.stringify(gamertag: gamertag)
      gold: no
    , (err, res, body) =>
      
      if err
        logger.profile profiler_identifier
        logger.error 'unable to get friends', prettyjson.render err
        cb(err, {})
        return
      
      jsdom.env
        html: body
        scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
      , (dom_err, window) =>
        
        if dom_err
          logger.profile profiler_identifier
          logger.error 'unable to get friends(dom)', prettyjson.render dom_err
          cb(dom_err, {})
          return
          
        token = window.jQuery('input[name=__RequestVerificationToken]').val()
        payload =
          '__RequestVerificationToken': token
          'gamertag': gamertag
        
        Turbine
          url: xbox_page.url_prefix + '/en-US/Friends/List'
          method: 'post'
          form: payload
          jar: res.req.jar
          headers:
            'X-Requested-With': 'XMLHttpRequest'
        , (err, res, body) =>        
        
          if err
            logger.profile profiler_identifier
            logger.error 'unable to get friends(dom,turbine)', prettyjson.render err
            process.nextTick -> cb(err, {})
            return
        
          if body == ''
            logger.profile profiler_identifier
            logger.error 'unable to get friends(dom,turbine) - blank body'
            process.nextTick -> cb(err, {})
            return
        
          json = JSON.parse(body)
          
          unless json.Success
            logger.profile profiler_identifier
            logger.error 'unable to get friends(dom,turbine) - blank body'
            process.nextTick -> cb({code: 502, message: 'Error on json'}, {})
            return
          
          json_friends = json.Data.Friends
          jfriends = []
          
          if json_friends?
            for friend in json_friends
              jfriends.push
                gamertag: friend.GamerTag
                avatar: friend.LargeGamerTileUrl
                game_score: friend.GamerScore
              
            logger.profile profiler_identifier
            process.nextTick -> cb(null, jfriends)
            return
            
          else
            if retries < 5
              retries += 1
              logger.info "Empty friends data, retrying ##{retries}"
              process.nextTick =>
                @friends gamertag, cb, retries
                return
            else
              ferr =
                code: 502
                message: 'Unable to get friends from Xbox Live'
              
              logger.error prettyjson.render ferr
              logger.profile "xbox friends (#{gamertag})"
              process.nextTick -> cb(ferr, {})
              return
            
        return
      return
    return
  
  
  # get last time the user was seen in the network
  last_activity: (gamertag, cb = (->), retries = 0) ->
    @profile gamertag, (err, profile)=>
      if err
        logger.error 'unable to get profile information for last activity data', err
        return cb err, {}
      
      console.log profile
      process.nextTick -> cb null, _.parseActivity(profile.presence)
      
# Expose the xbox_api to `require` calls
module.exports = new xbox_api
