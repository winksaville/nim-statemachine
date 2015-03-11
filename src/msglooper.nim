const PTP = false

when PTP:
  proc ptp_hw_tp1(int_arg: int, string_arg: cstring) {.importc, header: "src/hw_ptp.h".}

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
  let
    prefix = ml.name & ".looper:"

  proc dbg(s: string) {.inline.} =
    when PTP: ptp_hw_tp1(0, prefix & s)
    when DBG: echo prefix & s

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

  # BUG: What happens when the list changes while we're iterating in these loops!

  ml.lock[].acquire
  while not ml.done:
    dbg "TOL ml.listMsgProcessorLen=" & $ml.listMsgProcessorLen
    # Check if there are any messages to process
    var processedAtLeastOneMsg = false
    for idx in 0..ml.listMsgProcessorLen-1:
      var mp = ml.listMsgProcessor[idx]
      var msg = mp.mq.rmvHeadNonBlockingNolock()
      if msg != nil:
        processedAtLeastOneMsg = true
        mp.sm.sendMsg(msg)
        dbg "processed msg=" & $msg

    if not processedAtLeastOneMsg:
      # No messages to process so wait
      dbg "waiting"
      ml.cond[].wait(ml.lock[])
      dbg "done-waiting"
  ml.lock[].release
  dbg "-"


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

