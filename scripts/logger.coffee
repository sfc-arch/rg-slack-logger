cron = (require 'cron').CronJob
solr = (require 'solr-client').createClient(host: process.env['SOLR_HOST'], core: 'rg_slack')
{Listener} = require 'hubot'
{SlackRawMessage} = require 'hubot-slack'

USER_MENTIONS_REGEX = /@[A-z0-9_-]+/g

module.exports = (robot) ->

  # Warning: Use hubot and hubot-slack private functions
  robot.listeners.push new Listener(
    robot,
    ((msg) -> msg instanceof SlackRawMessage && msg.rawMessage?.subtype == 'message_changed'),
    {},
    ((msg) ->
      message =
        id: msg.message.rawMessage.message.ts
        room: msg.message.user.room
        user:
          name: msg.message.rawMessage._client.users[msg.message.rawMessage.message.user].name
        text: msg.message.rawMessage.message.text
      onMessage(message)
    )
  )

  robot.hear //, (msg) ->
    onMessage(msg.message)

  onMessage = (message) ->
    mentions = message.text.match(USER_MENTIONS_REGEX)
    columns =
      id: message.id
      room: message.room
      user: message.user.name
      mention_user: if mentions? then (mention.substr(1) for mention in mentions) else []
      message: message.text
    solr.add columns, (err, obj) ->
      console.log err if err?
