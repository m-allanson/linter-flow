linterPath = atom.packages.getLoadedPackage('linter').path
Linter = require "#{linterPath}/lib/linter"
findFile = require "#{linterPath}/lib/util"

path = require "path"
fs = require 'fs'
{spawn} = require 'child_process'

_ = require 'underscore-plus'

class LinterFlow extends Linter
  # The syntax that the linter handles. May be a string or
  # list/tuple of strings. Names should be all lowercase.
  @syntax: ['source.js']

  linterName: 'flow'

  lintFile: (filePath, callback) ->
    filename = path.basename filePath
    origPath = path.join @cwd, filename
    options = {}

    unless @flowEnabled
      callback([])
      return

    str = ''
    child = spawn @flowPath, ['status', '--json', path.resolve(atom.project.path)]
    child.stdout.on 'data', (x) -> str += x
    child.stderr.on 'data', (x) -> str += x

    child.stdout.on 'close', (code) =>
      console.log str
      info = JSON.parse(str)
      if info.passed
        callback([])
        return

      realMessages = []
      _.each info.errors, (msg) ->

        first = true
        _.each msg.message, (item) ->
          realMessages.push(_.extend(item, error: first is true, warning: first is false))
          first = false

      realMessages = _.filter realMessages, (x) ->
        return true if x.path is null
        return (path.basename(x.path) is path.basename(filePath))

      ## NB: This parsing code pretty much sucks, but at least does what
      ## we want it to for now
      messages = _.map realMessages, (x) ->
        _.extend {},
          message: x.descr.replace("\n", " ")
          line: x.line
          lineStart: x.line
          lineEnd: x.endline
          colStart: x.start
          colEnd: x.end
          warning: x.warning
          error: x.error

      console.log(messages)

      callback(_.map(messages, (x) => @createMessage(x)))
      return

  findFlowInPath: ->
    pathItems = process.env.PATH.split(/[;:]/)
    _.find(pathItems, (x) -> fs.existsSync(path.join(x, 'flow')))

  constructor: (editor) ->
    super(editor)

    @flowPath = @findFlowInPath()

    @flowEnabled = true
    console.log @flowEnabled
    @flowEnabled &= atom.project.path and fs.existsSync(atom.project.path)
    console.log @flowEnabled
    @flowEnabled &= fs.existsSync(path.join(atom.project.path, '.flowconfig'))
    console.log @flowEnabled
    @flowEnabled &= !(@flowPath is null)
    console.log @flowEnabled

    @flowPath = path.join(@flowPath, 'flow')

    unless @flowEnabled
      console.log 'Flow is disabled, exiting!'
      return

    flowServer = spawn(@flowPath, ['start', '--all', '--module', 'node', path.resolve(atom.project.path)])
    flowServer.on 'close', (code) => @flowEnabled &= (code is 0)

  destroy: ->
    spawn(@flowPath, ['--stop', path.resolve(atom.project.path)])
    console.log "die"

module.exports = LinterFlow
