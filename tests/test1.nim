{.compile: "src/hw_tp.c".}
{.compile: "src/hw_ptp.c".}
proc ptp_hw_tp1(int_arg: int, string_arg: cstring) {.importc, header: "src/hw_ptp.h".}

import times, parseopt2, os, strutils, threadpool, math, locks
import statemachine, msgarena, msgqueue, msglooper

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
    doAssert(false, "Invalid smCurState=" & $sm.curState)

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
    doneLock: TLock
    doneCond: TCond
    loops: int
    counter1: int
    counter2: int
    counterOther: int
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
        " loops=" & $sm.loops &
        " curState=" & $sm.curState &
        " counter1=" & $sm.counter1 &
        " counter2=" & $sm.counter2 &
        " counterOther=" & $sm.counterOther &
        " mq=" & $sm.mq &
        " pq=" & $sm.pq &
      "}"

proc newTSm(name: string, loops: int, ma: MsgArenaPtr, mq: MsgQueuePtr, pq: MsgQueuePtr = nil): TSm =
  result = TSm(name: name, loops: loops, curState: 1, ma: ma, mq: mq, pq: pq)
  result.doneLock.initLock()
  result.doneCond.initCond()

method getMessageCount(sm: TSm): int64 =
  result = sm.counter1 + sm.counter2

method processMsg(sm: TSm, msg: MsgPtr) =
  when debug: echo sm.name & ".processMsg:+ msg.cmd=" & $msg.cmd & " sm=" & $sm

  var
    cmd = msg.cmd

  case sm.curState
  of 1:
    sm.counter1 += 1
    sm.transitionTo(2)
  of 2:
    sm.counter2 += 1
    sm.transitionTo(1)
  else:
    sm.counterOther += 1
    echo sm.name & ".processMsg:default state"

  if not sm.done:
    # Send message to partner
    var newMsg = sm.ma.getMsg(msg.cmd + 1, 0)
    when debug: echo sm.name & ".processMsg:addTail newMsg to partner"
    sm.pq.addTail(newMsg)

  # return the message after processing
  when debug: echo sm.name & ".processMsg:retMsg"
  sm.ma.retMsg(msg)

  if (cmd >= sm.loops):
    # We're done
    sm.done = true
    sm.doneCond.signal()
    when debug: echo sm.name & ": done"

  when debug: echo sm.name & ".processMsg:- msg.cmd=" & $cmd & " sm=" & $sm

proc t3() =
  var ma = newMsgArena()
  var tSm1 = newTSm("tSm1", loops, ma, newMsgQueue("tSm1"))
  var tSm2 = newTSm("tSm2", loops, ma, newMsgQueue("tSm2"))

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

    # Poll using this one thread
    echo "Start polling"
    while not tSm1.done or not tSm2.done:
      echo "check tSm1"
      msg = tSm1.mq.rmvHeadNonBlocking()
      if msg != nil:
        echo "send tSm1"
        tSm1.sendMsg(msg)
      echo "check tSm2"
      msg = tSm2.mq.rmvHeadNonBlocking()
      if msg != nil:
        echo "send tSm2"
        tSm2.sendMsg(msg)

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
    echo "done: " & $sm

  var
    ma = newMsgArena()
    sm1 = newTSm("looper1", loops, ma, newMsgQueue("looper1"))
    sm2 = newTSm("looper2", loops, ma, newMsgQueue("looper2"))

  sm1.pq = sm2.mq
  sm2.pq = sm1.mq

  echo "sm1: " & $sm1
  echo "sm2: " & $sm2

  spawn looper(sm1)
  spawn looper(sm2)

  # The first message
  var msg = ma.getMsg(0, 0)
  sm1.sendMsg(msg)

  echo "waiting for the loopers to complete"
  sync()
  echo "loopers completed"

proc t5() =
  var
    ma = newMsgArena()
    mq1: MsgQueuePtr
    mq2: MsgQueuePtr
    sm1: TSm
    sm2: TSm

  if false:
    # Have both message queues use two different loopers
    var
      ml1 = newMsgLooper("ml1")
      ml2 = newMsgLooper("ml2")
    mq1 = newMsgQueue("mq1-ml1", ml1.cond, ml1.lock)
    mq2 = newMsgQueue("mq2-ml2", ml2.cond, ml2.lock)
    sm1 = newTSm("sm1", loops, ma, mq1, mq2)
    sm2 = newTSm("sm2", loops, ma, mq2, mq1)
    ml1.addMsgProcessor(sm1, mq1)
    ml2.addMsgProcessor(sm2, mq2)
  else:
    # Have both message queues use the same looper
    var
      ml1 = newMsgLooper("ml1")
    mq1 = newMsgQueue("mq1-ml1", ml1.cond, ml1.lock)
    mq2 = newMsgQueue("mq2-ml1", ml1.cond, ml1.lock)
    sm1 = newTSm("sm1", loops, ma, mq1, mq2)
    sm2 = newTSm("sm2", loops, ma, mq2, mq1)
    ml1.addMsgProcessor(sm1, mq1)
    ml1.addMsgProcessor(sm2, mq2)


  ptp_hw_tp1(1, "t5-start")

  # The first message
  echo "test1: send first message"
  var
    startTime = epochTime()
    msg = ma.getMsg(1, 0)
  sm1.mq.addTail(msg)

  # Wait till the SM's are done
  sm1.doneLock.acquire()
  while not sm1.done:
    sm1.doneCond.wait(sm1.doneLock)
  sm1.doneLock.release()

  sm2.doneLock.acquire()
  while not sm2.done:
    sm2.doneCond.wait(sm2.doneLock)
  sm2.doneLock.release()

  ptp_hw_tp1(2, "t5-done")

  # With two loopers 177us/loop and one looper 158us/loop on my Unix desktop
  var
    endTime = epochTime()
    messageCount = sm1.getMessageCount() + sm2.getMessageCount()
    time = (((endTime - startTime) / float(messageCount))) * 1_000_000

  echo "t5 done: time=" & time.formatFloat(ffDecimal, 4) & "us/msg"
  echo "  sm1: " & $sm1
  echo "  sm2: " & $sm2

#t1()
#t2()
#t3()
#t4()
t5()
