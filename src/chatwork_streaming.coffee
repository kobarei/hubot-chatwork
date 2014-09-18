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

  Me: (callback) =>
    @get "/me", "", callback

  My: =>
    status: (callback) =>
      @get "/my/status", "", callback

    tasks: (opts, callback) =>
      params = []
      params.push "assigned_by_account_id=#{opts.assignedBy}" if opts.assignedBy?
      params.push "status=#{opts.status}" if opts.status?
      body = params.join '&'
      @get "/my/tasks", body, callback

  Contacts: (callback) =>
    @get "/contacts", "", callback

  Rooms: =>
    show: (callback) =>
      @get "/rooms", "", callback

    create: (name, adminIds, opts, callback) =>
      params = []
      params.push "name=#{name}"
      params.push "members_admin_ids=#{adminIds.join ','}"
      params.push "description=#{opts.desc}" if opts.desc?
      params.push "icon_preset=#{opts.icon}" if opts.icon?
      params.push "members_member_ids=#{opts.memberIds.join ','}" if opts.memberIds?
      params.push "members_readonly_ids=#{opts.roIds.join ','}" if opts.roIds?
      body = params.join '&'
      @post "/rooms", body, callback

  Room: (id) =>
    baseUrl = "/rooms/#{id}"

    show: (callback) =>
      @get "#{baseUrl}", "", callback

    update: (opts, callback) =>
      params = []
      params.push "description=#{opts.desc}" if opts.desc?
      params.push "icon_preset=#{opts.icon}" if opts.icon?
      params.push "name=#{opts.name}" if opts.name?
      body = params.join '&'
      @put "#{baseUrl}", body, callback

    leave: (callback) =>
      body = "action_type=leave"
      @delete "#{baseUrl}", body, callback

    delete: (callback) =>
      body = "action_type=delete"
      @delete "#{baseUrl}", body, callback

    Members: =>
      show: (callback) =>
        @get "#{baseUrl}/members", "", callback

      update: (adminIds, opts, callback) =>
        params = []
        params.push "members_admin_ids=#{adminIds.join ','}"
        params.push "members_member_ids=#{opts.memberIds.join ','}" if opts.memberIds?
        params.push "members_readonly_ids=#{opts.roIds.join ','}" if opts.roIds?
        body = params.join '&'
        @put "#{baseUrl}/members", body, callback

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

    Message: (mid) =>
      show: (callback) =>
        @get "#{baseUrl}/messages/#{mid}", "", callback

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

    Task: (tid) =>
      show: (callback) =>
        @get "#{baseUrl}/tasks/#{tid}", "", callback

    Files: =>
      show: (opts, callback) =>
        body = ""
        body += "account_id=#{opts.account}" if opts.account?
        @get "#{baseUrl}/files", body, callback

    File: (fid) =>
      show: (opts, callback) =>
        body = ""
        body += "create_download_url=#{opts.createUrl}" if opts.createUrl?
        @get "#{baseUrl}/files/#{fid}", body, callback

  get: (path, body, callback) ->
    @request "GET", path, body, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  put: (path, body, callback) ->
    @request "PUT", path, body, callback

  delete: (path, body, callback) ->
    @request "DELETE", path, body, callback

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
