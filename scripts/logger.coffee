cron = (require 'cron').CronJob
solr = (require 'solr-client').createClient(host: process.env['SOLR_HOST'], core: process.env['SOLR_CORE'])
{Listener} = require 'hubot'
{SlackRawMessage} = require 'hubot-slack'

SLACK_HOME = process.env['SLACK_HOME']
USER_MENTIONS_REGEX = /@[A-z0-9_-]+/g

module.exports = (robot) ->

  new cron '0 30 * * * *', ->
    solr.optimize()
  , null, true, 'Asia/Tokyo'

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

  robot.hear /log\s+search\s+([^\s]+)(\s+(.+))?/, (msg) ->
    query = solr.createQuery()
      .q(msg.match[1])
      .start(0)
      .rows(2)
      .sort(timestamp: 'desc');

    # fq inject
    query.parameters.push 'fq=' + msg.match[3] if msg.match[3]?

    solr.search query, (err, obj) ->
      console.log err if err?
      return if obj.response.numFound <= 0

      for doc in obj.response.docs
        msg.send("#{doc.user} in #{doc.room}: #{doc.message}\n#{SLACK_HOME}/archives/#{doc.room}/p#{doc.id.replace(/\./, '')}")
