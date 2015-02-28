import unittest, tsq, messagearena, statemachine

suite "tsq unittests":
  test "new_del_tsq":

    var myq = newTsq()
    myq.delTsq()

  test "add_rmv":
    var
      ma = newMessageArena()
      myq = newTsq()
    myq.addTail(ma.getMessage(123, 0))
    var msg = myq.rmvHead()
    check msg != nil
    check msg.cmd == 123
