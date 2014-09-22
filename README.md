hubot-chatwork
==============

A Hubot adapter for chatwork.

[![Build Status](https://travis-ci.org/akiomik/hubot-chatwork.png?branch=master)](https://travis-ci.org/akiomik/hubot-chatwork)
[![Coverage Status](https://coveralls.io/repos/akiomik/hubot-chatwork/badge.png?branch=master)](https://coveralls.io/r/akiomik/hubot-chatwork?branch=master)
[![Dependency Status](https://gemnasium.com/akiomik/hubot-chatwork.png)](https://gemnasium.com/akiomik/hubot-chatwork)
[![NPM version](https://badge.fury.io/js/hubot-chatwork.png)](http://badge.fury.io/js/hubot-chatwork)

## Installation

1. Add `hubot-chatwork` to dependencies in your hubot's `package.json`.
```javascript
"dependencies": {
    "hubot-chatwork": "git://github.com/kobarei/hubot-chatwork.git"
}
```

2. Install `hubot-chatwork`.
```sh
npm install
```

3. Set environment variables.
```sh
export HUBOT_CHATWORK_TOKEN="DEADBEEF" # see http://developer.chatwork.com/ja/authenticate.html
export HUBOT_CHATWORK_ROOMS="123,456"   # comma separated
export HUBOT_CHATWORK_ID="123456"   # chatwork ID for hubot task
export HUBOT_GITHUB_TOKEN="**************************"
export HUBOT_GITHUB_OWNER="kobarei"
export HUBOT_GITHUB_REPOS="hubot-chatwork"
export HUBOT_API_RATE="360"
```

4. Move scripts
Move ``scripts/github-polling.coffee`` & ``scripts/chatwork-task-polling.coffee`` into ``scripts`` folder

5. Run hubot with chatwork adapter.
```sh
bin/hubot -a chatwork
```

## Note

`GET /rooms/{room_id}/messages` API is NOT provided yet from Chatwork.

* http://developer.chatwork.com/ja/endpoint_rooms.html#GET-rooms-room_id-messages

So Chatwork API will return `501` error response.

Modify ``node_modules/hubot/src/listener.coffee`` when hubot can't POST to ChatWork.
```diff
  constructor: (@robot, @regex, @callback) ->
-   if message instanceof TextMessage
-     message.match @regex
+   message.match? @regex
```

## License
The MIT License. See `LICENSE` file.
