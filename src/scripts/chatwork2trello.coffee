# Description:
#  chatwork task to trello card
#
# Commands:
#   hubot reqdev - chatwork task to trello card
#
# Configuration:
#   HUBOT_TRELLO_KEY - Trello application key
#   HUBOT_TRELLO_TOKEN - Trello API token
#   HUBOT_TRELLO_REQDEV_LIST - The list ID that you'd like to create cards for
#
# Dependencies:
#   "node-trello": "latest"

Trello = require "node-trello"

module.exports = (robot) ->
  robot.respond /REQDEV ((.|\n)*)$/i, (msg) ->
    cardName = msg.match[1]
    dueDate = new Date msg.envelope.user.limitTime * 1000

    unless process.env.HUBOT_TRELLO_TOKEN? and process.env.HUBOT_TRELLO_KEY? and process.env.HUBOT_TRELLO_REQDEV_LIST
      robot.logger.error \
        'Not enough parameters provided. I need a token, key, list'
      process.exit 1

    createCard msg, cardName, dueDate

  createCard = (msg, cardName, dueDate) ->
    t = new Trello process.env.HUBOT_TRELLO_KEY, process.env.HUBOT_TRELLO_TOKEN
    t.post "/1/cards", { name: cardName, idList: process.env.HUBOT_TRELLO_REQDEV_LIST, due: dueDate }, (err, data) ->
      if err
        msg.send "There was an error creating the card"
      else
        msg.send "#{msg.envelope.user.name}さんが開発に#{data.name}を依頼しました\n#{data.url}"
        robot.brain.set "chTask:#{msg.envelope.user.taskId}", data.id
        robot.brain.save()

  robot.respond /CLOSE_REQDEV$/i, (msg) ->
    close msg

  close = (msg) ->
    task_id = robot.brain.get "chTask:#{msg.envelope.user.taskId}"
    t = new Trello process.env.HUBOT_TRELLO_KEY, process.env.HUBOT_TRELLO_TOKEN
    t.put "/1/cards/#{task_id}", { closed: true }, (err, data) ->
      if err
        msg.send "There was an error closing the card"
      else
        robot.brain.remove "chTask:#{msg.envelope.user.taskId}"
        robot.brain.save()
