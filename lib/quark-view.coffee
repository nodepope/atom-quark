#TODO break this down, please!
{$, ScrollView} = require 'atom'
_ = require 'underscore-plus'
moment = require 'moment'
$ = require 'jquery'
require 'jquery-ui'
fs = require 'fs'
uuid = require('node-uuid')

taskFile = '/home/pope/tasks.json'

tick = (project) ->
  active = $('.active', '.quark ol')
  console.log(active, active.length, $('.quark ol'))

  if active.length
    updateTimer($('time', active), project)

    setTimeout(->tick project, 300)

updateTimer = (element, project) ->
  lastTimer = project.timers[project.timers.length-1]
  duration = moment().diff(lastTimer.start) + moment.duration(project.time)

  element.text getTimeString duration

getTimeString = (duration) ->
  time = moment.duration(duration)

  pad = '00'
  hours = (pad + time.get('hours')).slice(-pad.length)
  minutes = (pad + time.get('minutes')).slice(-pad.length)
  seconds = (pad + time.get('seconds')).slice(-pad.length)

  return hours + ':' + minutes + ':' + seconds;

write = (projects) ->
  fileContent = JSON.stringify(projects, null, 2)

  fs.writeFile taskFile, fileContent, (err) ->
    if err
      console.log "Error!", err
    else
      console.log "Tasks file updated!"

module.exports =
class QuarkView extends ScrollView
  @projects:null

  @content: ->

    @div class: 'quark', =>
      @div outlet: 'titleBar', class: 'titleBar', =>
        @h1 'Tasks'

      @ol outlet: 'list', class: 'projects'

  addProject: (project, persist) ->
    if persist
      @projects.push(project)

      write @projects

    button = $('<span/>').addClass('toggle').text(project.state)

    time = '<time></time>'
    if project.time
      time = "<time>#{project.time}</time>"

    element = $('<li/>')
      .attr('quark-task', project.id)
      .append(button)
      .append(
        $('<div/>')
          .addClass('item')
          .append("#{time}<h2>#{project.name}</h2>")
      )

    if project.status
      element.addClass(project.status)

    if project.state
      element.addClass(project.state)

    @list.append element

  initialize: (state) ->
    console.log('init view')
    data = fs.readFileSync taskFile
    projects = JSON.parse(data)

    # ensure there is an id on each task
    for project in projects
      project.id = uuid() unless project.id

    @projects = projects
    $list = @list
    $that = this

    atom.workspace.observeTextEditors (editor) ->
      editor.onDidSave (e) ->
        hasActiveProject = false

        for project in projects
          if project.state == 'active'
            hasActiveProject = true

            unless project.timers
              project.timers = [{}]
              lastTimerIndex = 0
            else
              lastTimerIndex = project.timers.length - 1

            if !project.timers.length || project.timers[lastTimerIndex].end
              hasActiveProject = false
            else
              timer = project.timers[lastTimerIndex]
              unless timer.files
                timer.files = []

        unless hasActiveProject
          project = projects[0]

          unless project.timers
            project.timers = [{}]

            lastTimerIndex = 0
          else
            lastTimerIndex = project.timers.length-1

          timer = project.timers[lastTimerIndex]

        unless timer.files
          timer.files = []

        timer.files = _.sortBy _.union timer.files, e.path

        write projects

    @titleBar.on 'click', (e) ->
      projectForm = $(this).find('.projectForm')

      if projectForm.length
        projectForm.toggle()
      else
        projectForm = $('<div/>').addClass('projectForm')

        projectName = $('<input>')
          .addClass('name native-key-bindings')
          .attr('placeholder', 'Add a new Task')

        projectSubmit = $('<button>')
          .attr('type', 'submit')
          .addClass('newProject')
          .text('Add')

        projectForm.append(projectName)
        projectForm.append(projectSubmit)

        $(this).append(projectForm)

        projectName.on 'keyup', (e) ->
          if e.which == 13
            projectSubmit.trigger 'click'

        projectSubmit.on 'click', (e) ->

          if projectName.val() != ''
            $that.addProject { "name": projectName.val() }, true

          projectName.val('')
          $that.titleBar.trigger 'click'

          return false

      projectForm.find('input').focus()

    @list.on 'dblclick', '.files li', (e) ->
      atom.workspace.open $(this).attr('path')

    @list.on 'click', '.toggle', (e, refresh) ->
      parentElement = $(this).closest('li')

      $('li.active', $list).not(parentElement).each ->
        project = projects[$(this).index()]

        $that.stopTimer(project)

        $(this).removeClass('active')

      project = projects[$(parentElement).index()]
      $('.timers', $list).remove()

      if project.state != 'active'
        $(parentElement).addClass('active')

        $that.startTimer(project)

        timersElement = $('<ul/>').addClass('timers')

        for timer in project.timers
          timerWrapperElement = $('<li/>')

          startTimerElement = $('<time/>').attr('datetime', timer.start)
          timerWrapperElement.append(startTimerElement)

          if timer.end
            startTimerElement.text(moment(timer.start)
              .format('YYYY-MM-DD HH:mm:ss'))
            endTimerElement = $('<time/>').attr('datetime', timer.end)
              .text('-' + moment(timer.end).format('HH:mm:ss'))

            timerWrapperElement.append(endTimerElement)

            duration = moment(timer.end).diff(timer.start)

            if duration
              timerWrapperElement.append($('<div/>')
                .addClass('time-spent')
                .text(
                  moment.duration(
                    duration
                  ).humanize()
                )
              )

          if timer.files
            filesElement = $('<ol/>').addClass('files')

            for path in timer.files
              filename = path.replace(/(.*\/)(.+)$/,
                '<span class="path">$1</span><strong class="file">$2</strong>')

              fileElement = $("<li>#{filename}</li>").attr('path', path)
              filesElement.append(fileElement)

            timerWrapperElement.append(filesElement)

          timersElement.prepend(timerWrapperElement)

          $('.item', parentElement).append(timersElement)
          timersElement.show('slow')
      else
        $that.stopTimer(project)
        $(parentElement).removeClass('active')

        for project in projects
          duration = 0

          if project.timers
            for timer in project.timers
              if timer.end
                duration += moment(timer.end).diff(timer.start)

            if duration
              project.time = getTimeString duration

      write projects

    write projects

    @list.find('.active .toggle').trigger('click', true)

    atom.workspaceView.command "quark:toggle", => @toggle()
    @toggle()

    atom.workspaceView.command "quark:complete_task",
      => @complete_task(arguments[0], arguments[1])

    atom.workspaceView.command "quark:archive",
      => @archive(arguments[0], arguments[1])

  archive: (event, context) ->
    element = $(event.target).closest('li')
    element.addClass('archive')
    projects = @projects

    project = projects[element.index()]
    project.status = "archive"

    write projects

  complete_task: (event, context) ->
    element = $(event.target).closest('li')
    element.addClass('complete')
    projects = @projects

    project = projects[element.index()]
    project.status = "complete"

    write projects

  startTimer: (project) ->
    project.state = 'active'

    unless project.timers
      project.timers = []
      lastTimerIndex = 0
    else
      lastTimerIndex = project.timers.length-1

    if !project.timers.length ||
        !project.timers[lastTimerIndex].start ||
        project.timers[lastTimerIndex].end

      project.timers[project.timers.length] = {
        start: moment().format('YYYY-MM-DDTHH:mm:ssZZ')
      }
    else
      console.log 'Error! Timers are out of sync with state!', project

    tick(project)

  stopTimer: (project) ->
    project.state = 'paused'

    unless project.timers
      project.timers = []

    lastIndex = project.timers.length-1

    if project.timers && project.timers.length && !project.timers[lastIndex].end
      project.timers[lastIndex].end = moment().format('YYYY-MM-DDTHH:mm:ssZZ')
    else
      console.log 'Error! Timers are out of sync with state!', project

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  toggle: ->
    projects = @projects
    $that = this

    if @hasParent()
      @detach()
    else
      @list.empty()
      $(@list).sortable
        update: (e, ui) ->
          sorted = []

          for item in $(this).sortable('toArray', attribute: 'quark-task')
            next = _.findWhere projects, id: item

            sorted.push next

          $that.projects = sorted
          write $that.projects

      @addProject project for project in projects

      atom.workspaceView.appendToRight(this)
