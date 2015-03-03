# Thread safe Msg Queue

import statemachine, msgarena, locks

type
  MsgQueuePtr* = ptr MsgQueue

  MsgQueue* = object
    cond: TCond
    lock: TLock
    head: MsgPtr
    tail: MsgPtr

proc newMsgQueue*(): MsgQueuePtr =
  var mq = cast[MsgQueuePtr](allocShared(sizeof(MsgQueue)))
  mq.cond.initCond()
  mq.lock.initLock()
  mq.head = nil
  mq.tail = nil
  result = cast[MsgQueuePtr](mq)

proc delMsgQueue*(mq: MsgQueuePtr) =
  assert(mq.head == nil)
  assert(mq.tail == nil)
  mq.cond.deinitCond()
  mq.lock.deinitLock()
  deallocShared(mq)

proc addTail*(mq: MsgQueuePtr, msg: MsgPtr) =
  mq.lock.acquire()
  block:
    if mq.head == nil:
      mq.head = msg
      mq.tail = msg
      mq.cond.signal()
    else:
      msg.next = nil
      mq.tail.next = msg
      mq.tail = msg
  mq.lock.release()

proc rmvHeadNolock(mq: MsgQueuePtr): MsgPtr =
  result = mq.head
  mq.head = result.next
  result.next = nil
  if mq.head == nil:
    mq.tail = nil

proc rmvHead*(mq: MsgQueuePtr): MsgPtr =
  mq.lock.acquire()
  block:
    while mq.head == nil:
      echo("waiting")
      mq.cond.wait(mq.lock)
    echo("rmvHead: going")
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

