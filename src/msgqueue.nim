# Thread safe Msg Queue

import statemachine, msgarena, locks

when not defined(release):
  const DBG = true
else:
  const DBG = false

type
  MsgQueuePtr* = ptr MsgQueue

  MsgQueue* = object
    name: string
    ownsCondAndLock: bool
    cond: ptr TCond
    lock: ptr TLock
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

proc newMsgQueue*(name: string, cond: ptr TCond, lock: ptr TLock): MsgQueuePtr =
  ## Create a new MsgQueue passing the initialized condition and lock
  var mq = cast[MsgQueuePtr](allocShared(sizeof(MsgQueue)))
  proc dbg(s:string) =
    when DBG: echo name & ".newMsgQueue(name,cond,lock):" & s
  dbg "+"
  mq.name = name
  mq.ownsCondAndLock = false
  mq.cond = cond;
  mq.lock = lock;
  mq.head = nil
  mq.tail = nil
  result = cast[MsgQueuePtr](mq)
  dbg "-"

proc newMsgQueue*(name: string): MsgQueuePtr =
  var mq = cast[MsgQueuePtr](allocShared(sizeof(MsgQueue)))
  proc dbg(s:string) =
    when DBG: echo name & ".newMsgQueue(name):" & s
  dbg "+"
  mq.name = name
  mq.ownsCondAndLock = true
  mq.cond = cast[ptr TCond](allocShared(sizeof(TCond)))
  mq.cond[].initCond()
  mq.lock = cast[ptr TLock](allocShared(sizeof(TLock)))
  mq.lock[].initLock()
  mq.head = nil
  mq.tail = nil
  result = cast[MsgQueuePtr](mq)
  dbg "-"

proc delMsgQueue*(mq: MsgQueuePtr) =
  proc dbg(s:string) =
    when DBG: echo mq.name & ".delMsgQueue:" & s
  dbg "+"
  assert(mq.head == nil)
  assert(mq.tail == nil)
  if mq.ownsCondAndLock:
    mq.cond[].deinitCond()
    freeShared(mq.cond)
    mq.lock[].deinitLock()
    freeShared(mq.lock)
  GcUnref(mq.name)
  deallocShared(mq)
  dbg "-"

proc addTail*(mq: MsgQueuePtr, msg: MsgPtr) =
  proc dbg(s:string) =
    when DBG: echo mq.name & ".addTail:" & s
  dbg "+ msg=" & $msg
  mq.lock[].acquire()
  dbg "got lock"
  block:
    msg.next = nil
    if mq.head == nil:
      mq.head = msg
      mq.tail = msg
      dbg "add msg to empty and signal"
      mq.cond[].signal()
    else:
      mq.tail.next = msg
      mq.tail = msg
      dbg "add msg to non-empty NO signal"
  dbg "releasing lock"
  mq.lock[].release()
  dbg "- msg=" & $msg

proc rmvHeadNolock(mq: MsgQueuePtr): MsgPtr =
  proc dbg(s:string) =
    when DBG: echo mq.name & ".rmvHeadNolock:" & s
  dbg "+"
  result = mq.head
  mq.head = result.next
  result.next = nil
  if mq.head == nil:
    mq.tail = nil
  dbg "- msg=" & $result

proc rmvHead*(mq: MsgQueuePtr): MsgPtr =
  proc dbg(s:string) =
    when DBG: echo mq.name & ".rmvHead:" & s
  dbg "+"
  mq.lock[].acquire()
  block:
    while mq.head == nil:
      dbg "waiting"
      mq.cond[].wait(mq.lock[])
    dbg "going"
    result = mq.rmvHeadNolock()
  mq.lock[].release()
  dbg "- msg=" & $result

proc rmvHeadNonBlocking*(mq: MsgQueuePtr): MsgPtr =
  proc dbg(s:string) =
    when DBG: echo mq.name & ".rmvHeadNonBlocking:" & s
  dbg "+"
  mq.lock[].acquire()
  block:
    if mq.head == nil:
      result = nil
    else:
      result = mq.rmvHeadNolock()
  mq.lock[].release()
  dbg "- msg=" & $result

proc emptyNolock*(mq: MsgQueuePtr): bool =
  ## Assume a lock is held outside
  result = mq.head != nil
