import nimbox
import os, unicode, tables, strutils, sequtils, strformat, macros

var colorLine = "█" # 0x2588 from https://github.com/nsf/termbox/blob/master/src/demo/paint.c

type
  Coord = (int, int)

  Box = ref object
    drawHandler: proc(box: Box, data: TUIData, nb: Nimbox)
    start: Coord
    width: int
    height: int
    name: string
    coord: Coord

  TUIData = ref object
    location: Location
    status: string
    callstack: seq[FunctionName]
    chronology: seq[ChronoEvent]
    boxes: Table[string, Box]
    coord: Coord
    currentBox: Box
    buildHeight: int 
    buildWidth: int
    lastHeight: int
    files:      Table[string, File]
    flash:      Flash

  Flash = ref object
    text:       string

  File* = ref object
    path*:       string
    line*:       int
    lines*:      seq[Line]

  Line* = ref object
    text*:      string

  ## TEMP

  Location* = object
    path*: string
    line*: int
    status*: string
    functionName*: string

    # move to codetracer
    codeID*:      int64
    functionID*:  FunctionID
    callID*:      int64
    lineID*:      int
    programCodeID*: int64
    event*:       int
    expression*:  string      

  FunctionName* = object
    mangled*:    string
    name*:       string
  
  ChronoEvent* = object
    text*:        string

  FunctionID* = int64

      
const MAX = 100

var data = TUIData()
var nb: Nimbox

macro box(nameArg: untyped, code: untyped): untyped =
  let nameLit = newLit(nameArg.repr)
  result = quote:
    data.boxes[`nameLit`] = Box(name: `nameLit`)
    data.boxes[`nameLit`].drawHandler = proc (box: Box, data: TUIData, nb: Nimbox) =
      data.currentBox = box
      box.coord = box.start
      `code`

macro box(nameArg: untyped, heightArg: static[int], widthArg: static[int]): untyped =
  let nameLit = newLit(nameArg.repr)
  result = quote:
    data.boxes[`nameLit`].height = `heightArg`
    data.boxes[`nameLit`].width = `widthArg`
    data.boxes[`nameLit`].coord = (data.buildWidth, data.buildWidth)
    data.buildWidth += `widthArg`
    data.lastHeight = `heightArg`
  echo result.repr


# sorry, Zahary: I know this is not the top priority
# however i didnt had enough time today, decided to do some work at evening
# and at evening one likes to do more experimental stuff
# and i wanted to try TUI for codetracer for a long time


template text(t: string, newLine: bool = true): untyped =
  nb.print(data.currentBox.coord[0], data.currentBox.coord[1], t)
  if newLine:
    data.currentBox.coord = (data.currentBox.start[0], data.currentBox.coord[1] + 1)
  else:
    data.currentBox.coord = (data.currentBox.coord[0] + t.len, data.currentBox.coord[1])

template align(t: string, width: int): untyped =
  text strutils.alignLeft(t, width), newLine=false

template group(boxes: untyped): untyped =
  `boxes`
  data.buildHeight += data.lastHeight
  data.lastHeight = 0

proc loadFile(path: string): File =
  File(path: path, lines: @[])

iterator visibleLines(file: File, location: Location): Line =
  discard

box toolbar:
  let l = data.location
  align &"codeID = {l.codeID}", 20
  align &"path = {l.path}", 40
  align &"line = {l.line}", 20
  align data.status,20

box editor:
  let file = loadFile(data.location.path)
  for line in file.visibleLines(data.location):
    text line.text

box callgraph:
  for element in data.callstack:
    text element.name

box chronology:
  for element in data.chronology:
    text element.text

box info:
  if not data.flash.isNil:
    text data.flash.text

group:
  box toolbar, MAX, 10

group:
  box editor, 40, 80
  box callgraph, 20, 80
  box chronology, 40, 80

group:
 box info, MAX, 10


proc drawColumn(nb: Nimbox, start: Coord, height: int) =
  # similar to termbox examples
  for i in start[1] ..< start[1] + height:
    nb.print(start[0], i, colorLine)

proc drawLine(nb: Nimbox, start: Coord, width: int) =
  for i in start[0] ..< start[0] + width:
    nb.print(i, start[1], colorLine)

proc drawBox(nb: Nimbox, box: Box, data: TUIData) =
  box.drawHandler(box, data, nb)
  if box.start[0] > 0:
    nb.drawColumn(box.start, box.height)
  if box.start[0] + box.width < MAX:
    nb.drawColumn((box.start[0] + box.width, box.start[1]), box.height)
  if box.start[1] > 0:
    nb.drawLine(box.start, box.width)
  if box.start[1] + box.height < MAX:
    nb.drawLine((box.start[0], box.start[1] + box.height), box.width)

proc draw(nb: Nimbox, data: TUIData) =
  for name, box in data.boxes:
    nb.drawBox(box, data)

# onShortcut:
#   on "F10": next()
#   on "F11": stepIn()
#   on "F12": stepOut()
#   on "0":   jumpCallgraph(0)

proc main() =
  nb = newNimbox()
  defer: nb.shutdown()

  var ch: char
  var text: string
  var evt: Event
  while true:
    nb.clear()
    nb.draw(data)
    nb.present()

    evt = nb.peekEvent(100)
    case evt.kind:
      of EventType.Key:
        if evt.sym == Symbol.Escape:
          break
        ch = evt.ch
        text.add(ch)
      else: discard

when isMainModule:
  main()
