type
  MsgPtr* = ptr Msg
  Msg* = object of RootObj
    next*: MsgPtr
    cmd*: int32

  State* = int

  StateMachine* = ref object of RootObj
    name*: string
    curState*: int

proc `$`*(msg: MsgPtr): string =
  result = if msg == nil: "<nil>" else: "{msg: cmd=" & $msg.cmd & "}"

# processMsg needs to be dynamically dispatched thus its a method
method processMsg*(sm: StateMachine, msg: MsgPtr) =
  echo "StateMachine.processMsg NOT Overidden Ignoring: msg=", $msg[]

proc transitionTo*(sm: StateMachine, nextState: int) =
  sm.curState = nextState

proc sendMsg*(sm: StateMachine, msg: MsgPtr) =
  sm.processMsg(msg)
