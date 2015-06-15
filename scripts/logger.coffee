cron = (require 'cron').CronJob
solr = (require 'solr-client').createClient(host: process.env['SOLR_HOST'], core: 'rg_slack')

USER_MENTIONS_REGEX = /@[A-z0-9_-]+/g

module.exports = (robot) ->
  robot.hear //, (msg) ->
    mentions = msg.message.text.match(USER_MENTIONS_REGEX)
    columns =
      id: msg.message.id
      room: msg.message.room
      user: msg.message.user.name
      mention_user: if mentions? then (mention.substr(1) for mention in mentions) else []
      message: msg.message.text
    solr.add columns, (err, obj) ->
      console.log err, obj
