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
    loops: int
    counter1: int
    counter2: int
    ma: MsgArenaPtr # My message arena
    mq: MsgQueuePtr # My receive queue
    pq: MsgQueuePtr # Partner queue

proc `$`(sm: TSm): string =
  result =
    if sm == nil:
      "<nil>"
    else:
      "{" &
        $sm.name & ":" &
        " done=" & $sm.done &
        " curState=" & $sm.curState &
        " counter1=" & $sm.counter1 &
        " counter2=" & $sm.counter2 &
        " mq=" & $sm.mq &
        " pq=" & $sm.pq &
      "}"

method processMsg(sm: TSm, msg: MsgPtr) =
  echo($sm)
  case sm.curState
  of 1:
    sm.counter1 += 1
    sm.transitionTo(2)
  of 2:
    sm.counter2 += 1
    sm.transitionTo(1)
  else:
    echo "TestSm default state"

  # Send message to partner
  var newMsg = sm.ma.getMsg(msg.cmd + 1, 0)
  echo sm.name & ": send message to partner"
  sm.pq.addTail(newMsg)

  # return the message after processing
  sm.ma.retMsg(msg)

  if (msg.cmd > sm.loops):
    echo sm.name & ": done"
    sm.done = true

proc t3() =
  var ma = newMsgArena()
  var tSm1 = TSm(name: "tSm1", loops: loops, curState: 1, ma: ma, mq: newMsgQueue("tSm1"))
  var tSm2 = TSm(name: "tSm2", loops: loops, curState: 1, ma: ma, mq: newMsgQueue("tSm2"))

  # Connect statemachines
  tSm1.pq = tSm2.mq
  tSm2.pq = tSm1.mq

  echo($tSm1)
  echo($tSm2)

  randomize()

  proc twoStateMachinesOneThread(name: string) =
    var msg: MsgPtr
    var startTime = epochTime()
    var cmdVal = 0.int32

    echo "loops=" & $loops & " fastest=" & $fastest
    echo "cmdVal=" & $cmdVal
    msg = ma.getMsg(cmdVal, 0)
    tSm1.sendMsg(msg)
    tSm1.ma.retMsg(msg)

    # Poll using this one thread
    echo "Start polling"
    while not tSm1.done or not tSm2.done:
      echo "check tSm1"
      msg = tSm1.mq.rmvHeadNonBlocking()
      if msg != nil:
        echo "send tSm1"
        tSm1.sendMsg(msg)
        tSm1.ma.retMsg(msg)
      echo "check tSm2"
      msg = tSm2.mq.rmvHeadNonBlocking()
      if msg != nil:
        echo "send tSm2"
        tSm2.sendMsg(msg)
        tSm2.ma.retMsg(msg)

    var
      endTime = epochTime()
      time = (((endTime - startTime) / float(loops))) * 1_000_000_000

    echo("time=" & time.formatFloat(ffDecimal, 4) & "ns/loop" & " tSm1=" & $tSm1)

  twoStateMachinesOneThread("th1")

proc t4() =
  proc looper(sm: TSm) =
    echo "start: " & $sm
    while not sm.done:
      var msg = sm.mq.rmvHead()
      sm.sendMsg(msg)
      sm.ma.retMsg(msg)
    echo "done: " & $sm

  var
    ma = newMsgArena()
    sm1 = TSm(name: "looper1", loops: loops, curState: 1, ma: ma, mq: newMsgQueue("looper1"))
    sm2 = TSm(name: "looper2", loops: loops, curState: 1, ma: ma, mq: newMsgQueue("looper2"))

  sm1.pq = sm2.mq
  sm2.pq = sm1.mq

  echo "sm1: " & $sm1
  echo "sm2: " & $sm2

  spawn looper(sm1)
  spawn looper(sm2)

  # The first message
  var msg = ma.getMsg(0, 0)
  sm1.sendMsg(msg)
  sm1.ma.retMsg(msg)

  echo "waiting for the loopers to complete"
  sync()
  echo "loopers completed"

#t1()
#t2()
#t3()
t4()
