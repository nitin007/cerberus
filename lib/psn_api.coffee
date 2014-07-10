Turbine = require "#{__dirname}/turbine"
CookieJar = require "#{__dirname}/cookie_jar"
Cookie = require "#{__dirname}/cookie"
jsdom = require 'jsdom'
logger = require("#{__dirname}/logger") 'playstation'
argue = require 'argue'
prettyjson = require 'prettyjson'
config = require '../config'
async = require 'async'
_ = require 'underscore'
logger.cli()

# Useful for debugging. Just a simple wrapper to
# show objects in a nice way.
puts = (d) -> console.log prettyjson.render d

# The `psn_api` connects to PSN and scrapes data
# from their site. No authentication is required
# to pull the data.
class psn_api

  # Our collection of users
  user_pool = []

  version: '0.0.3'

  # Prefix all requests with this URL
  url_prefix: 'http://us.playstation.com'  
  debug: no

  constructor: ->
    @user config.psn_users

  user: (username, password) ->
    if _.isArray username
      username = (_.defaults(user, jar: new CookieJar) for user in username)
      user_pool = _.union username, user_pool
    else
      user_pool.push name: username, password: password, jar: new CookieJar
  
  get: (args...) ->
    signature = argue args
    opts = {}

    switch signature
      # signature: '/foo'
      when 's'
        logger.error 'callback required'
        return no
      # signature: '/foo', function(){}
      when 'sf'
        opts =
          url: args[0]
          done: args[1]
      # signature: {}, function(){}
      when 'of'
        opts = _.extend args[0], {done: args[1]}
      # unknown signature
      else
        logger.error 'improper invocation'
        return no

    # A request is useless without a URL, so we return.
    unless _.has opts, 'url'
      logger.error 'url missing'
      return

    options = _.defaults opts,
      user: no
      payload: undefined
      prefix: (@url_prefix if opts.url.toLowerCase().indexOf('http') is -1) or ''
      done: (err, data) -> return

    options.url = options.prefix + options.url

    unless _.isObject options.user
      if user_pool.length > 0
        options.user = user_pool[Math.floor(Math.random() * user_pool.length)]
      else
        # While still warranting an error, its okay for the user pool
        # to be empty
        logger.error 'user pool is empty'

    # Since the USER has been found, we can set the jar.
    options.jar = options.user.jar

    Turbine options, (err, res, body) ->
      if err
        options.done err, {}, ''
        logger.error 'a psn error occured', err
        return

      if body.indexOf('loginWindow();') > -1
        logger.info 'psn login page' 
        login res, options, (err, res, body) ->
          #retry original request
          Turbine
            url: options.url
            referer: options.referer
            jar: options.jar
            form: options.form
          , options.done
      else
        logger.info 'login NOT required'
        options.done null, res, body

  login = (res, options, cb = (->)) ->

    Turbine
      url: 'https://account.sonyentertainmentnetwork.com/external/auth/login.action?request_locale=en_US&service-entity=psn&returnURL=https://us.playstation.com/uwps/PSNTicketRetrievalGenericServlet'
      jar: options.jar
    , (err, res, body) ->
      if err
        logger.error 'PSN achievement error', err
        cb err, res, body
        return
      jsdom.env
        html: body
        scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
      , (dom_err, window) ->
        if dom_err
          logger.error 'PSN achievement error', err
          cb err, res, body
          return

        $ = window.jQuery


        formData = {}
        $('#mainForm input').each ->
          name = $(@).attr('name')
          val = $(@).val()
          formData[name] = val
        formData.j_username = options.user.name
        formData.j_password = options.user.password
        puts formData

        Turbine
          url: 'https://account.sonyentertainmentnetwork.com/external/auth/login!authenticate.action'
          method: 'POST'
          jar: options.jar
          form: formData
        , (err, res, body) ->
          if err
            logger.error 'PSN achievement error', err
            cb err, res, body
            return
          Turbine
            url: body.match(/location='(.*)'/)[1]
            jar: options.jar
          , (err, res, body) ->
            if err
              logger.error 'PSN achievement error', err
              logger.profile profiler_identifier
              cb err, res, body
              return
            cb(err, res, body)
            
  profile: (profile, cb = (->)) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - psn profile_validity (#{profile}) -"
    logger.profile profiler_identifier

    if profile.match /^[-\w]{3,16}$/
      # valid profile ids must be 3-16 letters, alphanumeric, -, and _
      referer = "http://us.playstation.com/publictrophy/index.htm?onlinename=#{profile}"
      url = "http://us.playstation.com/playstation/psn/profiles/#{profile}"
      new Turbine
        url: url
        referer: referer
      , (err, res, body) ->
        jsdom.env
          html: body
          scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
        , (dom_err, window) ->
          if dom_err
            logger.profile profiler_identifier
            logger.error 'unable to get playstation profile validity', err
            return cb err, {}

          $ = window.jQuery
          data = 
            invalid: !!$('.errorSection').length
            avatar: $('#id-avatar img').attr('src')?.split('=')?.pop()
            trophy_count: $('#totaltrophies #text')?.text().trim()
            level: $('#levelprogress #leveltext')?.text().trim()
            progress: $('#trophysummary .progresstext')?.text().trim()

          process.nextTick -> cb(null, data)
          logger.profile profiler_identifier
    else
      process.nextTick -> cb(null, invalid: yes)
      logger.profile profiler_identifier

  games: (profile, cb = (->)) ->
    profiler_identifier = "[#{process.pid}] #{Date.now()} - psn games (#{profile}) -"
    logger.profile profiler_identifier
    trophies = "#{@url_prefix}/playstation/psn/profile/#{profile}/get_ordered_trophies_data"
    referer = "#{@url_prefix}/publictrophy/index.htm?onlinename=#{profile}/trophies"
    # Get the page with the proper referer
    new Turbine 
      url: trophies
      referer: referer
    , (err, res, body) ->
      if err
        logger.error 'unable to get playstation games', err
        logger.profile profiler_identifier
        return cb err, {}
      
      jsdom.env
        html: body
        scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
      , (dom_err, window) ->
        if dom_err
          logger.profile profiler_identifier
          logger.error 'unable to get playstation games', err
          return cb err, {}

        $ = window.jQuery
        data = []


        # each slotContent contains all the data we need
        $('.slotcontent').each (i, e)->
          apiname = $(e).find('.gameTitleSortField').parent('a').attr('href')?.split('/').pop()
          data.push 
            apiname: apiname
            appid: apiname?.split('-').shift() 
            tile: $(e).find('.titlelogo img').attr('src')
            name: $(e).find('.gameTitleSortField').text()?.trim()
            progress: $(e).find('.gameProgressSortField').text()?.trim()
            trophies: 
              total: $(e).find('.gameTrophyCountSortField').text()?.trim()
              bronze: $(e).find('.trophyholder .trophycount:first').text()?.trim()
              silver: $(e).find('.trophyholder .trophycount:nth-child(2)').text()?.trim()
              gold: $(e).find('.trophyholder .trophycount:nth-child(3)').text()?.trim()
              platinum: $(e).find('.trophyholder .trophycount:nth-child(4)').text()?.trim()

        logger.profile profiler_identifier
        # Execute the callback
        process.nextTick -> cb(null, data)

  recent_games: (profile, cb = (->)) ->
    @games profile, (err, recent_games) ->
      if err
        logger.error 'unable to get playstation recent games', err
        return cb err, {}
        
      process.nextTick -> cb null, _.first(recent_games, 5)


  process_achievements: (body, cb = (->)) ->
    data = []

    jsdom.env
      html: body
      scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
    , (dom_err, window) ->
      if dom_err
        logger.error 'PSN achievement error', err
      else
        dom_err = null
        $ = window.jQuery
        $('.slot').each (index)->
          earned_date = $(@).find('.dateEarnedSortField').html()?.trim()
          data.push
            apiname: "achievement_#{index}"
            tile: $(@).find('.trophyimage img').attr 'src'
            name: $(@).find('.trophyTitleSortField').html()?.trim()
            description: $(@).find('.subtext').html()?.trim()
            earned: if earned_date then yes else no
            earned_date: if earned_date then Date.parse(earned_date) else undefined
            type: $(@).find('.trophyTypeSortField').html()?.trim().toLowerCase()
      
      # always execute the callback
      process.nextTick -> cb dom_err, data
  
  smart_achievements: (profile, apiname, cb = (->)) ->
    achievements = "#{@url_prefix}/playstation/psn/profile/#{profile}/get_ordered_title_details_data"
    referer = "#{@url_prefix}/playstation/psn/#{profile}/trophies/#{apiname}"
    if user_pool.length > 0
      user = user_pool[Math.floor(Math.random() * user_pool.length)]
      jar = user.jar
    else
      # While still warranting an error, its okay for the user pool
      # to be empty
      logger.error 'user pool is empty'
      # Since the USER has been found, we can set the jar.
      jar = new CookieJar

    Turbine
      url: achievements
      referer: referer
      jar: jar
      method: 'POST'
      form:
        titleId: apiname
        sortBy: 'id_asc'
    , (err, res, body) ->
      if err
        logger.error 'PSN achievement error', err
        process.nextTick -> cb err, res, body
        return

      if body.indexOf('loginWindow();') > -1
        # not the page we want, do the login process
        process.nextTick -> login_achievments jar, cb
      else
        # we got the page, do a simple process
        process.nextTick -> process_achievements body, cb

  achievements: (profile, apiname, cb = (->)) ->  
    profiler_identifier = "[#{process.pid}] #{Date.now()} - psn achievements (#{profile}) -"
    logger.profile profiler_identifier

    achievements = "#{@url_prefix}/playstation/psn/profile/#{profile}/get_ordered_title_details_data"
    referer = "#{@url_prefix}/playstation/psn/#{profile}/trophies/#{apiname}"
    logger.info "achievements for #{profile} - #{apiname}"
    
    Turbine
      url: achievements
      referer: referer
      method: 'POST'
      form:
        titleId: apiname
        sortBy: 'id_asc'
    , (err, res, body) ->
      if err
        logger.error 'PSN achievement error', err
        logger.profile profiler_identifier
        cb err, {}
        return

      data = []
      
      jsdom.env
        html: body
        scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
      , (dom_err, window) ->
        if dom_err
          logger.error 'PSN achievement error', err
          logger.profile profiler_identifier
          cb err, {}
          return

        $ = window.jQuery
        $('.slot').each (index)->
          earned_date = $(@).find('.dateEarnedSortField').html()?.trim()
          data.push
            apiname: "achievement_#{index}"
            tile: $(@).find('.trophyimage img').attr 'src'
            name: $(@).find('.trophyTitleSortField').html()?.trim()
            description: $(@).find('.subtext').html()?.trim()
            earned: if earned_date then yes else no
            earned_date: if earned_date then Date.parse(earned_date) else undefined
            type: $(@).find('.trophyTypeSortField').html()?.trim().toLowerCase()
        logger.info "Achievements for # for #{apiname} #{data.length}"
        process.nextTick -> cb(null, data)

  # get last time the user was seen in the network
  last_activity: (profile, cb = (->)) ->
    @profile profile, (err, pdata) ->
      if err
        logger.error 'unable to get playstation profile', err
        return cb err, {}
        
      process.nextTick -> cb null, {level: pdata.level, progress: pdata.progress}
  
exports = module.exports = new psn_api
