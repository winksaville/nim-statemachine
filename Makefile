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
NIM_TARGET=$(SRC_DIR)/statemachine

#NIM_FLAGS=-d:useSysAssert -d:useGcAssert $(FAST_DEFINE) $(REL_DEFINE)
NIM_FLAGS= $(FAST_DEFINE) $(REL_DEFINE)

help:
	@echo "Usage:"
	@echo " targets:"
	@echo "   build  -- clean and builds statemachine"
	@echo "   run    -- run statemachine no parameters"
	@echo "   clean  -- remove build artifacts"
	@echo " options:"
	@echo "   loops=count                     -- optional number of loops for run"
	@echo "   rel={true|false} default false  -- release build"
	@echo "   fast={true|false} default false -- fastest running"

build: clean $(NIM_TARGET)

$(NIM_TARGET): $(NIM_TARGET).nim
	nim c $(NIM_FLAGS) $(NIM_TARGET).nim

run: $(NIM_TARGET)
	./$(NIM_TARGET) $(LOOPS)

clean:
	@rm -rf $(SRC_DIR)/nimcache $(NIM_TARGET)
