# Thread safe Msg Queue

import statemachine, msgarena, locks

type
  MsgQueuePtr* = ptr MsgQueue

  MsgQueue* = object
    name: string
    ownsCondAndLock: bool
    cond: TCond
    lock: TLock
    head: MsgPtr
    tail: MsgPtr

proc `$`*(mq: MsgQueuePtr): string =
  result =
    if mq == nil:
      "<nil>"
    else:
      "{" & $mq.name & ":" &
        " ownsCondAndLock=" & $mq.ownsCondAndLock &
        " head=" & $mq.head &
        " tail=" & $mq.tail &
      "}"

proc newMsgQueue*(name: string, cond: TCond, lock: TLock): MsgQueuePtr =
  ## Create a new MsgQueue passing the initialized condition and lock
  echo "newMsqQueue:+ with cond/lock name=" & name
  var mq = cast[MsgQueuePtr](allocShared(sizeof(MsgQueue)))
  mq.name = name
  mq.ownsCondAndLock = false
  mq.cond = cond;
  mq.lock = lock;
  mq.head = nil
  mq.tail = nil
  result = cast[MsgQueuePtr](mq)
  echo "newMsqQueue:- with cond/lock name=" & name

proc newMsgQueue*(name: string): MsgQueuePtr =
  var mq = cast[MsgQueuePtr](allocShared(sizeof(MsgQueue)))
  mq.name = name
  mq.ownsCondAndLock = true
  mq.cond.initCond()
  mq.lock.initLock()
  mq.head = nil
  mq.tail = nil
  result = cast[MsgQueuePtr](mq)

proc delMsgQueue*(mq: MsgQueuePtr) =
  assert(mq.head == nil)
  assert(mq.tail == nil)
  if mq.ownsCondAndLock:
    mq.cond.deinitCond()
    mq.lock.deinitLock()
  GcUnref(mq.name)
  deallocShared(mq)

proc addTail*(mq: MsgQueuePtr, msg: MsgPtr) =
  echo($mq.name & ".addTail: msg=" & $msg)
  mq.lock.acquire()
  block:
    if mq.head == nil:
      mq.head = msg
      mq.tail = msg
      echo($mq.name & ".addTail: add msg to empty and signal")
      mq.cond.signal()
    else:
      msg.next = nil
      mq.tail.next = msg
      mq.tail = msg
      echo($mq.name & ".addTail: add msg to non-empty NO signal")
  mq.lock.release()
  echo($mq.name & ".addTail: released")

proc rmvHeadNolock(mq: MsgQueuePtr): MsgPtr =
  echo($mq.name & ".rmvHeadNolock:+")
  result = mq.head
  mq.head = result.next
  result.next = nil
  if mq.head == nil:
    mq.tail = nil
  echo($mq.name & ".rmvHeadNolock:-")

proc rmvHead*(mq: MsgQueuePtr): MsgPtr =
  mq.lock.acquire()
  block:
    while mq.head == nil:
      echo($mq.name & ".rmvHead: waiting")
      mq.cond.wait(mq.lock)
    echo($mq.name & ".rmvHead: going")
    result = mq.rmvHeadNolock()
  mq.lock.release()

proc rmvHeadNonBlocking*(mq: MsgQueuePtr): MsgPtr =
  mq.lock.acquire()
  block:
    if mq.head == nil:
      result = nil
    else:
      result = mq.rmvHeadNolock()
  mq.lock.release()

