_ = require 'underscore'
http = require 'http'
config = require '../config'
url = require 'url'

gamertag = escape('medford 007')
game_id = 1297287339

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


describe 'XBOX Live REST API [integration test]', ->
  describe '/xbox', ->
    it "should have discovery urls", (done) ->
      request '/xbox', (err, res) ->
        err.should.be.false
        res.json.should.have.ownProperty 'urls'
        done()


  describe '/xbox/:gamertag', ->
    it "should have discovery urls", (done) ->
      request "/xbox/#{gamertag}", (err, res) ->
        err.should.be.false
        res.json.should.have.ownProperty 'urls'
        done()
  
  describe '/xbox/:gamertag/profile', ->
    it "should return profile", (done) ->
      request "/xbox/#{gamertag}/profile", (err, res) ->
        checklist = w 'gamerscore motto nickname bio presence gamertile_small'
        _.each checklist, (e) ->
          res.json[e].should.exist
        done()
  
  
  describe '/xbox/:gamertag/games', ->
    it "should return game list", (done) ->
      request "/xbox/#{gamertag}/games", (err, res) ->
        checklist = w 'gamerscore gamertile_large progress games'
        _.each checklist, (e) ->
          res.json[e].should.exist

        
        checklist = w 'id name tile total_points unlocked_points unlocked_achievements urls'
        _.each checklist, (e) ->
          res.json.games[0][e].should.exist

        res.json.games[0].urls.achievements.should.exist
        res.json.games[0].urls.product.should.be.exist

        done()
  
  describe '/xbox/:gamertag/:game_id', ->
    it "should return product details", (done) ->
      request "/xbox/#{gamertag}/#{game_id}", (err, res) ->
        checklist = w 'title boxart rating_count rating artwork downloads'
        _.each checklist, (e) ->
          res.json[e].should.exist

        
        checklist = w 'tile name rating release_date file_size description price'
        _.each checklist, (e) ->
          res.json.downloads[1][e].should.exist

        done()

  describe '/xbox/:gamertag/:game_id/achievments', ->
    it "should return achievement data", (done) ->
      request "/xbox/#{gamertag}/#{game_id}/achievements", (err, res) ->
        checklist = w 'gamertile_large percent_complete game_id achievements'
        _.each checklist, (e) ->
          res.json[e].should.exist

        
        checklist = w 'id name tile description score'
        _.each checklist, (e) ->
          res.json.achievements[1][e].should.exist

        done()

    
