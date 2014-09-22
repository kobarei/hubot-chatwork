{Robot, Adapter, TextMessage} = require 'hubot'
ChatworkStreaming = require './chatwork_streaming.coffee'
GithubPolling = require './github_polling.coffee'

class Chatwork extends Adapter
  # override
  send: (envelope, strings...) ->
    if envelope.room == undefined
      for room_id in @ch_rooms
        envelope.room = room_id
        @send envelope, strings
    else
      for string in strings
        @ch_bot.Room(envelope.room).Messages().create string, (err, data) =>
          @robot.logger.error "Chatwork send error: #{err}" if err?

  # override
  run: ->
    options =
      # chatwork
      chatwork_token: process.env.HUBOT_CHATWORK_TOKEN
      rooms: process.env.HUBOT_CHATWORK_ROOMS
      hubot_id: process.env.HUBOT_CHATWORK_ID # chatwork hubot account ID
      apiRate: process.env.HUBOT_API_RATE

    ch_bot = new ChatworkStreaming options, @robot
    ch_rooms = options.rooms.split ','

    setInterval =>
      for room_id in ch_rooms
        ch_bot.Room(room_id).Tasks().listen()
    , 1000 / (options.apiRate / (60 * 60))

    ch_bot.on 'task', (room_id, messageId, account, body, sendAt, updatedAt) =>
      user = @robot.brain.userForId account.account_id,
        name: account.name
        avatarImageUrl: account.avatar_image_url
        room: room_id
      @receive new TextMessage user, body, messageId

    @ch_bot = ch_bot
    @ch_rooms = ch_rooms

    @emit 'connected'

exports.use = (robot) ->
  new Chatwork robot
