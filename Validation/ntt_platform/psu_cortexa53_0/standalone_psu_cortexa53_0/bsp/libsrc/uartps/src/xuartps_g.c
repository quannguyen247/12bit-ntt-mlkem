#include "xuartps.h"

XUartPs_Config XUartPs_ConfigTable[] __attribute__ ((section (".drvcfg_sec"))) = {

	{
		"xlnx,zynqmp-uart", /* compatible */
		0xff010000, /* reg */
		0x5f5dd19, /* xlnx,clock-freq */
		0x0, /* xlnx,has-modem */
		0x39, /* clocks */
		0x4016, /* interrupts */
		0xf9010000 /* interrupt-parent */
	},
	 {
		 NULL
	}
};