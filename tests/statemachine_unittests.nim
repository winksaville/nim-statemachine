import unittest, statemachine, msgarena, times, parseopt2, os, strutils

type
  TestSm = ref object of StateMachine
    counter1: int
    counter2: int

var
  loops = 11

for kind, key, val in getopt():
  echo "kind=" & $kind & " key=" & key & " val=" & val
  case kind:
  of cmdShortOption:
    case toLower(key):
    of "l": loops = parseInt(val)
    else: discard
  else: discard

method processMsg(sm: TestSm, msg: MsgPtr) =
  case sm.curState
  of 1:
    sm.counter1 += 1
    sm.transitionTo(2)
  of 2:
    sm.counter2 += 1
    sm.transitionTo(1)
  else:
    echo "TestSm default state"

suite "statemachine unittests":
  test "fast test":
    var
      testSm1 = TestSm(curState: 1)
      ma = newMsgArena()
      cmdVal = 1i32
      msg = ma.getMsg(cmdVal, 0)
      startTime = epochTime()

    for loop in 1..loops:
      cmdVal += 1
      msg.cmd = cmdVal # 2.3ns/loop
      testSm1.sendMsg(msg)

    var
      endTime = epochTime()
      time = (((endTime - startTime) / float(loops))) * 1_000_000_000

    echo("test1: time=" & time.formatFloat(ffDecimal, 4) & "ns/loop" & " testSm1=" & $testSm1[])

    check (testSm1.counter1 == (loops div 2 + loops mod 2))
    check (testSm1.counter2 == loops div 2)

  test "message each loop test":
    var
      testSm1 = TestSm(curState: 1)
      cmdVal = 1i32
      ma = newMsgArena()
      startTime = epochTime()

    for loop in 1..loops:
      cmdVal += 1
      testSm1.sendMsg(ma.getMsg(cmdVal, 0))

    var
      endTime = epochTime()
      time = (((endTime - startTime) / float(loops))) * 1_000_000_000

    echo("test1: time=" & time.formatFloat(ffDecimal, 4) & "ns/loop" & " testSm1=" & $testSm1[])

    check (testSm1.counter1 == (loops div 2 + loops mod 2))
    check (testSm1.counter2 == loops div 2)
