{Robot, Adapter} = require 'hubot'
HTTPS            = require 'https'
querystring      = require 'querystring'

class Chatwork extends Adapter
  # override
  send: (envelope, strings...) ->
    if envelope.room == undefined
      for room_id in @options.rooms
        envelope.room = room_id
        @send envelope, strings
    else
      @create envelope.room, strings, (err, data) =>
        @robot.logger.error "Chatwork send error: #{err}" if err?

  # override
  run: ->
    @options =
      token: process.env.HUBOT_CHATWORK_TOKEN
      rooms: process.env.HUBOT_CHATWORK_ROOMS.split ','

    unless @options.token? and @options.rooms?
      @robot.logger.error \
        'Not enough parameters provided. I need a token, rooms'
      process.exit 1

    @emit 'connected'

  create: (room, text, callback) ->
    params = []
    params.push text
    body = params.join '&'
    @post "/rooms/#{room}/messages", body, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  request: (method, path, body, callback) ->
    logger = @robot.logger

    # console.log "chatwork #{method} #{path} #{body}"

    token = @options.token
    host = 'api.chatwork.com'

    headers =
      "Host"           : host
      "X-ChatWorkToken": @options.token
      "Content-Type"   : "application/x-www-form-urlencoded"

    options =
      "agent"  : false
      "host"   : host
      "port"   : 443
      "path"   : "/v1#{path}"
      "method" : method
      "headers": headers

    postData = querystring.stringify("body": body)

    options.headers["Content-Length"] = postData.length

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

    request.write postData

    request.end()

    request.on "error", (err) ->
      logger.error "Chatwork request error: #{err}"

exports.use = (robot) ->
  new Chatwork robot
