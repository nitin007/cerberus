# `xbox_page` creates requests and authenticates
# as needed. It can utilize a pool of users,
# which helps hide our activities.

_ = require 'underscore'
jsdom = require 'jsdom'
config = require '../config'
winston = require 'winston'
prettyjson = require 'prettyjson'

Turbine = require "#{__dirname}/turbine"
CookieJar = require "#{__dirname}/cookie_jar"

winston.cli()
# Useful for debugging. Just a simple wrapper to
# show objects in a nice way.
puts = (d) -> console.log prettyjson.render d

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

class xbox_page
  # A collection for our user pool
  user_pools =
    gold: []
    silver: []

  # Prefix all requests with this URL
  url_prefix: 'https://live.xbox.com'
  debug: no

  constructor: ->
    @user config.users

  # Add a user to the pool
  # If the first argument is an array (of user objects)
  # push each one into the user_pool without duplicates.
  user: (username, password, gold = no) ->
    if _.isArray username
      username = (_.defaults(user, jar: new CookieJar) for user in username)
      
      users = 
        gold: _.filter(username, (u) -> _.has(u, 'gold') and u.gold?)
        silver: _.reject(username, (u) -> _.has(u, 'gold') and u.gold?)

      user_pools.gold   = _.union user_pools.gold, users.gold
      user_pools.silver = _.union user_pools.silver, users.silver
    else
      pool = if gold? then user_pools.gold else user_pools.silver
      pool.push name: username, password: password

  
  get: (args...) ->
    default_options =
      gold: no
      user: no
      payload: undefined

    # called: xbox_page.request 'http://example.com'
    console.log args
    if args.length is 1 and _.isString args[0]
      return winston.error 'callback required'
    else if args.length is 2 and _.isFunction args[1]
      # called: xbox_page.request 'http://example.com', (err, res, body) ->
      if _.isString args[0]
        opts = 
          url: args[0]
          done: args[1]
      # called: xbox_page.request url: 'http://example.com', (err, res, body) ->
      else if _.isObject args[0]
        opts = _.extend args[0], {done: args[1]}
      else
        winston.error 'improper invocation'
        return no
    else
      return no

    unless _.has opts, 'url'
      winston.error 'missing a url'

    options = _.defaults opts,
      gold: no
      user: no
      payload: undefined
      prefix: (@url_prefix if opts.url.toLowerCase().indexOf('http') is -1) or ''     
      done: (err, data) -> return

    options.url = options.prefix + options.url

    # To help confound XBOX Live, we select a user from our
    # `user_pool` at random. We detect the type of account needed,
    # and select from that pool.
    unless _.isObject options.user
      type = ('gold' if options.gold) or 'silver'
      pool = user_pools[type]

      if pool.length > 0
        options.user = pool[Math.floor(Math.random() * pool.length)]
      else
        winston.error 'user pool is empty'
    
    # Since the USER has been found, we can set the jar.
    options.jar = options.user.jar

    # Spin up a `Turbine` and get it all going.
    Turbine options, (err, res, body) ->
      if err
        options.done err, {}, ''
        winston.error 'error occurred', err
        return

      if isLoginPage(res)
        #!winston.info 'login page'
        login options, res, body
      else
        process.nextTick -> options.done(null, res, body)


  # #Private Methods

  # The title of the login page is fairly standard. This
  # lets us determine if a login is required, since we'll
  # only get this title on Login pages.
  isLoginPage = (res) ->
    title = _.getTitle res
    # `title` may not exist
    title? and title.toLowerCase() is 'sign in to your microsoft account'

  # ## Authenticating with XBOX Live
  # Authentication is a multi-step process since Microsoft
  # frowns on accessing their site(s) in any automated way.
  login =(options, res, body) ->
    #!winston.info 'attempting login (1) as', options.user.name
    
    SCRIPT_DATA = ///
      <script[^>]*> # opening script tag
      \s*var\s+ServerData\s+= # the proper block
      (.*)  # all the junk
      </script> #closing tag
    ///

    scripts = body.match(SCRIPT_DATA)[1]
    scripts = scripts.split('</script>')
    serverData = scripts[0].replace(/;$/, '');
    
    

    # Our target page is stored as a javascript variable.
    loginPostUrl = serverData.match(/urlPost:\s*'([^']*)',/)[1]

    # PPFT appears to be some kind of session identifier which is
    # required for the login process.

    ppft_html = serverData.match(/sFTTag:\s*'([^']*)',/)[1]
    ppft = ppft_html.match(/value="([^"]+)/)[1]

    Turbine
      url: loginPostUrl
      method: 'post'
      jar: options.jar
      form:
        login: options.user.name
        passwd: options.user.password
        # These are strange constants that are required by
        # the form.
        type: '11'
        LoginOptions: '3'
        NewUser: '1'
        PPSX: 'Passpor'
        PPFT: ppft
        idshbo: '1'
        SI: "Sign In"
    , (err, res, body) ->
      # The login will "fail" and return a page saying that 
      # Javascript must be enabled. However, there is a 
      # hidden form in the page that can be
      # submitted to enable non-javascript support.
      #
      # Submitting the form on the Javascript error page 
      # completes the login process, and SHOULD 
      # return the originally requested page.
      #
      # This is used to help confound simple scrapers. We collect
      # all the variables and form elements, and submit the page
      # directly.
      if err then return winston.error 'nope'
      #!winston.debug 'attempting login (2) as', options.user.name

      jsdom.env
        html: body
        scripts: ['http://cdnjs.cloudflare.com/ajax/libs/jquery/1.7.2/jquery.min.js']
      , (dom_err, window) ->
        if dom_err then return winston.error 'dom error', dom_err
        $ = window.jQuery

        title = $('title')?.text()?.toLowerCase()
        
        if title is 'continue'
          $form = $('#fmHF')
          Turbine
            url: $form.attr('action')
            method: 'post'
            jar: options.jar
            form:
              NAP: $form.find('#NAP').val()
              ANON: $form.find('#ANON').val()
              t: $form.find('#t').val()
          , (err, res, body) ->

            if err then return winston.error 'nope nope'
            process.nextTick -> options.done(null, res, body)

          
 
# Export an instance of our `xbox_page` module
exports = module.exports = new xbox_page
