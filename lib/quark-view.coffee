#TODO break this down, please!
{$, ScrollView} = require 'atom'
_ = require 'underscore-plus'
moment = require 'moment'
fs = require 'fs'

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

      fileContent = JSON.stringify(@projects, null, 2)
      fs.writeFile '/home/pope/tasks.json', fileContent, (err) ->
        if err
          console.log "Error!", err
        else
          console.log "Tasks file updated!"

    button = $('<span/>').addClass('toggle').text(project.state)
    element = $('<li/>').attr('draggable', true).append(button)
      .append($('<div/>').addClass('item').append("<h2>#{project.name}</h2>"))

    if project.status
      element.addClass(project.status)

    if project.state
      element.addClass(project.state)

    @list.append element

  initialize: (state) ->
    console.log('init view')
    data = fs.readFileSync '/home/pope/tasks.json'
    projects = JSON.parse(data)

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

        fileContent = JSON.stringify(projects, null, 2)
        fs.writeFile '/home/pope/tasks.json', fileContent, (err) ->
          if err
            console.log "Error!", err
          else
            console.log "Tasks file updated!"

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
      console.log refresh
      parentElement = $(this).closest('li')

      $('li.active', $list).not(parentElement).each ->
        project = projects[$(this).index()]

        $that.stopTimer(project)

        $(this).removeClass('active')

      project = projects[$(parentElement).index()]
      $('.timers', $list).remove()

      if project.state != 'active'
        $that.startTimer(project)

        $(parentElement).addClass('active')

        timersElement = $('<ul/>').addClass('timers')

        for timer in project.timers
          timerWrapperElement = $('<li/>')

          startTimerElement = $('<time/>').attr('datetime', timer.start)
          timerWrapperElement.append(startTimerElement)

          if !timer.end
            startTimerElement.text(moment().fromNow())
          else
            startTimerElement.text(moment(timer.start)
              .format('YYYY-MM-DD HH:mm:ss'))
            endTimerElement = $('<time/>').attr('datetime', timer.end)
              .text('-' + moment(timer.end).format('HH:mm:ss'))

            timerWrapperElement.append(endTimerElement)

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
        $('.timers', $list).append('time...')
        $(parentElement).removeClass('active')

      fileContent = JSON.stringify(projects, null, 2)
      fs.writeFile '/home/pope/tasks.json', fileContent, (err) ->
        if err
          console.log "Error!", err
        else
          console.log "Tasks file updated! "

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

    fileContent = JSON.stringify(projects, null, 2)
    fs.writeFile '/home/pope/tasks.json', fileContent, (err) ->
      if err
        console.log "Error!", err
      else
        console.log "Tasks file updated! "

  complete_task: (event, context) ->
    element = $(event.target).closest('li')
    element.addClass('complete')
    projects = @projects

    project = projects[element.index()]
    project.status = "complete"

    fileContent = JSON.stringify(projects, null, 2)
    fs.writeFile '/home/pope/tasks.json', fileContent, (err) ->
      if err
        console.log "Error!", err
      else
        console.log "Tasks file updated! "

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
    if @hasParent()
      @detach()
    else
      @list.empty()

      @addProject project for project in @projects

      atom.workspaceView.appendToRight(this)
