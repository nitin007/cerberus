url = require 'url'

Cookie = exports = module.exports = (str, req) ->
  @str = str
  str.split(RegExp(" *; *")).reduce ((obj, pair) ->
    p = pair.indexOf("=")
    key = (if p > 0 then pair.substring(0, p).trim() else pair.trim())
    lowerCasedKey = key.toLowerCase()
    value = (if p > 0 then pair.substring(p + 1).trim() else true)
    unless obj.name
      obj.name = key
      obj.value = value
    else if lowerCasedKey is "httponly"
      obj.httpOnly = value
    else
      obj[lowerCasedKey] = value
    obj
  ), this
  @expires = (if @expires then new Date(@expires) else Infinity)
  @path = (if @path then @path.trim() else (if req then url.parse(req.url).pathname else "/"))

  return @
Cookie::toString = ->
  @str