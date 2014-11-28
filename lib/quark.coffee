#TODO find a way to run this on startup!
{$, View} = require 'atom'
QuarkView = require './quark-view'
fs = require('fs')

class Quark
  quarkView: null

  activate: (state) ->
    @quarkView = new QuarkView(state)
    atom.workspaceView.appendToRight @quarkView

  deactivate: ->
    console.log('deactivate')
    @quarkView.destroy()

  serialize: ->
    console.log('serialize')
    quarkViewState: @quarkView.serialize()

module.exports = new Quark()
