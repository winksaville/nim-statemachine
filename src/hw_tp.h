
#undef TRACEPOINT_PROVIDER
#define TRACEPOINT_PROVIDER hw

#undef TRACEPOINT_INCLUDE
#define TRACEPOINT_INCLUDE "src/hw_tp.h"

#if !defined(HW_TP_H) || defined(TRACEPOINT_HEADER_MULTI_READ)
#define HW_TP_H

#include <lttng/tracepoint.h>

TRACEPOINT_EVENT(
	hw,
	tp1,
	TP_ARGS(
		int, int_arg,
		char *, string_arg
	),
	TP_FIELDS(
		ctf_integer(int, int_field, int_arg)
		ctf_string(string_field, string_arg)
	)
)

#endif /* HW_TP_H */

#include <lttng/tracepoint-event.h>
