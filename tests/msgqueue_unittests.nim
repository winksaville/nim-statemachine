import unittest, msgqueue, msgarena, statemachine

suite "msgqueue unittests":
  test "new_del_msgqueue":

    var myq = newMsgQueue()
    myq.delMsgQueue()

  test "add_rmv":
    var
      ma = newMsgArena()
      myq = newMsgQueue()
    myq.addTail(ma.getMsg(123, 0))
    var msg = myq.rmvHead()
    check msg != nil
    check msg.cmd == 123

  test "rmvHeadNonBlocking":
    var
      ma = newMsgArena()
      myq = newMsgQueue()
      msg = myq.rmvHeadNonBlocking()
    check msg == nil
