Anonymize =
  init: ->
    return unless g.VIEW in ['index', 'thread', 'archive'] and Conf['Anonymize']
    return @archive() if g.VIEW is 'archive'

    Post.callbacks.push
      name: 'Anonymize'
      cb:   @node

  node: ->
    return if @info.capcode or @isClone
    {name, tripcode, email} = @nodes
    if @info.name isnt 'Anonymous'
      name.textContent = 'Anonymous'
    if tripcode
      $.rm tripcode
      delete @nodes.tripcode
    if @info.email
      $.replace email, name
      delete @nodes.email

  archive: ->
    $.ready ->
      name.textContent = 'Anonymous' for name in $$ '.name'
      $.rm trip for trip in $$ '.postertrip'
      return
