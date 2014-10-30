# Description:
#   A Polling scripts for docker actions.
#
# Dependencies:
#   "dockerode": "^2.0.3"
#
# Configuration:
#   HUBOT_CHATWORK_DEV_ROOM
#

{EventEmitter} = require 'events'
Docker         = require 'dockerode'

module.exports = (robot) ->
  options =
    chatwork_dev_room: process.env.HUBOT_CHATWORK_DEV_ROOM

  dp = new DockerPolling robot
  dp.Containers().reset()

  setInterval =>
    dp.Containers().polling()
  , 1000 / (360 / (60 * 60))

  dp.on 'containerUp', (containerInfo) ->
    msg = "【Docker】#{containerInfo.Names[0]?.match(/^\/(.*)/)[1]} (#{containerInfo.Image.replace(/:p/,': p')}) is running."
    robot.send { room: options.chatwork_dev_room }, [msg]

  dp.on 'containerDown', (containerName) ->
    msg = "【Docker】#{containerName?.match(/^\/(.*)/)[1]} stopped"
    robot.send { room: options.chatwork_dev_room }, [msg]

class DockerPolling extends EventEmitter
  constructor: (robot) ->
    @robot = robot
    @docker = new Docker socketPath: '/var/run/docker.sock'
    @existContainers = []
    @containerNames = {}

  Containers: ->

    reset: =>
      @docker.listContainers (err, currentContainers) =>
        @Containers().checkNew currentContainers, null

    polling: =>

      @docker.listContainers (err, currentContainers) =>

        # check if stopped containers
        @Containers().checkStopped currentContainers, (containerName) =>
          @emit 'containerDown', containerName

        # check if new containers
        @Containers().checkNew currentContainers, (containerInfo) =>
          @emit 'containerUp', containerInfo

    checkStopped: (currentContainers, callback) =>
      @existContainers.forEach (containerId) =>
        containerName = @containerNames[containerId]
        targetContainer = currentContainers.where Id: containerId
        if targetContainer.length is 0
          @existContainers.some (v, i) =>
            @existContainers.splice i, 1 if v is containerId
          @Containers().removeName containerId
          callback containerName

    checkNew: (currentContainers, callback) =>
      currentContainers.forEach (containerInfo) =>
        exist = @existContainers.filter (x) -> x is containerInfo.Id
        if exist.length is 0
          @Containers().setName containerInfo
          @existContainers.push containerInfo.Id
          callback containerInfo if callback

    setName: (containerInfo) =>
      @containerNames[containerInfo.Id] = containerInfo.Names[0]

    removeName: (containerId) =>
      delete @containerNames[containerId]

  Array::where = (query) ->
      return [] if typeof query isnt "object"
      hit = Object.keys(query).length
      @filter (item) ->
          match = 0
          for key, val of query
              match += 1 if item[key] is val
          if match is hit then true else false
