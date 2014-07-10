module.exports = 
  api_key: 'deP3LRMR73wA3o7a'
  allow_query_key: yes
  persist_cookies: yes
  base_url: 'http://localhost:5000'
  users: [
  #  name: 'ryan.faerman@gmail.com', password: 'rewt123', gold: yes
  #,
    name: 'rfaerman@intergi.com', password: 'splinter'
  ,
    name: 'cerberus75@gamezone.com', password: 'splinter', gold: yes
  ,
    name: 'cerberus21@gamezone.com', password: 'splinter'
  #,
  # name: 'cerberus21@gamezone.com', password: 'splinter', gold: yes
  #,
  # name: 'devotedgmr17@hotmail.com', password: 'bulma159753', gold: yes
  ]
  steam_api_key: 'A3E8AE5154BAE5FDDB7A0AE924E8B8DB'
  psn_users: [
    name: 'devotedgmr17@gmail.com', password: 'bulma159753'
  ]
  request_threshold: 15
  child_timeout: 15000
  redis:
    host: '127.0.0.1'
    port: 6379
    database: 2
