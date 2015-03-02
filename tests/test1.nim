import times, parseopt2, os, strutils, threadpool, math
import statemachine, msgarena, msgqueue

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

method processMsg(sm: TestSm, msg: MsgPtr) =
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

proc t1() =
  var testSm1 = TestSm(curState: 1)

  var ma = newMsgArena()
  var msg = ma.getMsg(0, 0)

  var startTime = epochTime()
  var cmdVal = 1.int32
  echo "loops=" & $loops & " fastest=" & $fastest
  for loop in 1..loops:
    cmdVal += 1
    when fastest:
      # Reuse same message this is the fastest path
      # 19.2ns/loop desktop, 22.9ns/loop on mac laptop
      msg.cmd = cmdVal
      testSm1.sendMsg(msg)
    elif false:
      # Allocate a new MessageRef each time, this is the slowest path
      # 100.2ns/loop desktop, 125.4ns/loop laptop
      msg = MessageRef(cmd: cmdVal)
      testSm1.sendMsg(msg)
    else:
      # Use MsgArena to speed things up
      # 37.5ns/loop desttop (no locks), 55.2ns/loop desttop (locks), 46.5ns/loop laptop (no locks)
      msg = ma.getMsg(cmdVal, 0)
      testSm1.sendMsg(msg)
      ma.retMsg(msg)

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

  var ma = newMsgArena()
  echo "t2: ma=" & $ma

  var msg1 = ma.getMsg(123, 0)
  var msg2 = ma.getMsg(456, 0)
  echo "t2: msg1=" & $msg1
  echo "t2: msg2=" & $msg2
  ma.retMsg(msg1)
  echo "t2: retMessage ma=" & $ma
  ma.retMsg(msg2)
  echo "t2: retMessage ma=" & $ma

  # get one of the messages back
  msg1 = ma.getMsg(789, 0)
  echo "t2: msg1=" & $msg1
  echo "t2: retMessage ma=" & $ma
  ma.retMsg(msg1)
  echo "t2: retMessage ma=" & $ma

  delMsgArena(ma)

  var d2 = newData()
  d2.s = "def"
  echo "d2=" & $d2[]
  delData(d2)

  echo "t2:-"

type
  TSm = ref object of StateMachine
    done: bool
    counter1: int
    counter2: int
    ma: MsgArenaPtr
    mq: MsgQueuePtr

proc `$`(sm: TSm): string =
  result = "(counter1x=" & $(sm.counter1) & " counter2x=" & $(sm.counter2) & ")"

method processMsg(sm: TSm, msg: MsgPtr) =
  case sm.curState
  of 1:
    sm.counter1 += 1
    sm.transitionTo(2)
  of 2:
    sm.counter2 += 1
    sm.transitionTo(1)
  else:
    echo "TestSm default state"

  if (msg.cmd <= loops):
    var newMsg = sm.ma.getMsg(msg.cmd + 1, 0)
    sm.mq.addTail(newMsg)
  else:
    sm.done = true

proc t3() =
  var ma = newMsgArena()
  var tSm1 = TSm(curState: 1, ma: ma, mq: newMsgQueue())
  var tSm2 = TSm(curState: 1, ma: ma, mq: newMsgQueue())

  echo "tSm1=" & $tSm1

  var loopCount = 10.int32

  randomize()

  proc th(name: string) =
    var msg: MsgPtr
    var startTime = epochTime()
    var cmdVal = 0.int32

    echo "loops=" & $loops & " fastest=" & $fastest
    echo "cmdVal=" & $cmdVal
    msg = ma.getMsg(cmdVal, 0)
    tSm1.sendMsg(msg)

    # Poll using this one thread
    echo "Start polling"
    while not tSm1.done or not tSm2.done:
      msg = tSm1.mq.rmvHeadNonBlocking()
      if msg != nil:
        tSm1.sendMsg(msg)
      msg = tSm2.mq.rmvHeadNonBlocking()
      if msg != nil:
        tSm2.sendMsg(msg)

    var
      endTime = epochTime()
      time = (((endTime - startTime) / float(loops))) * 1_000_000_000

    echo("time=" & time.formatFloat(ffDecimal, 4) & "ns/loop" & " tSm1=" & $tSm1)

  #proc t(name: string) =
  #  for idx in 0..loopCount-1:
  #    var delay = 0 # random(100..250)
  #    echo "t" & name & " idx=" & $idx & " delay=" & $delay
  #    var msg = ma.getMsg(idx, 0)
  #    sleep(delay)
  #    ma.retMessage(msg)

  th("th1")
  sync()

t1()
#t2()
t3()
