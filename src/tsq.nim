# Thread safe Queue

import statemachine, messagearena, locks

type
  TsqPtr* = ptr Tsq

  Tsq* = object
    cond: TCond
    lock: TLock
    head: MessagePtr
    tail: MessagePtr

proc newTsq*(): TsqPtr =
  var mq = cast[TsqPtr](allocShared(sizeof(Tsq)))
  mq.cond.initCond()
  mq.lock.initLock()
  mq.head = nil
  mq.tail = nil
  result = cast[TsqPtr](mq)

proc delTsq*(tsq: TsqPtr) =
  var mq = cast[TsqPtr](tsq)
  assert(mq.head == nil)
  assert(mq.tail == nil)
  mq.cond.deinitCond()
  mq.lock.deinitLock()
  deallocShared(mq)

proc addTail*(tsq: TsqPtr, msg: MessagePtr) =
  echo "add: msg=" & $msg
  var mq = cast[TsqPtr](tsq)
  var msgPtr = msg # cast[MessagePtr](msg)
  mq.lock.acquire()
  block:
    if mq.head == nil:
      mq.head = msgPtr
      mq.tail = msgPtr
      #q.cond.signal()
    else:
      msgPtr.next = nil
      mq.tail.next = msgPtr
      mq.tail = msgPtr
  mq.lock.release()

proc rmvHead*(tsq: TsqPtr): MessagePtr =
  echo "rmvHead:"
  var mq = cast[TsqPtr](tsq)
  mq.lock.acquire()
  block:
    while mq.head == nil:
      echo("waiting")
      #mq.cond.wait(mq.lock)
    echo("rmvHead: going")
    var x = mq.head
    if x == nil:
      echo "x == nil"
    else:
      echo "x=" & $x
    echo("rmvHead: 2")
    mq.head = x.next
    x.next = nil
    echo("rmvHead: 3")
    if mq.head == nil:
      echo("rmvHead: 4")
      mq.tail = nil
      echo("rmvHead: 5")
    echo("rmvHead: 6")
    result = x # cast[MessageRef](x)
    if result == nil:
      echo "result == nil"
    else:
      echo "result=" & $result
  echo("rmvHead: 7")
  mq.lock.release()
