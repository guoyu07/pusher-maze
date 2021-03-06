`
CanvasRenderingContext2D.prototype.roundRect = function (x, y, w, h, r) {
  if (w < 2 * r) r = w / 2;
  if (h < 2 * r) r = h / 2;
  this.beginPath();
  this.moveTo(x+r, y);
  this.arcTo(x+w, y,   x+w, y+h, r); 
  this.arcTo(x+w, y+h, x,   y+h, r);
  this.arcTo(x,   y+h, x,   y,   r);
  this.arcTo(x,   y,   x+w, y,   r);
  this.closePath();
  return this;
}
`

angular.module("Maze").controller("AppCtrl", ["$scope", "$pusher", ($scope, $pusher) ->

  $scope.hidden = false

  document.onkeydown = (e) ->
    if e.keyCode is 72 then $scope.$apply -> $scope.hidden = !$scope.hidden
  
  $scope.triggerStream = [];
  $scope.bindStream = [];
  
  renderInitialHtml = (inner)-> $scope.initialHtml = "<pre style='text-align: left'><code class='language-javascript'>" + inner +  "</code></pre>"

  renderTriggerHtml = (inner)-> $scope.triggerHtml = "<pre style='text-align: left'><code class='language-javascript'>" + inner +  "</code></pre>"
  
  renderBindHtml = (inner)-> $scope.bindHtml = "<pre style='text-align: left'><code class='language-javascript'>" + inner +  "</code></pre>"
  
  # TODO: do not hard-code the key
  
  intialHtml = "var pusher = new Pusher('77f6df16945f47c63a1f');\n\nvar tiltChannel =  pusher.subscribe('presence-tilt-channel');\n\n"

  initialTriggerHtml = "tiltChannel.trigger('client-tilt', {colour: user.color, tilt: tilt.direction});"

  initialBindHtml = "tiltChannel.bind('client-tilt', function(user){\n\tvar square = Square.colour(user.colour);\n\tsquare.move(user.direction);\n});"

  renderInitialHtml(Prism.highlight(intialHtml, Prism.languages.javascript))
  renderTriggerHtml(Prism.highlight(initialTriggerHtml, Prism.languages.javascript))
  renderBindHtml(Prism.highlight(initialBindHtml, Prism.languages.javascript))

  # $scope.bindHtml = renderTriggerHtml("var pusher = new Pusher('77f6df16945f47c63a1f');\n\nvar tiltChannel = pusher.subscribe('presence-tilt-channel');\ntiltChannel.bind('client-tilt', function(user){\n\tvar square = Square.colour(user.colour);\n\tsquare.move(user.direction);\n});")

  # --------------- PUSHER ------------- 

  # -- Pusher Initialization

  client = new Pusher("77f6df16945f47c63a1f")
  pusher = $pusher(client)
  tiltChannel = pusher.subscribe("presence-tilt-channel")

  # -- Event listeners

  triggerHtml = ->
    "tiltChannel.trigger('client-tilt', {colour: '#{$scope.lastEvent.colour}', tilt: '#{$scope.lastEvent.direction}'});"

  bindHtml = ->
    "tiltChannel.bind('client-tilt', function(user){\n\tvar square = Square.colour('#{$scope.lastEvent.colour}');\n\tsquare.move('#{$scope.lastEvent.direction}');\n});"

  $scope.lastEvent = {};

  # Whenever there is a new player, create a new square

  tiltChannel.bind "client-new-player", (user) -> new Square(390, 0, user.colour)

  # Whenever a member is removed, delete a square from the array of squares

  tiltChannel.bind 'pusher:member_removed', (user) -> Square.all = _.without(Square.all, Square.colour(user.id))

  # Whenver somebody has tilt their phone, move the square whose colour is assigned to that user

  tiltChannel.bind "client-tilt", (user) -> 
    square = Square.colour(user.colour)
    lastMove = square.lastMove
    square.move user.tilt
    if user.tilt isnt lastMove
      console.log "Change in direction! #{square.colour} is moving #{user.tilt}"
      # $scope.$apply(function)

      $scope.$apply ->  $scope.lastEvent = {colour: user.colour, direction: user.tilt}
      console.log($scope.lastEvent)

      inner =  Prism.highlight(bindHtml(), Prism.languages.javascript);
      renderBindHtml inner
      
      inner =  Prism.highlight(triggerHtml(), Prism.languages.javascript);
      renderTriggerHtml inner
      
      # $scope.bindHtml = "<pre style='text-align: left'><code class='language-javascript'>" + inner +  "</code></pre>"
      # console.log $scope.bindHtml
      # console.log html
      # Prism.highlightAll()
      # code = document.getElementById('example-code')
      # Prism.highlightElement(code)
      # $scope.moveStream.unshift({colour: user.colour, direction: user.tilt})



  # --------- SETTING UP AND DRAWING ON THE CANVAS ------- 

  WIDTH = HEIGHT = 1000
  img = new Image()
  img.src = "assets/plewmaze.png"
  canvas = document.getElementById("canvas")
  ctx = canvas.getContext("2d")

  rect = (x, y, w, h) ->
    ctx.roundRect(x, y, w, h, 3).fill()

  drawMaze = -> ctx.drawImage img, 0, 50

  clearCanvas = -> ctx.clearRect 0, 0, WIDTH, HEIGHT

  drawSquares = ->
    clearCanvas()
    drawMaze()
    drawOne(square) for square in Square.all;

  drawOne = (square) ->
    ctx.fillStyle = square.colour
    rect square.x, square.y, 15, 15 

  setInterval drawSquares, 100 # redraws canvas every 100ms

  # -------- THE SQUARE CLASS -------

  class Square

    # class methods

    @all: []

    @colour: (colour) -> _.findWhere(@all, {colour: colour})

    # instance methods

    constructor: (@x, @y, @colour) ->
      @dx = @dy = 15
      @constructor.all.push(@)

    move: (direction) ->
      startValue = (if (direction is "up" or direction is "down") then "y" else "x")
      operator = (if (direction is "up" or direction is "left") then "-" else "+")
      inverseOperator = (if (operator is "-") then "+" else "-")
      boundLimit = (if (direction is "down") then HEIGHT else (if (direction is "right") then WIDTH else 0))
      boundMovement = (if (operator is "-") then ">" else "<")
      
      withinBounds = eval("this." + startValue + " " + operator + " " + "this." + "d" + startValue + " " + boundMovement + " " + boundLimit)
      move = "this." + startValue + " " + operator + "=" + " " + "this." + "d" + startValue
      moveBack = "this." + startValue + " " + inverseOperator + "=" + " " + "this." + "d" + startValue
      
      if withinBounds
        eval move
        if @collision()
          eval moveBack
          tiltChannel.trigger "client-collision", {colour: @colour}

      @lastMove = direction


    collision: ->
      imgd = ctx.getImageData(@x, @y, 15, 15)
      pix = imgd.data
      for i in [3..pix.length - 1 ] by 4  
        return true if (pix[i] isnt 0)

])
