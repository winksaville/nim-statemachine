type
  Message* = object of RootObj
    cmd*: int32

  MessageRef* = ref Message
  MessagePtr* = ptr Message

  State* = int

  StateMachine* = ref object of RootObj
    curState*: int

proc `$`*(msg: MessageRef): string =
  result = $msg.cmd

proc `$`*(msg: MessagePtr): string =
  $cast[MessageRef](msg)

# processMsg needs to be dynamically dispatched thus its a method
method processMsg*(sm: StateMachine, msg: MessageRef) =
  echo "StateMachine.processMsg msg=", msg[]

proc transitionTo*(sm: StateMachine, nextState: int) =
  sm.curState = nextState

proc sendMsg*(sm: StateMachine, msg: MessageRef) =
  sm.processMsg(msg)

