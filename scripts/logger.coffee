moment =  require 'moment'
async  =  require 'async'
mysql  =  require 'mysql-activerecord'
cron   = (require 'cron').CronJob
{Listener} = require 'hubot'
{SlackRawMessage} = require 'hubot-slack'

USER_MENTIONS_REGEX = /@[A-z0-9_-]+/g

db = new mysql.Adapter(
  server: process.env['MYSQL_HOST'],
  username: process.env['MYSQL_USER'],
  password: process.env['MYSQL_PASS'],
  database: process.env['MYSQL_DATABASE'],
  reconnectTimeout: 2000
)

module.exports = (robot) ->
  robot.hear //, (msg) ->
    onMessage(msg.message)

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
      onMessageEdited(message)
    )
  )

  onMessage = (message) ->
    columns =
      pid: message.id
      room: message.room
      user: message.user.name
      message: message.text
      timestamp: moment(message.timestamp).format("YYYY-MM-DD HH:mm:ss")
      created_at: moment(message.timestamp).format("YYYY-MM-DD HH:mm:ss")
      updated_at: moment(message.timestamp).format("YYYY-MM-DD HH:mm:ss")

    db.insert('slack_messages', columns, (err, info) ->
      return console.log 'ERR', err if err?
      mention_users = message.text.match(USER_MENTIONS_REGEX)
      return unless mention_users?
      mention_users = (user.substr(1) for user in mention_users)
      async.each(mention_users, (user, callback) ->
        user_columns =
          message_id: info.insertId
          user: user
          created_at: moment().format("YYYY-MM-DD HH:mm:ss")
          updated_at: moment().format("YYYY-MM-DD HH:mm:ss")
        db.insert('slack_message_mentions', user_columns, callback)
      )
    )

  onMessageEdited = (message) ->
    mention_users = (user.substr(1) for user in message.text.match(USER_MENTIONS_REGEX))
    columns =
      pid: message.id
      room: message.room
      user: message.user.name
      message: message.text

    db.where(pid: columns.pid).get('slack_messages', (err, info) ->
      return console.log 'ERR', err if err?
      message = info[0]
      db.where(id: message.id).update('slack_messages', columns, (err) ->
        return console.log 'ERR', err if err?
        mention_users = message.text.match(USER_MENTIONS_REGEX)
        return unless mention_users?
        mention_users = (user.substr(1) for user in mention_users)
        db.where(message_id: message.id).delete('slack_messages', (err) ->
          return console.log 'ERR', err if err?
          async.each(mention_users, (user, callback) ->
            user_columns =
              message_id: message.id
              user: user
              created_at: moment().format("YYYY-MM-DD HH:mm:ss")
              updated_at: moment().format("YYYY-MM-DD HH:mm:ss")
            db.insert('slack_message_mentions', user_columns, callback)
          )
        )
      )
    )
