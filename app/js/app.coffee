Song = Ember.Object.extend
  tempo: 120

  beat_count: 16

  startedAt: 0

  isPlaying: false

  parts: []

  toggle: ->
    if @get('isPlaying') then @stop() else @play()

  elapsed: ->
    @currentTime() - @get('startedAt')

  progress: ->
    @elapsed() / @get('screenDuration')

  screenDuration: (-> @get('beat_count') * 60 / +@get('tempo')).property('tempo', 'beat_count')

  currentTime: -> Seq25.audioContext.currentTime

  loopHasEnded: -> @progress() >= 1

  play: ->
    @set('startedAt', @currentTime())
    @set('isPlaying', true)
    for part in @get('parts')
      for note in part.get('notes')
        note.schedule()
    movePlayBar = =>
      $('#play-bar').css left: "#{@progress() * 100}%"
      return unless @get('isPlaying')
      if @loopHasEnded()
        @play()
      else
        requestAnimationFrame movePlayBar

    requestAnimationFrame movePlayBar

  stop: ->
    for part in @get('parts')
      for note in part.get('notes')
        note.stop()
    @set('startedAt', 0)
    @set('isPlaying', false)

window.Seq25 = Ember.Application.create()

Seq25.Part = Ember.Object.extend
  init: ->
    @set('notes', [])
    @_super()

  name: ''
  notes: null

  addNoteAtPoint: (progress, pitch)->
    note = new Note progress, pitch
    note.schedule() if @get('isPlaying')
    @get('notes').addObject note

  removeNote:(note)->
    note.stop()
    @get('notes').removeObject(note)

window.song = Song.create()

Seq25.audioContext = new AudioContext

Seq25.Router.map ->
  @resource 'song', path: '/', ->
    @resource 'part', path: "/parts/:name"
    @resource 'parts', ->
      @route 'notes'
      @route 'instrument'

Seq25.SongRoute = Ember.Route.extend
  model: -> song

  setupController: (controller, model)->
    @controllerFor('transport').set('model', model)
    controller.set('model', model)

Seq25.PartRoute = Ember.Route.extend
  parts: (-> @modelFor('song').get('parts')).property()

  findPart: (name)-> @get('parts').findBy 'name', name

  model: (params)->
    @set('intendedName', params.name)
    @findPart @get('intendedName')

  setupController: (controller, model)->
    unless model
      model = Seq25.Part.create name: @get('intendedName')
    unless @findPart model.get('name')
      @get('parts').addObject model
    controller.set('model', model)

Seq25.PartController = Ember.ObjectController.extend
  pitches: (->
    Seq25.Pitch.all.map (pitch)=>
      Seq25.PitchController.create content: pitch, part: @get('model')
  ).property('model')

  beats: (-> [1..@get('beat_count')] ).property('beat_count')


Seq25.PartsIndexRoute = Ember.Route.extend
  model: ->
    'Q W E R A S D F'.w().map (name)->
      Seq25.Part.create name: name

Seq25.PartsIndexController = Ember.ArrayController.extend
  rowSize: 4
  rows: (->
    [0,1].map (x)=>
      @slice @get('rowSize') * x, @get('rowSize') + (@get('rowSize') * x)
  ).property()
  actions:
    hotKey: (key)->
      @forEach (part)=>
        if part.get('name') == key
          @transitionToRoute('part', part)

Seq25.PartsIndexView = Ember.View.extend
  didInsertElement: ->
    addEventListener 'keydown', (e)=>
      return unless @get('state') == 'inDOM'
      e.preventDefault()
      @get('controller').send('hotKey', String.fromCharCode(e.keyCode))

Seq25.TransportController = Ember.ObjectController.extend

  song: Ember.computed.alias 'model'

  empty: (-> @get('notes').length == 0).property('notes.@each')

  actions:
    play: ->
      return if @get('empty')
      @get('song').toggle()


Seq25.PitchController = Ember.ObjectController.extend
  notes: (->
    @get('part').get('notes').filter (note)=>
      note.isPitch @get('model')
  ).property('part.notes.@each')
  actions:
    play: -> Seq25.Osc.play @get('model')
    stop: -> Seq25.Osc.stop @get('model')
    addNote: (time)->
      @get('part').addNoteAtPoint(time, @get('model'))
    removeNote: (note)->
      @get('part').removeNote(note)

Seq25.SongController = Ember.ObjectController.extend
  pitches: (->
    Seq25.Pitch.all.map (pitch)-> Seq25.PitchController.create content: pitch
  ).property()

  beats: (-> [1..@get('beat_count')] ).property('beat_count')

  actions:
    setTempo: (val)->
      @get('model').set 'tempo', val

    setBeatCount: (val)->
      @get('model').set 'beatCount', val

Seq25.TransportView = Ember.View.extend
  didInsertElement: ->
    addEventListener 'keydown', (e)=>
      if e.keyCode == 32
        e.preventDefault()
        @get('controller').send 'play'

  tagName: 'section'

Seq25.NumberView = Ember.TextField.extend
  type: 'number'
  attributeBindings: ['min', 'max', 'action']
  change: ->
    @triggerAction
      action: @get('action'),
      actionContext: +@get('value')

Seq25.PianoKeyView = Ember.View.extend
  attributeBindings: ['class']
  classNames: ['row']
  classNameBindings: ['isSharp']
  isSharp: (-> 'sharp' if @get('controller').get('isSharp')).property()
  tagName: 'li'

  mouseLeave: -> @get('controller').send 'stop'
  mouseUp:    -> @get('controller').send 'stop'
  mouseDown:  -> @get('controller').send 'play'

Seq25.BeatListView = Ember.CollectionView.extend
  classNames: ['measures']
  itemViewClass: Ember.View.extend
    classNames: ['measure']
    didInsertElement: ->
      beats = @get('controller').get('beat_count')
      @$().css(width: "#{100 / beats }%")

Seq25.NoteListView = Ember.CollectionView.extend
  itemView: 'note'
  tagName: 'ul'
  classNames: ['notes']
  itemViewClass: Ember.View.extend
    click: ->
      @get('controller').send 'removeNote', @get('content')
      false

    didInsertElement: ->
      time = @get('content').get('start')
      @$().css(left: "#{time * 100}%")

  click: (e)->
    offsetX = e.pageX - @$().offset().left
    rowWidth = @$().width()
    @get('controller').send 'addNote', (offsetX / rowWidth)

Ember.Handlebars.helper 'beat-list',   Seq25.BeatListView
Ember.Handlebars.helper 'piano-key',   Seq25.PianoKeyView
Ember.Handlebars.helper 'note-list',   Seq25.NoteListView
Ember.Handlebars.helper 'number-input',Seq25.NumberView

Note = Ember.Object.extend
  init: (@start, @pitch)->

  isPitch: (pitch)->
    @pitch.name == pitch.name

  schedule: ->
    beats = song.get('beat_count')
    ratio = 60 * beats / song.get('tempo')
    Seq25.Osc.play(@pitch, (@start - song.progress()) * ratio, (ratio/beats))

  stop: ->
    Seq25.Osc.stop(@pitch)

class Seq25.Pitch
  noteNames = "A A# B C C# D D# E F F# G G#".w()
  a0Pitch = 27.5
  constructor: (@number)->
    @name = noteNames[(number - 21) % 12] + Math.round((number - 17) / 12)
    @freq = a0Pitch * Math.pow(2, (@number - 21)/12)
    @isSharp = @name.indexOf('#') > 0

  do ->
    pitches = for number in [45..95] #[21..108]
      new Pitch(number)
    Pitch.all = pitches.reverse()
