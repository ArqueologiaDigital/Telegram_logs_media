/***************************************************************************************
 * MegaNet / Telebradesco modem cartridge hardware support - v6
 ****************************************************************************************/

#ifndef _CART_HW_MEGANET_H_
#define _CART_HW_MEGANET_H_

extern int meganet_is_cart(void);
extern void meganet_modem_reset(void);
extern void meganet_modem_install(void);

/* Optional low-level CPU bypass helpers for $200001-$20000D UART access. */
extern int meganet_modem_cpu_handles(unsigned int address);
extern unsigned int meganet_modem_cpu_read_8(unsigned int address);
extern unsigned int meganet_modem_cpu_read_16(unsigned int address);
extern void meganet_modem_cpu_write_8(unsigned int address, unsigned int value);
extern void meganet_modem_cpu_write_16(unsigned int address, unsigned int value);

#endif /* _CART_HW_MEGANET_H_ */
