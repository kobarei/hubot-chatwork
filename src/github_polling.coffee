HTTPS          = require 'https'
{EventEmitter} = require 'events'

class GithubPolling extends EventEmitter
  constructor: (options, @robot) ->
    unless options.github_token? and options.github_repos? and options.github_owner?
      @robot.logger.error \
        'Not enough parameters provided. I need a token, repos, owner'
      process.exit 1

    @token = options.github_token
    @owner = options.github_owner
    @rate = parseInt options.apiRate, 10
    @host = 'api.github.com'

    unless @rate > 0
      @robot.logger.error 'API rate must be greater then 0'
      process.exit 1

  Repos: (repo_name, ch_room_id) =>
    Commits: =>
      fetch: (callback) =>
        @get "/repos/#{@owner}/#{repo_name}/commits", "", callback

      polling: (callback) =>
        @Repos(repo_name).Commits().fetch (err, commits) =>
          message = {}
          lastCommit = @robot.brain.get repo_name
          if lastCommit == null
            @robot.brain.set repo_name, commits[1].commit.committer.date
            @robot.brain.save()

          for commit in commits.reverse()
            # initialize message component
            message["user"] = commit.committer.login if message["user"] is undefined
            message["msg"] = "" if message["msg"] is undefined

            lastCommit = @robot.brain.get repo_name
            if lastCommit < commit.commit.committer.date
              # add commit message
              message["msg"] += "  * #{commit.commit.message}: ( #{commit.html_url} )\n"
              lastCommit = commit.commit.committer.date

            @robot.brain.set repo_name, lastCommit
            @robot.brain.save()

          if message["msg"] != ""
            msg = "#{message["user"]}さんが#{repo_name}にコミットしました.\n" + message["msg"]
            @emit 'commit',
              ch_room_id
              repo_name
              msg

  get: (path, body, callback) ->
    @request 'GET', path, body, callback

  request: (method, path, body, callback) ->
    logger = @robot.logger
    # console.log "github #{method} #{path} #{body}"

    headers =
      "Host": @host
      "Authorization": "token #{@token}"
      "User-Agent": @owner

    options =
      "agent"  : false
      "host"   : @host
      "port"   : 443
      "path"   : path
      "method" : method
      "headers": headers

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
              logger.error "GitHub HTTPS status code: #{response.statusCode}"
              logger.error "GitHub HTTPS response data: #{data}"

        if callback
          json = try JSON.parse data catch e then data or {}
          callback null, json

      response.on "error", (err) ->
        logger.error "GitHub HTTPS response error: #{err}"
        callback err, {}

    request.end body

    request.on "error", (err) ->
      logger.error "GitHub request error: #{err}"

module.exports = GithubPolling
