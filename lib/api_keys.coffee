# The `api_keys` middleware just checks the headers
# and optionally the query string for the valid
# api key as defined in the configuration file.
#
# To authenticate via headers (ideal) include the
# `intergi-api-key` with its value as your API key.

config = require '../config'

module.exports = (req, res, next) ->
  if (config.allow_query_key and req.param('key') is config.api_key) or req.header('intergi-api-key') is config.api_key
    next()
  else
    # 401 Authentication Required
    res.send 401