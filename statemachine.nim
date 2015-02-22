import times
import parseopt2
import os
import strutils

when defined(fast):
  const fastest=true
else:
  const fastest=false

when defined(release):
  const debug = false
else:
  const debug = true

type
  Message = ref object of RootObj
    cmd: int32

  State = int

  StateMachine = ref object of RootObj
    curState: int

# processMsg needs to be dynamically dispatched thus its a method
method processMsg(sm: StateMachine, msg: Message) =
  echo "StateMachine.processMsg msg=", msg[]

proc transitionTo(sm: StateMachine, nextState: int) =
  sm.curState = nextState

proc sendMsg*(sm: StateMachine, msg: Message) =
  sm.processMsg(msg)

when isMainModule:
  type
    TestSm = ref object of StateMachine
      counter1: int
      counter2: int

  var
    testSm1: TestSm
    msg: Message

  method processMsg(sm: TestSm, msg: Message) =
    case sm.curState
    of 1:
      sm.counter1 += 1
      sm.transitionTo(2)
    of 2:
      sm.counter2 += 1
      sm.transitionTo(1)
    else: echo "TestSm default state"

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

  testSm1 = TestSm(curState: 1)
  msg = Message()

  var startTime = epochTime()
  var cmdVal = 1i32
  echo "loops=" & $loops & " fastest=" & $fastest
  for loop in 1..loops:
    cmdVal += 1
    when fastest:
      msg.cmd = cmdVal # 2.3ns/loop
    else:
      msg = Message(cmd: cmdVal) # 26.6ns/loop about 10 times slower
    testSm1.sendMsg(msg)
  var endTime = epochTime()

  var time = (((endTime - startTime) / float(loops))) * 1_000_000_000
  echo("time=" & time.formatFloat(ffDecimal, 4) & "ns/loop" & " testSm1=" & $testSm1[])
