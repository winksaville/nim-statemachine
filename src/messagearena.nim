# A MessageArena that manages getting and returning messages from memory
#
#               ****** NOT THREAD SAFE! *********
#
# I don't like that sometimes I'm casting to "Ptr" and sometimes not.
# Casting is bad but this seems out of control!
import statemachine

type
  MessageArena* = object
    msgCount*: int
    msgArray*: ptr array[256, MessagePtr]

  MessageArenaPtr* = ptr MessageArena

# private procs
proc newMessage(cmdVal: int32, dataSize: int): MessagePtr =
  result = cast[MessagePtr](alloc(sizeof(Message)))
  result.cmd = cmdVal

proc getMsgArrayPtr(ma: MessageArenaPtr): ptr array[256, MessagePtr] =
  if ma.msgArray == nil:
    ma.msgArray = cast[ptr array[256, MessagePtr]](create(MessagePtr, 256))
  result = ma.msgArray
  

## public procs

proc `$`*(ma: MessageArenaPtr): string =
  var msgStr = "{"
  if ma.msgArray != nil:
    for idx in 0..ma.msgCount-1:
      # probably should do a sequence ??
      msgStr &= $(cast[MessagePtr](ma.msgArray[idx]))
      if idx < ma.msgCount-1:
        msgStr &= ", "
  msgStr &= "}"
  result = "{" & $ma.msgCount & ", " & msgStr & "}"

proc newMessageArena*(): MessageArenaPtr =
  result = cast[MessageArenaPtr](alloc0(sizeof(MessageArena)))
  result.msgCount = 0;

proc delMessageArena*(ma: MessageArenaPtr) =
  if ma.msgArray != nil:
    for idx in 0..ma.msgCount-1:
      var msg = cast[MessagePtr](ma.msgArray[idx])
      dealloc(msg)
    free(ma.msgArray)
  dealloc(ma)

proc getMessage*(ma: MessageArenaPtr, cmd: int32, dataSize: int): MessageRef =
  var msgA = ma.getMsgArrayPtr()
  if ma.msgCount > 0:
    ma.msgCount -= 1
    result = cast[MessageRef](msgA[ma.msgCount])
    result.cmd = cmd
  else:
    result = cast[MessageRef](newMessage(cmd, dataSize))

proc retMessage*(ma: MessageArenaPtr, msg: MessageRef) =
  var msgA = ma.getMsgArrayPtr()
  if ma.msgCount < msgA[].len():
    msgA[ma.msgCount] = cast[MessagePtr](msg)
    ma.msgCount += 1
  else:
    doAssert(ma.msgCount < msgA[].len())
