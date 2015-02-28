# A MessageArena that manages getting and returning messages from memory
# The MessageArena is thread safe and shared so they maybe used across threads.
import statemachine, locks

const
  msgArenaSize = 32

type
  MessageArena* = object
    lock: TLock
    msgCount: int
    msgArray: ptr array[msgArenaSize, MessagePtr]

  MessageArenaPtr* = ptr MessageArena

# private procs
proc newMessage(cmdVal: int32, dataSize: int): MessagePtr =
  result = cast[MessagePtr](alloc(sizeof(Message)))
  result.cmd = cmdVal

proc getMsgArrayPtr(ma: MessageArenaPtr): ptr array[msgArenaSize, MessagePtr] =
  ### Assume ma.lock is acquired
  if ma.msgArray == nil:
    ma.msgArray = cast[ptr array[msgArenaSize, MessagePtr]](allocShared(sizeof(MessagePtr) * msgArenaSize))
  result = ma.msgArray
  
## public procs

proc `$`*(ma: MessageArenaPtr): string =
  ma.lock.acquire()
  block:
    var msgStr = "{"
    if ma.msgArray != nil:
      for idx in 0..ma.msgCount-1:
        # probably should do a sequence ??
        msgStr &= $(cast[MessagePtr](ma.msgArray[idx]))
        if idx < ma.msgCount-1:
          msgStr &= ", "
    msgStr &= "}"
    result = "{" & $ma.msgCount & ", " & msgStr & "}"
  ma.lock.release()

proc newMessageArena*(): MessageArenaPtr =
  result = cast[MessageArenaPtr](allocShared0(sizeof(MessageArena)))
  result.lock.initLock()
  result.msgCount = 0;

proc delMessageArena*(ma: MessageArenaPtr) =
  ma.lock.acquire()
  block:
    if ma.msgArray != nil:
      for idx in 0..ma.msgCount-1:
        var msg = cast[MessagePtr](ma.msgArray[idx])
        deallocShared(msg)
      deallocShared(ma.msgArray)
  ma.lock.release()
  ma.lock.deinitLock()
  deallocShared(ma)

proc getMessage*(ma: MessageArenaPtr, cmd: int32, dataSize: int): MessagePtr =
  ma.lock.acquire()
  block:
    var msgA = ma.getMsgArrayPtr()
    if ma.msgCount > 0:
      ma.msgCount -= 1
      result = cast[MessagePtr](msgA[ma.msgCount])
      result.cmd = cmd
    else:
      result = cast[MessagePtr](newMessage(cmd, dataSize))
  ma.lock.release()

proc retMessage*(ma: MessageArenaPtr, msg: MessagePtr) =
  ma.lock.acquire()
  block:
    var msgA = ma.getMsgArrayPtr()
    if ma.msgCount < msgA[].len():
      msgA[ma.msgCount] = cast[MessagePtr](msg)
      ma.msgCount += 1
    else:
      doAssert(ma.msgCount < msgA[].len())
  ma.lock.release()
