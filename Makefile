NIM_TARGET=statemachine
NIM_FLAGS=-d:useSysAssert -d:useGcAssert

$(NIM_TARGET): $(NIM_TARGET).nim
	nim c $(NIM_FLAGS) $<

release: $(NIM_TARGET).nim
	nim c --d:release $(NIM_FLAGS) $<

run: $(NIM_TARGET)
	./$(NIM_TARGET)

clean:
	@rm -rf nimcache $(NIM_TARGET)
