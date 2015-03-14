const PTP = false

when PTP:
  {.compile: "src/hw_tp.c".}
  {.compile: "src/hw_ptp.c".}
  proc ptp_hw_tp1(int_arg: int, string_arg: cstring) {.importc, header: "src/hw_ptp.h".}

import times, parseopt2, os, strutils, threadpool, math, locks
import statemachine, msgarena, msgqueue, msglooper

when defined(release):
  const debug = false
else:
  const debug = true

# command line args
when debug: echo "paramCount=" & $paramCount() & " paramStr=" & $commandLineParams()

var
  loops = 10

for kind, key, val in getopt():
  when debug: echo "kind=" & $kind & " key=" & key & " val=" & val
  case kind:
  of cmdShortOption:
    case toLower(key):
    of "l": loops = parseInt(val)
    else: discard
  else: discard

type
  TSm = ref object of StateMachine
    done: bool
    doneLock: TLock
    doneCond: TCond
    loops: int
    counter: int
    ma: MsgArenaPtr # My message arena
    mq: MsgQueuePtr # My receive queue
    pq: MsgQueuePtr # Partner queue

proc `$`(sm: TSm): string =
  result =
    if sm == nil:
      "<nil>"
    else:
      "{" &
        $sm.name & ":" &
        " done=" & $sm.done &
        " loops=" & $sm.loops &
        " curState=" & $sm.curState &
        " counter1=" & $sm.counter &
        " mq=" & $sm.mq &
        " pq=" & $sm.pq &
      "}"

proc newTSm(name: string, loops: int, ma: MsgArenaPtr, mq: MsgQueuePtr, pq: MsgQueuePtr = nil): TSm =
  result = TSm(name: name, loops: loops, ma: ma, mq: mq, pq: pq)
  result.doneLock.initLock()
  result.doneCond.initCond()

proc getMessageCount(sm: TSm): int64 =
  result = sm.counter

method processMsg(sm: TSm, msg: MsgPtr) =
  #ptp_hw_tp1(2, "t5-processMsg:+")
  when debug: echo sm.name & ".processMsg:+ msg.cmd=" & $msg.cmd & " sm=" & $sm

  sm.counter += 1

  if not sm.done:
    # Send message to partner
    var newMsg = sm.ma.getMsg(msg.cmd + 1, 0)
    when debug: echo sm.name & ".processMsg:addTail newMsg to partner"
    sm.pq.addTail(newMsg)

  # return the message after processing
  when debug: echo sm.name & ".processMsg:retMsg"
  sm.ma.retMsg(msg)

  if (msg.cmd >= sm.loops):
    # We're done
    sm.done = true
    when PTP: ptp_hw_tp1(2, "t5-processMsg: sm.doneCond.signal()")
    sm.doneCond.signal()
    when PTP: ptp_hw_tp1(2, "t5-processMsg: done")
    when debug: echo sm.name & ": done"

  when debug: echo sm.name & ".processMsg:- msg.cmd=" & $cmd & " sm=" & $sm
  #ptp_hw_tp1(2, "t5-processMsg:-")

proc t5() =
  var
    ma = newMsgArena()
    mq1: MsgQueuePtr
    mq2: MsgQueuePtr
    sm1: TSm
    sm2: TSm

  if true:
    # Have both message queues use two different loopers
    var
      ml1 = newMsgLooper("ml1")
      ml2 = newMsgLooper("ml2")
    mq1 = newMsgQueue("mq1-ml1", ml1.cond, ml1.lock)
    mq2 = newMsgQueue("mq2-ml2", ml2.cond, ml2.lock)
    sm1 = newTSm("sm1", loops, ma, mq1, mq2)
    sm2 = newTSm("sm2", loops, ma, mq2, mq1)
    ml1.addMsgProcessor(sm1, mq1)
    ml2.addMsgProcessor(sm2, mq2)
  else:
    # Have both message queues use the same looper
    var
      ml1 = newMsgLooper("ml1")
    mq1 = newMsgQueue("mq1-ml1", ml1.cond, ml1.lock)
    mq2 = newMsgQueue("mq2-ml1", ml1.cond, ml1.lock)
    sm1 = newTSm("sm1", loops, ma, mq1, mq2)
    sm2 = newTSm("sm2", loops, ma, mq2, mq1)
    ml1.addMsgProcessor(sm1, mq1)
    ml1.addMsgProcessor(sm2, mq2)


  # The first message
  echo "test1: send first message"
  when PTP: ptp_hw_tp1(1, "t5-start")
  var
    startTime = epochTime()
    msg = ma.getMsg(1, 0)
  when PTP: ptp_hw_tp1(1, "t5-adding")
  sm1.mq.addTail(msg)
  when PTP: ptp_hw_tp1(1, "t5-added")

  # Wait till the SM's are done
  sm1.doneLock.acquire()
  while not sm1.done:
    sm1.doneCond.wait(sm1.doneLock)
  sm1.doneLock.release()

  sm2.doneLock.acquire()
  while not sm2.done:
    sm2.doneCond.wait(sm2.doneLock)
  sm2.doneLock.release()

  when PTP: ptp_hw_tp1(2, "t5-done")

  # With two loopers we are now at 7.7-8.0us/loop, the big change was
  # using when DBG: to remove the debug from msglooper.
  var
    endTime = epochTime()
    messageCount = sm1.getMessageCount() + sm2.getMessageCount()
    time = (((endTime - startTime) / float(messageCount))) * 1_000_000

  echo "t5 done: time=" & time.formatFloat(ffDecimal, 4) & "us/msg"
  echo "  sm1: " & $sm1
  echo "  sm2: " & $sm2

t5()
