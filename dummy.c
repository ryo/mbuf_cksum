#include <stdio.h>
#include <machine/param.h>
#include <sys/types.h>
#include <sys/mbuf.h>

#ifdef __weak_alias
__weak_alias(in_cksum_old, in_cksum_dummy)
__weak_alias(in_cksum_new, in_cksum_dummy)
__weak_alias(cpu_in_cksum_old, cpu_in_cksum_dummy)
__weak_alias(cpu_in_cksum_new, cpu_in_cksum_dummy)
#endif

uint16_t
in_cksum_dummy(struct mbuf *m, int len)
{
	return 0;
}

uint16_t
cpu_in_cksum_dummy(struct mbuf *m, int len, int off, uint32_t sum)
{
	return 0;
}
