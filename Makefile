# make with no parameters or help prints usage
# default to non-fast mode
ifeq ($(ptp),true)
  $(warning ptp==true)
  PTP_DEFINE=-d:PTP
  LTTNG_COMP_FLAGS=--passL:-llttng-ust
else
  $(warning ptp==false)
  PTP_DEFINE=--symbol:PTP
  LTTNG_COMP_FLAGS=
endif

# default to release build
ifeq ($(rel),)
  REL_DEFINE=-d:release
else ifeq ($(rel),true)
  REL_DEFINE=-d:release
else
  REL_DEFINE=
endif

# default to no loops parameter
ifeq ($(loops),)
  LOOPS=
else
  LOOPS=-l:$(loops)
endif

SRC_DIR=src
TEST_DIR=tests

NIM_SRC_TEST_TARGET=$(TEST_DIR)/test1
NIM_BIN_TEST_TARGET=$(TEST_DIR)/bin/test1

NIM_FLAGS= $(FAST_DEFINE) $(REL_DEFINE) $(PTP_DEFINE) $(LTTNG_COMP_FLAGS) --cincludes=.
#NIM_FLAGS= -d:useSysAssert -d:useGcAssert $(FAST_DEFINE) $(REL_DEFINE) $(PTP_DEFINE) $(LTTNG_COMP_FLAGS) --cincludes=.

NIM_TEST_FLAGS=$(FAST_DEFINE) $(REL_DEFINE) $(PTP_DEFINE) $(LTTNG_COMP_FLAGS) --cincludes=.
#NIM_TEST_FLAGS=-d:useSysAssert -d:useGcAssert $(FAST_DEFINE) $(REL_DEFINE) $(PTP_DEFINE) $(LTTNG_COMP_FLAGS) --cincludes=.

help:
	@echo "Usage:"
	@echo " targets:"
	@echo "   build          -- clean and build statemachine"
	@echo "   test           -- clean build and run the test"
	@echo "   build-test     -- build test"
	@echo "   run-test       -- run test"
	@echo "   run-lttng-test -- run test with lttng"
	@echo "   make-unittests -- clean build and run the tests"
	@echo "   unittests      -- clean build and run the tests"
	@echo "   run-unittests  -- run statemachine no parameters"
	@echo "   clean          -- remove build artifacts"
	@echo " options:"
	@echo "   loops=count                     -- optional number of loops for run"
	@echo "   rel={true|false} default false  -- release build"
	@echo "   fast={true|false} default false -- fastest running"

build: clean
	@mkdir -p $(SRC_DIR)/bin
	nim c $(NIM_FLAGS) $(SRC_DIR)/statemachine.nim
	nim c $(NIM_FLAGS) $(SRC_DIR)/msgqueue.nim
	nim c $(NIM_FLAGS) $(SRC_DIR)/msgarena.nim
	nim c $(NIM_FLAGS) $(SRC_DIR)/msglooper.nim

test: build-test run-test

build-test: clean-tests $(NIM_BIN_TEST_TARGET)

# We need to makedir here because its not automatically created and linking fails
$(NIM_BIN_TEST_TARGET): $(NIM_SRC_TEST_TARGET).nim Makefile
	@mkdir -p $(TEST_DIR)/bin
	nim c $(NIM_TEST_FLAGS) $<

run-test: $(NIM_BIN_TEST_TARGET)
	./$(NIM_BIN_TEST_TARGET) $(LOOPS)

run-test-lttng: $(NIM_BIN_TEST_TARGET)
	lttng create sm-test
	lttng enable-event -k sched_wakeup,sched_wakeup_new,sched_switch,sched_migrate_task,sched_wait_task,sched_process_wait,sched_process_fork,sched_process_exec
	lttng enable-event -u hw:tp1
	lttng start ; ./$(NIM_BIN_TEST_TARGET) $(LOOPS) ; lttng stop
	lttng view > x.txt
	grep hw:tp1 x.txt > y.txt
	lttng destroy

unittests: clean-tests make-unittests run-unittests

make-unittests:
	@mkdir -p $(TEST_DIR)/bin
	nim c $(NIM_TEST_FLAGS) $(TEST_DIR)/statemachine_unittests.nim
	nim c $(NIM_TEST_FLAGS) $(TEST_DIR)/msgqueue_unittests.nim

run-unittests:
	$(TEST_DIR)/bin/statemachine_unittests
	$(TEST_DIR)/bin/msgqueue_unittests


# Clean operations
clean:
	@rm -rf $(SRC_DIR)/nimcache $(SRC_DIR)/bin

clean-tests: clean
	@rm -rf $(TEST_DIR)/nimcache $(TEST_DIR)/bin
