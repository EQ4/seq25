BUFFER_TIME = 0.5
PROGRESS_INTERVAL = 50
TransportController = Ember.Controller.extend
  song: Ember.computed.alias 'model'

  context: Em.computed -> @container._registry.resolve 'audioContext:main'
  currentTime: -> @get('context').currentTime
  startedAt: 0
  progress: 0
  scheduledUntil: 0
  isPlaying: false

  tempo: Em.computed.alias 'song.tempo'

  beat: Em.computed 'progress', 'tempo', ->
    Math.floor (@get('progress') * @get('tempo')) / 60

  elapsed: ->
    return 0 unless @get 'isPlaying'
    @currentTime() - @get('startedAt')

  play: ->
    @setProperties
      startedAt: @currentTime()
      isPlaying: true
      scheduledUntil: BUFFER_TIME

    {progress, song, scheduledUntil} = @getProperties 'progress', 'song', 'scheduledUntil'

    song.schedule progress, progress, scheduledUntil

    advancePosition = ->
      return unless @get 'isPlaying'
      @set('progress', @elapsed())
      {progress, scheduledUntil} = @getProperties 'progress', 'scheduledUntil'
      if (progress + BUFFER_TIME) > scheduledUntil
        newScheduleEnd = scheduledUntil + BUFFER_TIME
        song.schedule(progress, scheduledUntil, newScheduleEnd)
        @set 'scheduledUntil', newScheduleEnd
      Ember.run.later this, advancePosition, PROGRESS_INTERVAL

    Ember.run.later this, advancePosition, PROGRESS_INTERVAL

  stop: ->
    @get('song').stop()
    @setProperties
      scheduledUntil: 0
      startedAt: 0
      progress: 0
      isPlaying: false

  muteAll: ->
   @setMuteForAll(true)

  unmuteAll: ->
    @setMuteForAll(false)

  setMuteForAll: (val) ->
    @get('song.parts').forEach( (part) -> part.set('isMuted', val))

  actions:
    play: ->
      if @get('isPlaying') then @stop() else @play()

    gotoPart: (part)->
      @transitionToRoute('part', part)

`export default TransportController`
