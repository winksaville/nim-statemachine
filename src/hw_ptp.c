#include "hw_tp.h"

void ptp_hw_tp1(int int_arg, char *string_arg) {
  tracepoint(hw, tp1, int_arg, string_arg);
}
