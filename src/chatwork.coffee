{Robot, Adapter, TextMessage} = require 'hubot'
ChatworkStreaming = require './chatwork_streaming.coffee'
GithubPolling = require './github_polling.coffee'

class Chatwork extends Adapter
  # override
  send: (envelope, strings...) ->
    for string in strings
      @ch_bot.Room(envelope.room).Messages().create string, (err, data) =>
        @robot.logger.error "Chatwork send error: #{err}" if err?

  # override
  reply: (envelope, strings...) ->
    @send envelope, strings.map((str) ->
      "[To:#{envelope.user.id}]+#{envelope.user.name}さん\n#{str}")...

  # override
  run: ->
    options =
      # chatwork
      chatwork_token: process.env.HUBOT_CHATWORK_TOKEN
      rooms: process.env.HUBOT_CHATWORK_ROOMS
      hubot_id: process.env.HUBOT_CHATWORK_ID # chatwork hubot account ID
      # github
      github_token: process.env.HUBOT_GITHUB_TOKEN
      github_owner: process.env.HUBOT_GITHUB_OWNER
      github_repos: process.env.HUBOT_GITHUB_REPOS
      apiRate: process.env.HUBOT_API_RATE

    ch_bot = new ChatworkStreaming options, @robot
    gh_bot = new GithubPolling options, @robot

    ch_rooms = options.rooms.split ','
    gh_repos = options.github_repos.split ','

    setInterval =>
      for room_id in ch_rooms
        ch_bot.Room(room_id).Tasks().listen()
        for repo_name in gh_repos
          gh_bot.Repos(repo_name, room_id).Commits().polling()

    , 1000 / (options.apiRate / (60 * 60))

    ch_bot.on 'task', (room_id, messageId, account, body, sendAt, updatedAt) =>
      user = @robot.brain.userForId account.account_id,
        name: account.name
        avatarImageUrl: account.avatar_image_url
        room: room_id
      @receive new TextMessage user, body, messageId

    gh_bot.on 'commit', (room_id, repo, msg) =>
      envelope =
        user:
          room: room_id
        room: room_id
      @send envelope, [msg]

    @ch_bot = ch_bot

    @emit 'connected'

exports.use = (robot) ->
  new Chatwork robot
