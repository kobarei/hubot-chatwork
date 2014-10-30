# Description:
#   A Polling scripts for github repositories. Polling cycle is 1 minute.
#
# Dependencies:
#   "cron": ""
#
# Configuration:
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_OWNER
#   HUBOT_GITHUB_REPOS (Optional)
#   HUBOT_CHATWORK_DEV_ROOM

{CronJob}      = require 'cron'
HTTPS          = require 'https'
{EventEmitter} = require 'events'

module.exports = (robot) ->
  options =
    github_token: process.env.HUBOT_GITHUB_TOKEN
    github_owner: process.env.HUBOT_GITHUB_OWNER
    github_repos: process.env.HUBOT_GITHUB_REPOS
    chatwork_dev_room: process.env.HUBOT_CHATWORK_DEV_ROOM

  unless options.github_token? and options.github_owner? and options.chatwork_dev_room?
    robot.logger.error \
      'Not enough parameters provided. I need a token, repos, owner'
    process.exit 1

  gh_bot = new GithubPolling options, robot

  gh_repos = []
  if options.github_repos
    repos = options.github_repos.split ','
    for repo in repos
      gh_repos.push { "name": repo }

  # every 5 min
  cronjob = new CronJob '*/5 * * * *', () ->
    if gh_repos.length > 0
      gh_bot.emit 'repo_set', gh_repos
    else
      gh_bot.Users().repos()

  cronjob.start()

  gh_bot.on 'commit', (msg) =>
    robot.send { room: options.chatwork_dev_room }, [msg]

  gh_bot.on 'repo_set', (repos) =>
    for repo in repos
      gh_bot.Repos(repo.name).Branches().fetch()

  gh_bot.on 'branch_set', (repo_name, branches) =>
    for branch in branches
      gh_bot.Repos(repo_name).Commits(branch.name).polling()

class GithubPolling extends EventEmitter
  constructor: (options, @robot) ->

    @token = options.github_token
    @owner = options.github_owner
    @host  = 'api.github.com'

  Users: =>
    fetch: (callback) =>
      @get "/user/repos?type=owner", "", callback

    repos: () =>
      @Users().fetch (err, repos) =>
        @emit 'repo_set', repos

  Repos: (repo_name) =>
    Branches: () =>
      fetch: () =>
        @get "/repos/#{@owner}/#{repo_name}/branches", "", (err, branches) =>
          @emit 'branch_set', repo_name, branches

    Commits: (branch_name) =>
      fetch: (callback) =>
        @get "/repos/#{@owner}/#{repo_name}/commits?sha=#{branch_name}", "", callback

      polling: () =>
        @Repos(repo_name).Commits(branch_name).fetch (err, commits) =>
          message = {}
          message["msg"] = ""
          lastCommit = @robot.brain.get "#{repo_name}:#{branch_name}"
          if lastCommit == null
            @robot.brain.set "#{repo_name}:#{branch_name}", commits[0].commit.committer.date
            @robot.brain.save()

          for commit in commits.reverse()

            lastCommit = @robot.brain.get "#{repo_name}:#{branch_name}"
            if lastCommit < commit.commit.committer.date
              # add commit message
              message["user"] = commit.committer.login
              message["msg"] += "  * #{commit.commit.message.replace(/:p/,': p')}: ( #{commit.html_url} )\n"
              lastCommit = commit.commit.committer.date

            @robot.brain.set "#{repo_name}:#{branch_name}", lastCommit
            @robot.brain.save()

          if message["msg"] != ""
            msg = "#{message["user"]}さんが#{repo_name}:#{branch_name}にコミットしました.\n" + message["msg"]
            @emit 'commit',
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
