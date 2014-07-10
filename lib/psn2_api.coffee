util = require 'util'
request = require 'request'
each = require 'each'
async = require 'async'
jparser = require 'xml2json'
logger = require("#{__dirname}/logger") 'playstation'
logger.cli()

inspect = (data)->
  util.inspect data, {depth: null}

class PsnApi

  FirmWare: "3.70"
  #@BasicLogin  = "c7y-basic01:A9QTbosh0W0D^{7467l-n_>2Y%JG^v>o"
  #@TrophyLogin = "c7y-trophy01:jhlWmT0|:0!nC:b:#x/uihx'Y74b5Ycx"
  BasicLogin:
    u: 'c7y-basic01'
    p: 'A9QTbosh0W0D^{7467l-n_>2Y%JG^v>o'
  
  TrophyLogin:
    u: 'c7y-trophy01',
    p: "jhlWmT0|:0!nC:b:#x/uihx'Y74b5Ycx"
  
  jids = {}
  per_page: 50
    
  getJid: (psn_user, cb)->
    if jids[psn_user]
      cb null, jids[psn_user]
      return

    urls = {
      'us': 'http://searchjid.usa.np.community.playstation.net/basic_view/func/search_jid',
      'gb': 'http://searchjid.eu.np.community.playstation.net/basic_view/func/search_jid',
      'jp': 'http://searchjid.jpn.np.community.playstation.net/basic_view/func/search_jid'
    }

    req_data =
      url: ''
      auth:
        user: @BasicLogin.u
        pass: @BasicLogin.p
        sendImmediately: false
      headers:
        'User-Agent': "PS3Community-agent/1.0.0 libhttp/1.0.0"
        'Content-Type': "text/xml; charset=UTF-8"
      body: "<?xml version='1.0' encoding='utf-8'?><searchjid platform='ps3' sv='#{@FirmWare}'><online-id>#{psn_user}</online-id></searchjid>"
    
    ueach = each(urls)
    .on 'item', (key, value, next)->
      req_data.url = value
      
      request.post req_data, (err, resp, body)->
        if err or resp.statusCode != 200
          error = if err then err else new Error("Request error. url: #{req_data.url} | Status code: #{resp.statusCode}")
          next(error)
        else
          ueach.end()
          
          response = jparser.toJson body, {arrayNotation: true, object: true}
          if response.searchjid.result != 0
            error = new Error("No result received or request error for #{psn_user}")
            cb error, null
            return
          
          logger.info "getting jid for #{psn_user}"
          jids[psn_user] = {jid: response.searchjid.jid, region: key}
          
          cb null, jids[psn_user]
          
    .on 'error', (err)->
      cb err
      
    # .on 'end', ()->
    #   console.log 'done'
    
  profile: (psn_user, cb)->
    @getJid psn_user, (err, data)=>
      if err
        cb err, null
        return
        
      req_data =
        url: "http://getprof.#{data.region}.np.community.playstation.net/basic_view/func/get_profile"
        auth:
          user: @BasicLogin.u
          pass: @BasicLogin.p
          sendImmediately: false
        headers:
          'User-Agent': "PS3Community-agent/1.0.0 libhttp/1.0.0"
          'Content-Type': "text/xml; charset=UTF-8"
        body: "<profile platform='ps3' sv='#{@FirmWare}'><jid>#{data.jid}</jid></profile>"
      
      request.post req_data, (err, resp, body)->
        if err or resp.statusCode != 200
          cb err, null
          return
        
        response = jparser.toJson body, {arrayNotation: true, object: true}
        
        if response.profile.result != 0
          error = new Error("No result received or request error for #{psn_user}")
          cb error, null
          return
          
        logger.info "Getting profile data for #{psn_user}"
        profile = response.profile
        result = 
            name: profile.onlinename
            country: profile.country
            aboutme: profile.aboutme
            avatar: profile.avatarurl.$t
            psnplus: profile.plusicon ? 0
            
        cb null, result

  games: (psn_user, cb)->
    _that = @
    @getJid psn_user, (err, data)=>
      if err
        cb err
        return
      
      @games_page data.jid, 1, (err, page)->
        if err
          cb err
          return
          
        result = total: page.total, items: page.items
        if result.total < _that.per_page
          cb null, result.items
          return
        
        total_pages = Math.ceil(result.total / _that.per_page)
        
        queue = async.queue (task, callback)->
          _that.games_page task.jid, task.page, (err, page)->
            if err
              callback(err)
              return
            
            result.items = result.items.concat(page.items)
            callback()
        , 1
        
        queue.drain = ()->
          cb null, result.items
        
        for p in [2..total_pages]
          queue.push {jid: data.jid, page: p}

  recent_games: (psn_user, cb)->
    @getJid psn_user, (err, data)=>
      if err
        cb err
        return
        
      @games_page data.jid, 1, (err, page)->
        if err
          cb err
          return
          
        cb null, page.items
  
  games_page: (jid, page, cb)->
    start = ((page - 1) * @per_page) + 1
    #console.log "page:", {jid: jid, page: page, start: start}
    req_data =
      url: "http://trophy.ww.np.community.playstation.net/trophy/func/get_title_list"
      auth:
        user: @TrophyLogin.u
        pass: @TrophyLogin.p
        sendImmediately: false
      headers:
        'User-Agent': "PS3Application libhttp/3.5.5-000 (CellOS)"
        'Content-Type': "text/xml; charset=UTF-8"
      body: "<nptrophy platform='ps3' sv='#{@FirmWare}'><jid>#{jid}</jid><start>#{start}</start><max>#{@per_page}</max></nptrophy>"

    request.post req_data, (err, resp, body)->
      if err or resp.statusCode != 200
        error = if err then err else new Error("Request error. url: #{req_data.url} | Status code: #{resp.statusCode}")
        cb error
        return
      
      response = jparser.toJson body, {arrayNotation: true, object: true}
      
      if response.nptrophy.result != 0
        error = new Error("No result games received or request error on #{page} for #{jid}")
        cb error, null
        return
        
      games = total: response.nptrophy.title, items: []
      
      info = response.nptrophy.list.info
      if info
        info = if util.isArray(info) then info else [info]
      else
        info = []
      
      for gdata in info
        games.items.push
          game_id: gdata.npcommid
          last_updated: Date.parse(gdata['last-updated']) / 1000
          trophies: gdata.types

      cb null, games

  achievements: (psn_user, game_id, cb)->
    @getJid psn_user, (err, data)=>
      if err
        cb err
        return
      
      req_data =
        url: "http://trophy.ww.np.community.playstation.net/trophy/func/get_trophies"
        auth:
          user: @TrophyLogin.u
          pass: @TrophyLogin.p
          sendImmediately: false
        headers:
          'User-Agent': "PS3Community-agent/1.0.0 libhttp/1.0.0"
          'Content-Type': "text/xml; charset=UTF-8"
        body: "<nptrophy platform='ps3' sv='#{@FirmWare}'><jid>#{data.jid}</jid><list><info npcommid='#{game_id}'><target>FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF</target></info></list></nptrophy>"

      tr_types =
        '0' : 'bronze',
        '1' : 'silver',
        '2' : 'Gold',
        '3' : 'Platinum'
      
      request.post req_data, (err, resp, body)->
        if err or resp.statusCode != 200
          error = if err then err else new Error("Request error. url: #{req_data.url} | Status code: #{resp.statusCode}")
          cb error
          return
        
        logger.info "getting achievements data for #{game_id}"

        response = jparser.toJson body, {arrayNotation: true, object: true}
        
        if response.nptrophy.result != 0
          error = new Error("No result received or request error for #{game_id}")
          cb error, null
          return
        
        trophies = response.nptrophy.list.info.trophies.trophy
        if trophies
          trophies = if util.isArray(trophies) then trophies else [trophies]
        else
          trophies = []
          
        trophs = []
        for trophy in trophies
          trophs.push {
            id: trophy.id
            earned: true
            earned_date: Date.parse(trophy.$t) / 1000
            type: tr_types[trophy.type]
          }
        
        cb null, trophs

  trophies_list: (psn_user, game_id, cb)->
    @getJid psn_user, (err, data)=>
      if err
        cb err
        return
      
      req_data =
        url: "http://www.psnapi.com.ar/ps3/api/psn.asmx/getListTrophies?sGameId=#{game_id}"
        headers:
          'User-Agent': "PS3Community-agent/1.0.0 libhttp/1.0.0"
          'Content-Type': "text/xml; charset=UTF-8"

      request.get req_data, (err, resp, body)->
        if err or resp.statusCode != 200
          cb err
          return
          
        response = jparser.toJson body, {arrayNotation: true, object: true}
        trophies = response.ArrayOfTrophy.Trophy
        if trophies
          trophies = if util.isArray(trophies) then trophies else [trophies]
        else
          trophies = []
          
        for troph in trophies
          if troph.Platform.match /ps3/
            trophies.push
              id: troph.IdTrophy
              title: troph.Title
              image: troph.Image
              description: troph.Description
              type: troph.TrophyType
              hidden: troph.Hidden
              game: troph.GameTitle

        cb null, trophies


exports = module.exports = new PsnApi()

#psn = new PsnApi()
#psn.getJid 'emoboy4658', (err, data)-> 
#psn.profile 'emoboy4658', (err, data)->
#psn.games 'emoboy4658', (err, data) ->
#psn.achievements 'emoboy4658', 'NPWR00394_00', (err, data)->
# psn.trophies_list 'emoboy4658', 'NPWR00117_00',  (err, data)->
#   if err
#     console.log "Error:", err
#   else
#     console.log "Result:", data
