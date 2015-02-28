type
  MessagePtr* = ptr Message
  Message* = object of RootObj
    next*: MessagePtr
    cmd*: int32

  State* = int

  StateMachine* = ref object of RootObj
    curState*: int

proc `$`*(msg: MessagePtr): string =
  result = $msg.cmd

# processMsg needs to be dynamically dispatched thus its a method
method processMsg*(sm: StateMachine, msg: MessagePtr) =
  echo "StateMachine.processMsg msg=", msg[]

proc transitionTo*(sm: StateMachine, nextState: int) =
  sm.curState = nextState

proc sendMsg*(sm: StateMachine, msg: MessagePtr) =
  sm.processMsg(msg)

