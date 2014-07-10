# Only use nodetime if running standalone
if require.main is module
	require('nodetime').profile headless: no

express	 = require 'express'
fs = require 'fs'
_ = require 'underscore'
require 'express-namespace'
params = require 'express-params'
cluster = require 'cluster'

# Create the Express Server and active some middleware
app = module.exports = express.createServer()
params.extend(app)

config = require "#{__dirname}/config/#{app.settings.env}"

# Configuration
app.configure ->
	logFile = fs.createWriteStream("#{__dirname}/logs/#{app.settings.env}.log", flags: 'a')
	app.use express.logger(stream: logFile)
	app.use express.bodyParser()
	app.use express.methodOverride()
	
app.configure 'development', ->
	app.use express.errorHandler dumpExceptions: true, showStack: true

app.configure 'production', ->
	app.use require "#{__dirname}/lib/api_keys"
	app.use express.errorHandler()

app.resque = require('coffee-resque').connect config.redis


if cluster.isWorker
	process.on 'message', (msg) ->
		if msg.cmd?
			switch msg.cmd
				when 'disconnect' 
					app.destroy()
					cluster.worker.disconnect()
				when 'die' then cluster.worker.destroy()
				when 'stop'
					console.log 'stop'
					#winston.error 'Received stop command, closing...'
					app.close()
	app.get '*', (req, res, next) ->
		process.send cmd: 'notifyRequest'
		next()

# Now we go ahead and get all our controllers rolling.
_.each fs.readdirSync("#{__dirname}/controllers"), (controller) ->
	require("#{__dirname}/controllers/#{controller}")(app)

# Start the app if running standalone
if require.main is module
	app.listen process.env.NODE_PORT or= 5000
	console.log "Server listening on port #{app.address().port} in #{app.settings.env} mode"