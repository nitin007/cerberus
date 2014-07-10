_ = require 'underscore'
http = require 'http'
config = require '../config'
url = require 'url'

player_id = escape('emoboy4658')

w = (str) ->
  str.split(' ')

request = (path, cb = () ->) ->
  test_url = url.parse config.base_url + path
  http_options =
    host: test_url.hostname
    port: test_url.port
    path: test_url.path
    method: 'GET'
    headers:
      'intergi-api-key': config.api_key
  
  req = http.request http_options, (res) ->
    response =
      json: {}
      headers: res.headers
      code: res.statusCode
      url: test_url
      raw: ''
      error: no
    res.on 'data', (d) ->
      response.raw += d

    res.on 'end', ->
      if response.raw?
        response.json = JSON.parse response.raw
      cb(no, response)

  req.setTimeout 10000

  req.on 'error', (e) ->
    response =
      error: e
    cb(yes, response)

  req.end()

  return req

describe 'PSN REST API [integration test]', ->
  describe '/playstation', ->
    it "should have discovery urls", (done) ->
      request '/playstation', (err, res) ->
        err.should.be.false
        res.json.should.have.ownProperty 'urls'
        done()

  describe '/playstation/:profile_id', ->
    it "should return games", (done) ->
      request "/playstation/#{player_id}", (err, res) ->
        err.should.be.false
        
        checklist = w 'logo title progress trophies'
        _.each checklist, (e) ->
          res.json[0][e].should.be.ok

        checklist = w 'total bronze silver gold platinum'
        _.each checklist, (e) ->
          res.json[0].trophies[e].should.be.ok
        
        done()
