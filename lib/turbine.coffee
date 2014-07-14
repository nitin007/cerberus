url = require 'url'
winston = require 'winston'
_ = require 'underscore'
http = require 'http'
https = require 'https'
querystring = require 'querystring'

Cookie = require "#{__dirname}/cookie"
CookieJar = require "#{__dirname}/cookie_jar"


winston.cli()

# Turbine is a replacement for `Engine`. Unlike `Engine`,
# Turbine exports the class, not an instance of the class.
# Also, each Turbine request is a new request, only
# using data that is explicity provided. This helps eliminate
# "cross talk" of objects and cookies.
#
# Turbine will follow redirects and automatically switch between
# HTTP and HTTPS. It *does not* check that a secure certificate
# is valid, so MITM attacks are possible.
#
# Even though the coffeescript idiom `class` this is just a function
# that will have prototyped methods and variables. The idiom is used
# here for clarity, but this shouldn't be invoked as `new Turbine`
# since that will create a whole new copy and doesn't really help much.
# Also, doing so is a potential for a memory leak in our primary
# application.

class Turbine
  # #Private Variables
  default_options =
    # Individial HTTP Request timeout
    timeout: 10000
    # Most of these are how Turbine is identified to servers
    headers:
      'Accept': '*/*'
      'Accept-Charset': 'ISO-8859-1,utf-8;q=0.7,*;q=0.7'
      # Look like Safari on Lion
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/534.55.3 (KHTML, like Gecko) Version/5.1.3 Safari/534.53.10'
      'Connection': 'keep-alive'
      'Keep-Alive': 300
      'Accept-Encoding': 'identity'
      'Accept-Language': 'en-us,en;q=0.5'
    url: undefined
    # One of your standard HTTP verbs
    method: 'GET'
    # Sets `payload` to a querystring representation of the value
    # and adds `Content-type: application/x-www-form-urlencoded; charset=utf-8`
    # header
    form: undefined
    # Sets `payload` to a JSON representation of the value and
    # adds the `Content-type: application/json` header
    json: undefined
    # Used internally to store the post data
    payload: undefined
    # Follow HTTP 3xx responses as redirects
    followRedirect: yes
    # When supplied, sets the `Referer` header. This is automatically set
    # during redirects
    referer: undefined
    # The tally of used redirects
    redirects: 0
    # Max number of redirects to follow
    redirectLimit: 10
    # Supplying an instance of `CookieJar` to store cookies
    jar: new CookieJar
    # Used internally to store the callback
    success: (err, res, body) -> return

  # The response in the callback will follow this format
  default_response =
    code: undefined
    headers: {}
    url: {}
    body: ''

  # It's good form to not put all your logic in the constructor.
  constructor: (args...) ->
    request args

  # #The Turbine Core
  # This is the part of Turbine that actually does all the work.
  request = (args) ->
    
    # ## Argument Initialization

    # called: Turbine
    return no unless args?

    # called: Turbine 'http://example.com'
    if args.length is 1 and _.isString args[0]
      req = _.defaults {url: args[0]}, default_options

    else if args.length is 2 and _.isFunction args[1]
      # called: Turbine 'http://example.com', (err, res, body) ->
      if _.isString args[0]
        req = _.defaults {url: args[0], success: args[1]}, default_options

      # called: Turbine url: 'http://example.com', (err, res, body) ->
      else if _.isObject args[0]
        req = _.extend args[0], {success: args[1]}
        req = _.defaults req, default_options
      else
        winston.error 'improper invocation'
        return no
    else
      return no

    # we're done figuring out the parameters
    req.method = req.method.toUpperCase()

    #!winston.info "requesting (#{req.method}) #{req.url[0..50]}..."
    #winston.error ">>> #{req.url} - #{querystring.stringify(req.form)}"
    
    # ## Payload Creation
    # Supplying both `form` and `json` is silly. If you do,
    # the `json` will be used instead.
    if req.form?
      req.payload = querystring.stringify(req.form)
      req.headers = _.extend req.headers,
        'Content-Length': req.payload.length
        'Content-Type': 'application/x-www-form-urlencoded'
    if req.json?
      req.payload = JSON.stringify req.json
      req.headers = _.extend req.headers,
        'Content-Length': Buffer.byteLength(req.payload, 'utf8')
        'Content-Type': 'application/json'

    # ## Cookies and other Metadata
    # This relies pretty heavily on the `CookieJar` module
    cookies = req.jar.cookieString(req)
    if cookies?
      req.headers = _.extend req.headers,
        Cookie: cookies

    # Add the referer header if it exists; redirects will
    # set this automatically
    if req.referer?
      req.headers = _.extend req.headers, 
        Referer: req.referer

    req.parsed_url = url.parse req.url

    # Some servers and services check against the `Host` header
    # so we need to make sure it exists.
    req.headers = _.extend req.headers,
      host: req.parsed_url.host

    # These options are the ones passed to the `HTTP` or `HTTPS`
    # module. Setting `agent` to `no` disables socket pooling which
    # would limit us to having 5 sockets max.
    req.options =
      host: req.parsed_url.hostname
      port: req.parsed_url.port
      path: req.parsed_url.path
      method: req.method
      headers: req.headers
      agent: no

    # We really, really want to make sure that these headers are
    # not set. Web servers tend to sit around and wait until they
    # receive all the data as noted by the `Content-Length` but
    # since it is a `GET`, we don't send any.
    if req.method is 'GET'
      delete req.options.headers['Content-Length']
      delete req.options.headers['Content-Type']

    # Detect which module to use based on the URL and switch
    # it as needed. The module is cloned rather than simply assigned
    # to keep references to the original module intact.
    if req.parsed_url?.protocol?.toLowerCase().indexOf('https') is -1
      engine = _.clone http
    else
      engine = _.clone https
      #!winston.debug 'using SSL'

    # ##Perform the Request
    # After detecting the correct module to use, preparing
    # headers, and all other setup, we can *finally* make an
    # actual request.
    req.req = engine.request req.options, (res) =>

      # Prepare a new instance of the default response.
      # Cloned so we're copying rather than using a reference.
      response = _.clone default_response      
      
      response.headers = res.headers
      response.code = res.statusCode

      # Build the `body` as we receive `data`
      res.on 'data', (data) -> response.body += data

      # All data has been received, we can start processing
      # everything.
      res.on 'end', =>
        # `engine` is a clone of `http` or `https`; since it is no
        # longer needed and since next time we'll just clone it again
        # delete it here.
        # delete engine
        engine = null

        # This functionality is brought to you by the `Cookie` module.
        if _.has response.headers, 'set-cookie'
          #!winston.debug 'setting cookies'
          for cs in response.headers['set-cookie']
            req.jar.add new Cookie cs, req

        # Share the request (and all of its settings/data) with 
        # the callback.
        response.req = req

        # ### Redirect Handler
        if response.code in [301, 302, 303, 304, 305, 307]

          # sometimes location is a relative url, /foo/bar
          if response.headers.location.indexOf('http') is -1
            response.headers.location = "#{req.parsed_url.protocol}//#{req.parsed_url.host}#{response.headers.location}"
          
          if req.redirects < req.redirectLimit
            req.redirects += 1
            #!winston.debug "redirecting (#{req.redirects} / #{req.redirectLimit})", response.headers.location

            # Now that we know where to go, spin up a new Turbine.
            # The `maxRedirects` directive helps prevent an infinite loop.
            # Using `process.nextTick` makes sure that the redirect goes async
            process.nextTick ->
              Turbine 
                url: response.headers.location
                referer: response.headers.location
                followRedirect: req.followRedirect
                redirects: req.redirects
                redirectLimit: req.redirectLimit
                jar: req.jar
              , req.success

              # response was cloned, delete it since we're done.
              # delete response
              response = null
          else
            winston.error 'too many redirects'
            process.nextTick -> 
              req.success {error: 'Too Many Redirects'}, response, response.body
              # response was cloned, delete it since we're done.
              response = null
              # delete response
        else
          process.nextTick -> 
            req.success null, response, response.body
            # response was cloned, delete it since we're done.
            response = null
            # delete response
      
    req.req.setTimeout req.timeout
    req.req.on 'error', (e) ->
      winston.error 'something went wrong', e
      process.nextTick -> req.success e, {}, ''

    # Methods other than `GET` support having content in their bodies.
    unless req.method is 'GET'
      #!winston.debug "writing data" if req.payload?
      req.req.write "#{req.payload}\n" if req.payload?

    # Like all good things, even our request must end.
    req.req.end()

# Export Turbine for use as a module.
exports = module.exports = Turbine
