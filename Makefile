# make with no parameters or help prints usage

ifeq ($(fast),true)
FAST_DEFINE=-d:fast
else
FAST_DEFINE=--symbol:fast
endif

ifeq ($(rel),true)
REL_DEFINE=-d:release
else
REL_DEFINE=
endif

ifeq ($(loops),)
LOOPS=
else
LOOPS=-l:$(loops)
endif

NIM_TARGET=statemachine

#NIM_FLAGS=-d:useSysAssert -d:useGcAssert $(FAST_DEFINE) $(REL_DEFINE)
NIM_FLAGS= $(FAST_DEFINE) $(REL_DEFINE)

help:
	@echo "Usage:"
	@echo " targets:"
	@echo "   build  -- builds statemachine"
	@echo "   run    -- run statemachine no parameters"
	@echo "   clean  -- remove build artifacts"
	@echo " options:"
	@echo "   loops=count                     -- optional number of loops for run"
	@echo "   rel={true|false} default false  -- release build"
	@echo "   fast={true|false} default false -- fastest running"

build: $(NIM_TARGET)

$(NIM_TARGET): $(NIM_TARGET).nim
	nim c $(NIM_FLAGS) $(NIM_TARGET).nim

run: $(NIM_TARGET)
	./$(NIM_TARGET) $(LOOPS)

clean:
	@rm -rf nimcache $(NIM_TARGET)
