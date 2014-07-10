_ = require 'underscore'
http = require 'http'
config = require '../config'
url = require 'url'

steam_id = escape('devotedgmr17')
app_id = 8980
friendlyURL = 'TF2'

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

describe 'Steam REST API [integration test]', ->
  describe '/steam', ->
    it "should have discovery urls", (done)->
      request '/steam', (err, res) ->
        err.should.be.false
        res.json.should.have.ownProperty 'urls'
        done()

  describe '/steam/application', ->
    it "should have discovery urls", (done) ->
      request '/steam/application', (err, res) ->
        err.should.be.false
        res.json.should.have.ownProperty 'urls'
        done()

  describe '/steam/application/:app_id', ->
    it "should return news", (done) ->
      request "/steam/application/#{app_id}", (err, res) ->
        err.should.be.false
        checklist = w 'gid title url is_external_url author contents feedlabel date feedname'
        _.each checklist, (e) ->
          res.json[0][e].should.exist
        done()

  describe '/steam/:steam_id', ->
    it "should have discovery urls", (done) ->
      request '/steam/application', (err, res) ->
        err.should.be.false
        res.json.should.have.ownProperty 'urls'
        done()

  describe '/steam/:steam_id/profile', ->
    it "should return profile data", (done) ->
      request "/steam/#{steam_id}/profile", (err, res) ->
        err.should.be.false
        checklist = w 'steamid urls'
        _.each checklist, (e) ->
          res.json[e].should.exist
        done()

  describe '/steam/:steam_id/games', ->
    it "should return games", (done) ->
      request "/steam/#{steam_id}/games", (err, res) ->
        err.should.be.false
        checklist = w 'appid name urls'
        _.each checklist, (e) ->
          res.json[0][e].should.exist
        done()

  describe '/steam/:steam_id/friends', ->
    it "should return friends", (done) ->
      request "/steam/#{steam_id}/friends", (err, res) ->
        err.should.be.false
        checklist = w 'steamid urls'
        _.each checklist, (e) ->
          res.json[0][e].should.exist
        done()

  describe '/steam/:steam_id/:app_id', ->
    it "should have discovery urls", (done) ->
      request "/steam/#{steam_id}/#{app_id}", (err, res) ->
        err.should.be.false
        res.json.should.have.ownProperty 'urls'
        done()

  describe '/steam/:steam_id/:friendlyURL/achievements', ->
    it "should return achievements", (done) ->
      request "/steam/#{steam_id}/#{friendlyURL}/achievements", (err, res) ->
        err.should.be.false
        checklist = w 'apiname name description earned'
        _.each checklist, (e) ->
          res.json[0][e].should.exist
        done()




