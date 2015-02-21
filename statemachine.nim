import times

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

  testSm1 = TestSm(curState: 1)
  msg = Message()

  var startTime = cpuTime()
  var loops: int32 = 1_000_000_000
  for cmd in 1i32 .. loops: # better way to make a range of i32 literals?
    when false:
      msg = Message(cmd: cmd) # 5,100ns/loop, 3000 time slower
    else:
      msg.cmd = cmd # 1.7ns/loop
    msg.cmd = cmd
    testSm1.sendMsg(msg)
  var endTime = cpuTime()

  echo("time=" & $((endTime - startTime)/float(loops)) & " testSm1=" & $testSm1[])
