# Description:
#   A Polling scripts for lodge
#
# Dependencies:
#   "cron": ""
#   "nightmare": "^1.5.0"
#   "moment": "^2.8.3"
#
# Configuration:
#   HUBOT_LODGE_ID
#   HUBOT_LODGE_PASSWORD
#   HUBOT_LODGE_HOST
#   HUBOT_GOOGLE_SPREADSHEET_ID
#

{EventEmitter} = require 'events'
{TextMessage}  = require 'hubot'
{CronJob}      = require 'cron'
moment         = require "moment"
Nightmare      = require 'nightmare'

module.exports = (robot) ->
  options =
    lodge_id: process.env.HUBOT_LODGE_ID
    lodge_password: process.env.HUBOT_LODGE_PASSWORD
    host: process.env.HUBOT_LODGE_HOST
    sheet_id: process.env.HUBOT_GOOGLE_SPREADSHEET_ID

  lodgebot = new LodgePolling options, robot

  cronjob = new CronJob '00 23 * * *', () =>
    lodgebot.Articles().polling()

  lodgebot.on 'attendance', (set) ->
    set[0] = moment(set[0], 'YYYYMMDD').format('YYYY/MM/DD')
    robot.emit "addGoogleSpreadSheet", set, options.sheet_id

class Nightlodge
  lodgeLogin: (id, password) ->
    (nightmare) ->
      nightmare
        .type("#user_email", id)
        .type("#user_password", password)
        .click("input[name='commit']")

  stackReports: (cb) ->
    (nightmare) ->
      nightmare
        .evaluate(->
          dateset = new Date()
          year = dateset.getFullYear()
          month = dateset.getMonth() + 1
          month = "0#{month}" if month < 10
          date = dateset.getDate()
          items = document.querySelector('.article-table').querySelectorAll('tr')
          for idx in [0...items.length] by 1
            if items[idx].children[4]?.innerHTML is "#{year}/#{month}/#{date}" and items[idx].children[1]?.innerHTML.match(/日報/)
              stacked_articles = [] if stacked_articles is undefined
              stacked_articles.push items[idx].children[0].querySelector('a').href
          stacked_articles
        ,
          (stacked_articles) ->
            stacked_articles.forEach (item) ->
              cb(item)
        )

class LodgePolling extends EventEmitter
  constructor: (options, @robot) ->
    @host = options.host
    @lodge_id = options.lodge_id
    @lodge_password = options.lodge_password

  Articles: () ->
    polling: () =>
      tag = "日報"
      path = "http://" + @host + "/articles/tag/#{encodeURIComponent(tag)}"
      console.log path

      lodgecli = new Nightlodge()
      nightmare = new Nightmare(weak: false)
      nightmare
        .goto(path)
        .use(lodgecli.lodgeLogin(@lodge_id, @lodge_password))
        .wait("#articles-table")
        .use(
          lodgecli.stackReports(
            (item) =>
              nightmare
                .goto(item)
                .wait("#comment_body")
                .evaluate( ->

                  dateset = new Date()
                  year = dateset.getFullYear()
                  month = dateset.getMonth() + 1
                  month = "0#{month}" if month < 10
                  date = dateset.getDate()

                  if document.querySelector('.panel-body').innerHTML.match(/\d+\/\d+\/\d+/)[0] is "#{year}/#{month}/#{date}"
                    title = document.querySelector('h1').innerHTML.match(/【([^<]*)】([^<]*)/)
                    time = document.querySelector(".markdown").querySelectorAll("ul")[1].querySelector("li").innerHTML.replace(/<br>/, "")
                    [title[1], title[2], time, time.match(/\d*時間\d*分/)[0].replace(/時間/, ':').replace(/分/, ''), location.href]
                  else
                    []
                ,
                  (res) =>
                    if res.length > 0
                      @emit 'attendance', res
                )
          )
        )
        .run()
