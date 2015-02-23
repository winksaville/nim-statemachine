type
  Message* = ref object of RootObj
    cmd*: int32

  State* = int

  StateMachine* = ref object of RootObj
    curState*: int

# processMsg needs to be dynamically dispatched thus its a method
method processMsg*(sm: StateMachine, msg: Message) =
  echo "StateMachine.processMsg msg=", msg[]

proc transitionTo*(sm: StateMachine, nextState: int) =
  sm.curState = nextState

proc sendMsg*(sm: StateMachine, msg: Message) =
  sm.processMsg(msg)

