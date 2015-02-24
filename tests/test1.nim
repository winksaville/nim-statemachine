import times, parseopt2, os, strutils
import statemachine, messagearena

when defined(fast):
  const fastest=true
else:
  const fastest=false

when defined(release):
  const debug = false
else:
  const debug = true

type
  TestSm = ref object of StateMachine
    counter1: int
    counter2: int

var
  testSm1: TestSm

method processMsg(sm: TestSm, msg: Message) =
  case sm.curState
  of 1:
    sm.counter1 += 1
    sm.transitionTo(2)
  of 2:
    sm.counter2 += 1
    sm.transitionTo(1)
  else:
    echo "TestSm default state"

var
  loops: int

# command line args
when debug: echo "paramCount=" & $paramCount() & " paramStr=" & $commandLineParams()

proc t1() =
  when defined(fast):
    loops = 1_000_000_000
  else:
    loops =   100_000_000

  for kind, key, val in getopt():
    when debug: echo "kind=" & $kind & " key=" & key & " val=" & val
    case kind:
    of cmdShortOption:
      case toLower(key):
      of "l": loops = parseInt(val)
      else: discard
    else: discard

  testSm1 = TestSm(curState: 1)

  var ma = newMessageArena()
  var msg = Message()

  var startTime = epochTime()
  var cmdVal = 1.int32
  echo "loops=" & $loops & " fastest=" & $fastest
  for loop in 1..loops:
    cmdVal += 1
    when fastest:
      msg.cmd = cmdVal # 2.3ns/loop desktop, 22.9ns/loop on mac laptop
      testSm1.sendMsg(msg)
    else:
      #msg = Message(cmd: cmdVal) # 26.6ns/loop desktop, 125.4ns/loop laptop
      msg = ma.getMessage(cmdVal, 0) # 46.5ns/loop laptop
      testSm1.sendMsg(msg)
      ma.retMessage(msg)
  var
    endTime = epochTime()
    time = (((endTime - startTime) / float(loops))) * 1_000_000_000

  echo("time=" & time.formatFloat(ffDecimal, 4) & "ns/loop" & " testSm1=" & $testSm1[])



type
  Data = tuple[x, y: int, s: string]

when true:
  # THIS path works just fine

  # Stringify Data but handle nil members
  proc `$`(d: ptr Data): string =
    $d[] # Does this copy to the stack?

  proc `$`(d: Data): string =
    var d_s = if (d.s == nil): "nil" else: d.s
    result = "{" & $d.x & ", " & $d.y & ", " & d_s & "}"
else:
  # THIS path does NOT work

  # this is OK
  proc `$`(d: ptr Data): string =
    var d_s = if (d.s == nil): "nil" else: d.s
    result = "{" & $d.x & ", " & $d.y & ", " & d_s & "}"

  # this won't compile as addr(d) is not allowed
  proc `$`(d: Data): string =
    $cast[ptr Data](addr(d))  # Error: expression has no address

proc newData(): ptr Data =
  result = cast[ptr Data](alloc0(sizeof(Data)))

proc delData(d: ptr Data) =
  if (d.s != nil): GCunref(d.s)
  dealloc(d)

proc t2() =
  echo "t2:+"

  var ma = newMessageArena()
  echo "t2: ma=" & $ma

  var msg1 = ma.getMessage(123, 0)
  var msg2 = ma.getMessage(456, 0)
  echo "t2: msg1=" & $msg1
  echo "t2: msg2=" & $msg2
  ma.retMessage(msg1)
  echo "t2: retMessage ma=" & $ma
  ma.retMessage(msg2)
  echo "t2: retMessage ma=" & $ma

  # get one of the messages back
  msg1 = ma.getMessage(789, 0)
  echo "t2: msg1=" & $msg1
  echo "t2: retMessage ma=" & $ma
  ma.retMessage(msg1)
  echo "t2: retMessage ma=" & $ma

  delMessageArena(ma)

  var d2 = newData()
  d2.s = "def"
  echo "d2=" & $d2[]
  delData(d2)

  echo "t2:-"

t1()
t2()
