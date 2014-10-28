# Description:
#   A Polling scripts for lodge
#
# Dependencies:
#   "edit-google-spreadsheets": "^1.0.19"
#
# Configuration:
#   HUBOT_GOOGLE_EMAIL
#   HUBOT_GOOGLE_PASSWORD
#

GoogleSpreadsheets = require "edit-google-spreadsheet"

module.exports = (robot) ->
  options =
    google_email: process.env.HUBOT_GOOGLE_EMAIL
    google_password: process.env.HUBOT_GOOGLE_PASSWORD

  robot.on "addGoogleSpreadSheet", (arr, sheet_id) ->
    set = {}
    i = 0
    arr.forEach (item, i) ->
      set[++i] = item

    console.log set

    GoogleSpreadsheets.load
      debug: true
      spreadsheetId: sheet_id
      worksheetId: "od6"
      username: options.google_email
      password: options.google_password
    , (err, spreadsheet) ->
      spreadsheet.receive (err, rows, info) ->
        throw err  if err

        nextRow = info.nextRow
        output = {}
        output[nextRow] = set

        spreadsheet.add output
        spreadsheet.send (err) ->
          throw err  if err
