env = process.env.NODE_ENV or= 'development'
module.exports = require "./config/#{env}"