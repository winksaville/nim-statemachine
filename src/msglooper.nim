import os, threadpool, locks
import statemachine, msgqueue

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
    cond*: TCond
    lock*: TLock
    listMsgProcessorLen: int
    listMsgProcessor: ptr array[0..listMsgProcessorMaxLen-1, MsgProcessor]

# Global initialization lock and cond use to have newMsgLooper not return
# until looper has startend and MsgLooper is completely initialized.
var
  gInitLock: TLock
  gInitCond: TCond

gInitLock.initLock()
gInitCond.initCond()

proc looper(ml: MsgLooperPtr) =
  echo "looper:+ ml.name=" & ml.name
  var processedAtLeastOneMsg = false

  gInitLock.acquire()
  block:
    echo "looper: ml.name=" & ml.name & " initializing"
    # initialize MsgLooper
    ml.listMsgProcessorLen = 0
    ml.listMsgProcessor = cast[ptr array[0..listMsgProcessorMaxLen-1, MsgProcessor]](allocShared(sizeof(MsgProcessor) * listMsgProcessorMaxLen))
    ml.lock.initLock()
    ml.cond.initCond()
    echo "looper: ml.name=" & ml.name & " signal gInitCond"
    ml.initialized = true;
    gInitCond.signal()
  gInitLock.release()

  ml.lock.acquire()
  while not ml.done:
    echo "looper: ml.name=" & ml.name & " TOL ml.listMsgProcessorLen=" & $ml.listMsgProcessorLen
    for idx in 0..ml.listMsgProcessorLen-1:
      echo "looper: ml.name=" & ml.name & " idx=" & $idx
      var mp = ml.listMsgProcessor[idx]
      var msg = mp.mq.rmvHeadNonBlocking()
      echo "looper: ml.name=" & ml.name & " msg=" & $msg
      if msg != nil:
        echo "looper: ml.name=" & ml.name & " got msg=" & $msg
        processedAtLeastOneMsg = true
        mp.sm.sendMsg(msg)
        # who is to return the msg to the arena?????

    if (not ml.done) and (not processedAtLeastOneMsg):
      # No messages were processesed so wait for one to arrive
      echo "looper: ml.name=" & ml.name & " waiting"
      ml.cond.wait(ml.lock)
      echo "looper: ml.name=" & ml.name & " done-waiting"
      processedAtLeastOneMsg = false
    sleep(500)
  ml.lock.release()
  echo "looper:- ml.name=" & ml.name


proc newMsgLooper*(name: string): MsgLooperPtr =
  ## newMsgLooper does not return until the looper has started and
  ## everything is fully initialized
  echo "newMsgLooper:+ name=" & name

  # Use a global to coordinate initialization of the looper
  # We may want to make a MsgLooper an untracked structure
  # in the future.
  gInitLock.acquire()
  block:
    result = cast[MsgLooperPtr](allocShared(sizeof(MsgLooper)))
    result.name = name
    result.initialized = false;
    spawn looper(result)
    while (not result.initialized):
      echo "newMsgLooper: name=" & name & " waiting on gInitCond"
      gInitCond.wait(gInitLock)
    echo "newMsgLooper: name=" & name & " looper is initialized"
  gInitLock.release()

  echo "newMsgLooper:- name=" & name

proc delMsgLooper*(ml: MsgLooperPtr) =
  ## kills the message looper, andd message processors
  ## associated witht he looper will not receive any further
  ## messages and all queued up message are lost.
  ## So use this with care!!
  echo "delMsgLooper: empty"
  
proc addMsgProcessor*(ml: MsgLooperPtr, sm: StateMachine, mq: MsgQueuePtr) =
  echo "addMsgProcessor:+ ml.name=" & ml.name
  ml.lock.acquire()
  if ml.listMsgProcessorLen < listMsgProcessorMaxLen:
    echo "addMsgProcessor: ml.name=" & ml.name & "...."
    var mp = cast[MsgProcessor](allocShared(sizeof(MsgProcessor)))
    mp.sm = sm
    mp.mq = mq
    ml.listMsgProcessor[ml.listMsgProcessorLen] = mp
    ml.listMsgProcessorLen += 1
    ml.cond.signal()
  else:
    doAssert(ml.listMsgProcessorLen < listMsgProcessorMaxLen)
  ml.lock.release()
  echo "addMsgProcessor:- ml.name=" & ml.name

