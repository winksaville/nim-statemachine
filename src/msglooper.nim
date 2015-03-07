import os, threadpool, locks
import statemachine, msgqueue

when not defined(release):
  const DBG = true
else:
  const DBG = false

const
  listMsgProcessorMaxLen = 10

type
  ProcessMsg = proc(sm: StateMachine, msg: MsgPtr)

  MsgProcessorPtr = ptr MsgProcessor
  MsgProcessor = object
    mq: MsgQueuePtr
    sm: StateMachine

  MsgLooperPtr = ptr MsgLooper

  MsgLooper* = object
    name: string
    initialized: bool
    done: bool
    cond*: ptr TCond
    lock*: ptr TLock
    listMsgProcessorLen: int
    listMsgProcessor: ptr array[0..listMsgProcessorMaxLen-1, MsgProcessorPtr]
    thread: ptr TThread[MsgLooperPtr]

# Global initialization lock and cond use to have newMsgLooper not return
# until looper has startend and MsgLooper is completely initialized.
var
  gInitLock: TLock
  gInitCond: TCond

gInitLock.initLock()
gInitCond.initCond()

proc looper(ml: MsgLooperPtr) =
  proc dbg(s: string) =
    when DBG: echo ml.name & ".looper:" & s

  dbg "+"

  gInitLock.acquire()
  block:
    dbg "initializing"
    # initialize MsgLooper
    ml.listMsgProcessorLen = 0
    ml.listMsgProcessor = cast[ptr array[0..listMsgProcessorMaxLen-1, MsgProcessorPtr]](allocShared(sizeof(MsgProcessorPtr) * listMsgProcessorMaxLen))
    ml.lock = cast[ptr TLock](allocShared(sizeof(TLock)))
    ml.lock[].initLock()
    ml.cond = cast[ptr TCond](allocShared(sizeof(TCond)))
    ml.cond[].initCond()
    dbg "signal gInitCond"
    ml.initialized = true;
    gInitCond.signal()
  gInitLock.release()

  while not ml.done:
    dbg "TOL ml.listMsgProcessorLen=" & $ml.listMsgProcessorLen

    # BUG: What happens when the list changes while we're iterating in these loops!

    # First loop check if there are any messages to processes do not hold the lock
    # because its recursive with mq.rmvHeadNonBlocking
    var processedAtLeastOneMsg = false
    for idx in 0..ml.listMsgProcessorLen-1:
      dbg "idx=" & $idx
      var mp = ml.listMsgProcessor[idx]
      var msg = mp.mq.rmvHeadNonBlocking()
      dbg "msg=" & $msg
      if msg != nil:
        dbg "got msg=" & $msg
        processedAtLeastOneMsg = true
        mp.sm.sendMsg(msg)
        dbg "processed msg=" & $msg

    if (not ml.done) and (not processedAtLeastOneMsg):
      # In this second loop we'll check if its empty and we'll hold
      # the lock the entire time so we know for a fact that no signal
      # could have been generated.
      ml.lock[].acquire
      var noMsgs = true
      while (not ml.done) and noMsgs:
        # Check if there are any messages to process
        for idx in 0..ml.listMsgProcessorLen-1:
          var mp = ml.listMsgProcessor[idx]
          if mp.mq.emptyNolock():
            dbg "idx=" & $idx & " got a message"
            noMsgs = false
            break;

        if noMsgs:
          # No messages to process so wait
          dbg "waiting"
          ml.cond[].wait(ml.lock[])
          dbg "done-waiting"

      ml.lock[].release
  dbg ":-"


proc newMsgLooper*(name: string): MsgLooperPtr =
  proc dbg(s: string) =
    when DBG: echo name & ".newMsgLooper:" & s
  ## newMsgLooper does not return until the looper has started and
  ## everything is fully initialized

  dbg "+"

  # Use a global to coordinate initialization of the looper
  # We may want to make a MsgLooper an untracked structure
  # in the future.
  gInitLock.acquire()
  block:
    result = cast[MsgLooperPtr](allocShared(sizeof(MsgLooper)))
    result.name = name
    result.initialized = false;

    if true:
      dbg "Using createThread"
      result.thread = cast[ptr TThread[MsgLooperPtr]](allocShared(sizeof(TThread[MsgLooperPtr])))
      createThread(result.thread[], looper, result)
    else:
      dbg "Using spwan"
      spawn looper(result)

    while (not result.initialized):
      dbg "waiting on gInitCond"
      gInitCond.wait(gInitLock)
    dbg "looper is initialized"
  gInitLock.release()

  dbg "-"

proc delMsgLooper*(ml: MsgLooperPtr) =
  ## kills the message looper, andd message processors
  ## associated witht he looper will not receive any further
  ## messages and all queued up message are lost.
  ## So use this with care!!
  proc dbg(s:string) =
    when DBG: echo ml.name & ".delMsgLooper:" & s

  dbg "DOES NOTHING YET"
  
proc addMsgProcessor*(ml: MsgLooperPtr, sm: StateMachine, mq: MsgQueuePtr) =
  proc dbg(s:string) =
    when DBG: echo ml.name & ".addMsgProcessor:" & s
  dbg "+ sm=" & sm.name
  ml.lock[].acquire()
  dbg "acquired"
  if ml.listMsgProcessorLen < listMsgProcessorMaxLen:
    dbg "...."
    var mp = cast[MsgProcessorPtr](allocShared(sizeof(MsgProcessor)))
    mp.sm = sm
    mp.mq = mq
    ml.listMsgProcessor[ml.listMsgProcessorLen] = mp
    ml.listMsgProcessorLen += 1
    ml.cond[].signal()
  else:
    doAssert(ml.listMsgProcessorLen >= listMsgProcessorMaxLen)

  ml.lock[].release()
  dbg "- sm=" & sm.name

