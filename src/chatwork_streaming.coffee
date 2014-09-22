HTTPS          = require 'https'
{EventEmitter} = require 'events'

class ChatworkStreaming extends EventEmitter
  constructor: (options, @robot) ->
    unless options.chatwork_token? and options.rooms? and options.apiRate?
      @robot.logger.error \
        'Not enough parameters provided. I need a token, rooms and API rate'
      process.exit 1

    @token    = options.chatwork_token
    @hubot_id = options.hubot_id
    @host     = 'api.chatwork.com'
    @rate     = parseInt options.apiRate, 10
    @lastTask = 0

    unless @rate > 0
      @robot.logger.error 'API rate must be greater then 0'
      process.exit 1

  Room: (id) =>
    baseUrl = "/rooms/#{id}"

    Messages: =>
      show: (callback) =>
        @get "#{baseUrl}/messages", "", callback

      create: (text, callback) =>
        params = []
        text = encodeURIComponent(text).replace(/%20/g, '+')
        params.push "body=#{text}"
        body = params.join '&'
        body = body.replace(/\s/g, '+')
        @post "#{baseUrl}/messages", body, callback

      listen: =>
        @Room(id).Messages().show (err, tasks) =>
          for task in tasks
            if @lastTask < task.message_id and "#{task.account.account_id}" is @hubot_id
              @emit 'task',
                id,
                task.message_id,
                task.account,
                task.body,
                task.send_time,
                task.update_time
              @lastTask = task.message_id

    Tasks: =>
      show: (callback) =>
        params = []
        params.push "status=open"
        body = params.join '&'
        @get "#{baseUrl}/tasks", body, callback

      create: (text, toIds, opts, callback) =>
        params = []
        params.push "body=#{text}"
        params.push "to_ids=#{toIds.join ','}"
        params.push "limit=#{opts.limit}" if opts.limit?
        body = params.join '&'
        @post "#{baseUrl}/tasks", body, callback

      listen: =>
        @Room(id).Tasks().show (err, tasks) =>
          for task in tasks
            if @lastTask < task.task_id and "#{task.account.account_id}" is @hubot_id and Math.round(+new Date()/1000) < task.limit_time
              @emit 'task',
                id,
                task.task_id,
                task.account,
                task.body,
                task.send_time,
                task.update_time
              @lastTask = task.task_id

  get: (path, body, callback) ->
    @request "GET", path, body, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  request: (method, path, body, callback) ->
    logger = @robot.logger
    # console.log "chatwork #{method} #{path} #{body}"

    headers =
      "Host"           : @host
      "X-ChatWorkToken": @token
      "Content-Type"   : "text/plain"

    options =
      "agent"  : false
      "host"   : @host
      "port"   : 443
      "path"   : "/v1#{path}"
      "method" : method
      "headers": headers

    options.headers["Content-Length"] = body.length

    if body.length > 0
      options.path += "?#{body}"

    request = HTTPS.request options, (response) ->
      data = ""

      response.on "data", (chunk) ->
        data += chunk

      response.on "end", ->
        if response.statusCode >= 400
          switch response.statusCode
            when 401
              throw new Error "Invalid access token provided"
            else
              logger.error "Chatwork HTTPS status code: #{response.statusCode}"
              logger.error "Chatwork HTTPS response data: #{data}"

        if callback
          json = try JSON.parse data catch e then data or {}
          callback null, json

      response.on "error", (err) ->
        logger.error "Chatwork HTTPS response error: #{err}"
        callback err, {}

    request.end body

    request.on "error", (err) ->
      logger.error "Chatwork request error: #{err}"

module.exports = ChatworkStreaming
