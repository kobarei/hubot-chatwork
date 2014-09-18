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
    @repos = options.github_repos.split ','
    @rate = parseInt options.apiRate, 10
    @host = 'api.github.com'
    @lastCommit = ''

    unless @rate > 0
      @robot.logger.error 'API rate must be greater then 0'
      process.exit 1

  Repos: (repo_name, ch_room_id) =>
    Commits: =>
      fetch: (callback) =>
        @get "/repos/#{@owner}/#{repo_name}/commits", "", callback

      polling: (callback) =>
        @Repos(repo_name).Commits().fetch (err, commits) =>
          for commit in commits
            if @lastCommit < commit.commit.committer.date
              @emit 'commit',
                ch_room_id
                repo_name
                commit
              @lastCommit = commit.commit.committer.date

  get: (path, body, callback) ->
    @request 'GET', path, body, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  request: (method, path, body, callback) ->
    logger = @robot.logger
    console.log "github #{method} #{path} #{body}"

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
