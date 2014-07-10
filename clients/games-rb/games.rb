require 'rubygems'
require 'rest_client'
require 'json'


module Games

  class << self
    attr_accessor :api_key, :base_url
  end

  self.api_key = nil
  self.base_url = 'http://cerberus.gamezone.com'

  def self.api_key
    @api_key || ENV['GAMES_API_KEY']
  end

  def self.base_url
    @base_url
  end

  class Resource
    def self.api_key
      Games.api_key
    end

    def self.base_url
      Games.base_url
    end

    def self.get(path)
      url = base_url + path
      response = RestClient.get url, {"intergi-api-key" => api_key}
      JSON.parse response.body
    end
  end

  class Xbox < Resource
    def self.profile(gamertag)
      get "/xbox/#{gamertag}/profile" unless gamertag.nil?
    end

    def self.games(gamertag)
      get "/xbox/#{gamertag}/games" unless gamertag.nil?
    end

    def self.game(gamertag, game)
      get "/xbox/#{gamertag}/#{game}" unless gamertag.nil? and game.nil?
    end

    def self.achievements(gamertag, game)
      get "/xbox/#{gamertag}/#{game}/achievements" unless gamertag.nil? and game.nil?
    end
  end

  class Playstation < Resource
    def self.profile(player_id)
      get "/playstation/#{player_id}/profile" unless player_id.nil?
    end

    def self.games(player_id)
      get "/playstation/#{player_id}" unless player_id.nil?
    end

    def self.achievements(player_id, apiname)
      get "/playstation/#{player_id}/#{apiname}" unless player_id.nil? or apiname.nil?
    end
  end

  class Steam < Resource
    def self.profile(player)
      get "/steam/#{player}/profile" unless player.nil?
    end

    def self.games(player)
      get "/steam/#{player}/games" unless player.nil?
    end

    def self.recent_games(player)
      get "/steam/#{player}/games/recent" unless player.nil?
    end

    def self.friends(player)
      get "/steam/#{player}/friends" unless player.nil?
    end

    def self.achievements(player, app)
      get "/steam/#{player}/#{app}/achievements" unless player.nil? and app.nil?
    end

    def self.news(app)
      get "/steam/application/#{app}" unless app.nil?
    end

  end

end

=begin
Games.base_url = 'http://localhost:5000'
Games.api_key = 'deP3LRMR73wA3o7a'
gamertag = 'Listonosh87'
start_time = Time.now
games = Games::Xbox.games(gamertag)
puts "game list: #{Time.now - start_time}"

all_achievements_start_time = Time.now
games.each do |game|
  achievement_start_time = Time.now
  begin
    Games::Xbox.achievements(gamertag, game['apiname'])
  rescue
    Games::Xbox.achievements(gamertag, game['apiname'])
  end

  puts "achievements for #{game['name']} in #{Time.now - achievement_start_time}"
end

puts "all achievements: #{Time.now - all_achievements_start_time}"

puts "\n"

#puts Games::Xbox.achievements('indigopeak57', 1161889984)

#puts Games::Playstation.trophies('emoboy4658')

#steam_id = escape('devotedgmr17')
#app_id = 8980

#puts Games::Steam.news 8980
=end
