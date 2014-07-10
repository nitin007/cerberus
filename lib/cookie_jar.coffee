url = require 'url'

class CookieJar
  cookies: []
  add: (cookie) ->
    @cookies = @cookies.filter((c) ->
      not (c.name is cookie.name and c.path is cookie.path)
    )
    @cookies.push cookie
  get: (req) ->
    path = url.parse(req.url).pathname
    now = new Date
    specificity = {}
    @cookies.filter (cookie) ->
      specificity[cookie.name] = cookie.path.length  if 0 is path.indexOf(cookie.path) and now < cookie.expires and cookie.path.length > (specificity[cookie.name] or 0)
  cookieString: (req) ->
    cookies = @get(req)
    if cookies.length
      cookies.map((cookie) ->
        cookie.name + "=" + cookie.value
      ).join "; "

exports = module.exports = CookieJar