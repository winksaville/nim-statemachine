# make with no parameters or help prints usage
# default to non-fast mode
ifeq ($(fast),true)
  FAST_DEFINE=-d:fast
else
  FAST_DEFINE=--symbol:fast
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

#NIM_FLAGS=-d:useSysAssert -d:useGcAssert $(FAST_DEFINE) $(REL_DEFINE)
NIM_FLAGS= $(FAST_DEFINE) $(REL_DEFINE)

NIM_TEST_FLAGS=-d:useSysAssert -d:useGcAssert $(FAST_DEFINE) $(REL_DEFINE)
#NIM_TEST_FLAGS=$(FAST_DEFINE) $(REL_DEFINE)

help:
	@echo "Usage:"
	@echo " targets:"
	@echo "   build          -- clean and build statemachine"
	@echo "   tests          -- clean build and run the tests"
	@echo "   make-unittests -- clean build and run the tests"
	@echo "   unittests      -- clean build and run the tests"
	@echo "   run-unittests  -- run statemachine no parameters"
	@echo "   clean          -- remove build artifacts"
	@echo " options:"
	@echo "   loops=count                     -- optional number of loops for run"
	@echo "   rel={true|false} default false  -- release build"
	@echo "   fast={true|false} default false -- fastest running"

build:
	@mkdir -p $(SRC_DIR)/bin
	nim c $(NIM_FLAGS) $(SRC_DIR)/msgqueue.nim
	nim c $(NIM_FLAGS) $(SRC_DIR)/msgarena.nim
	nim c $(NIM_FLAGS) $(SRC_DIR)/statemachine.nim

tests: clean-tests $(NIM_BIN_TEST_TARGET) run-tests

unittests: clean-tests make-unittests run-unittests

make-unittests:
	@mkdir -p $(TEST_DIR)/bin
	nim c $(NIM_TEST_FLAGS) $(TEST_DIR)/statemachine_unittests.nim
	nim c $(NIM_TEST_FLAGS) $(TEST_DIR)/msgqueue_unittests.nim

run-unittests:
	$(TEST_DIR)/bin/statemachine_unittests
	$(TEST_DIR)/bin/msgqueue_unittests

# We need to makedir here because its not automatically created and linking fails
$(NIM_BIN_TEST_TARGET): $(NIM_SRC_TEST_TARGET).nim Makefile
	@mkdir -p $(TEST_DIR)/bin
	nim c $(NIM_TEST_FLAGS) $<

run-tests: $(NIM_BIN_TEST_TARGET)
	./$(NIM_BIN_TEST_TARGET) $(LOOPS)


# Clean operations
clean:
	@rm -rf $(SRC_DIR)/nimcache $(SRC_DIR)/bin

clean-tests: clean
	@rm -rf $(TEST_DIR)/nimcache $(TEST_DIR)/bin
