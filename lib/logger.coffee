winston = require 'winston'

module.exports = (worker)->
  logg_opts =
    transports: [ 
      new winston.transports.Console(),
      new winston.transports.File { filename: "#{__dirname}/../logs/#{worker}.log" } ]
    exceptionHandlers: [
      new winston.transports.File { filename: "#{__dirname}/../logs/#{worker}.log" } ]
  
  new winston.Logger(logg_opts)
