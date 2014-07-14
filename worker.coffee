winston = require 'winston'
fs = require 'fs'
config = require './config'

resque = require('coffee-resque').connect config.redis

# worker_type = process.env.WORKER_TYPE or= no
WORKER_TYPES = (n.split('.')[0] for n in fs.readdirSync("#{__dirname}/workers"))

unless worker_type and worker_type in WORKER_TYPES
  winston.error "WORKER_TYPE is required, valid types are: #{WORKER_TYPES.join ', '}"
  winston.error "Try: WORKER_TYPE=notifier #{process.argv.join ' '}"
  process.exit()

logger = require('./lib/logger') worker_type
winston.cli()
logger.cli()

# logger.info "Starting a #{worker_type} worker"
#
# worker = require "#{__dirname}/workers/#{worker_type}"
# worker.name = "#{worker_type}"
#
# worker.on 'job', (worker, queue, job) ->
#   logger.info "#{worker.name} working on job from #{queue}"
#
# worker.on 'error', (err, worker, queue, job) ->
#   logger.error "#{worker.name} had an error #{queue}"
#   logger.error err
#   logger.error worker
#   logger.error queue
#   logger.error job
#
# worker.on 'success', (worker, queue, job, result) ->
#   logger.info "#{worker.name} finished working and is ready for another task"
#
# worker.start()
# logger.info "#{worker_type} worker started"

workers = []
for worker_type in WORKER_TYPES
  logger.info "Starting a #{worker_type} worker"

  worker = require "#{__dirname}/workers/#{worker_type}"
  worker.name = "#{worker_type}"

  worker.on 'job', (worker, queue, job) ->
    logger.info "#{worker.name} working on job from #{queue}"

  worker.on 'error', (err, worker, queue, job) ->
    logger.error "#{worker.name} had an error #{queue}"
    logger.error err
    logger.error worker
    logger.error queue
    logger.error job

  worker.on 'success', (worker, queue, job, result) ->
    logger.info "#{worker.name} finished working and is ready for another task"

  worker.start()
  logger.info "#{worker_type} worker started"
  workers.push(worker)


# End the worker so that resque doesn't so extra workers
stop_gracefully = ->
  worker.end() for worker in workers
  process.exit()

process.on 'SIGTERM', stop_gracefully
process.on 'SIGINT', stop_gracefully
