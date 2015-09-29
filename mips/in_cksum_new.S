/*	$NetBSD$	*/
/*	$Id: in_cksum_new.S,v 1.4 2007/11/22 22:20:32 ryo Exp $	*/

/*
 * Copyright (c) 2000 SHIMIZU Ryo
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef IN_CKSUM_STANDALONE_TEST
#define _LOCORE
	.abicalls
#endif

#include <machine/endian.h>
#include <machine/asm.h>
#include "assym.h"

	.set	noreorder

#if defined(__mips_n32) || defined(__mips_n64)
#define	reg_tmp0		t0	/* t4? */
#define	reg_tmp1		t1	/* t5? */
#define	reg_tmp2		t2	/* t6? */
#define	reg_tmp3		t3	/* t7? */
#define	reg_tmp4		a4
#define	reg_tmp5		a5
#define	reg_tmp6		a6
#define	reg_tmp7		a7
#else
#define	reg_tmp0		t0
#define	reg_tmp1		t1
#define	reg_tmp2		t2
#define	reg_tmp3		t3
#define	reg_tmp4		t4
#define	reg_tmp5		t5
#define	reg_tmp6		t6
#define	reg_tmp7		t7
#endif
#define	reg_tmp8		t8
#define	reg_tmp9		t9

#define	reg_byte_swapped	s0
#define	reg_w			s1
#define	reg_mlen		v1
#define	reg_m			a0
#define	reg_len			a1
#define	reg_sum			v0

#define	reg_in_nxt		a1
#define	reg_in_off		a2
#define	reg_in_len		a3

#define	REDUCE	\
	move	reg_tmp0,reg_sum		; \
	andi	reg_sum,reg_sum,0xffff		; \
	srl	reg_tmp0,reg_tmp0,16		; \
	addu	reg_sum,reg_sum,reg_tmp0

#define	ROL	\
	sll	reg_sum,reg_sum,8

#if BYTE_ORDER == BIG_ENDIAN
#define	ADDB	\
	lbu	reg_tmp0,(reg_w)		; \
	addiu	reg_w,reg_w,1			; \
	ROL					; \
	addu	reg_sum,reg_sum,reg_tmp0	; \
	not	reg_byte_swapped,reg_byte_swapped
#else /* BYTE_ORDER == BIG_ENDIAN */
#define	ADDB	\
	lbu	reg_tmp0,(reg_w)		; \
	addiu	reg_w,reg_w,1			; \
	addu	reg_sum,reg_sum,reg_tmp0	; \
	ROL					; \
	not	reg_byte_swapped,reg_byte_swapped
#endif /* BYTE_ORDER == BIG_ENDIAN */

#define	ADDH	\
	lhu	reg_tmp0,(reg_w)		; \
	addiu	reg_w,reg_w,2			; \
	addu	reg_sum,reg_sum,reg_tmp0

#define	ADDHH(idx)	\
	lhu	reg_tmp0,idx(reg_w)		; \
	lhu	reg_tmp1,idx+2(reg_w)		; \
	addu	reg_sum,reg_sum,reg_tmp0	; \
	addu	reg_sum,reg_sum,reg_tmp1

#define	ADDH4(idx)	\
	lhu	reg_tmp0,idx(reg_w)		; \
	lhu	reg_tmp1,idx+2(reg_w)		; \
	lhu	reg_tmp2,idx+4(reg_w)		; \
	lhu	reg_tmp3,idx+6(reg_w)		; \
	addu	reg_sum,reg_sum,reg_tmp0	; \
	addu	reg_sum,reg_sum,reg_tmp1	; \
	addu	reg_sum,reg_sum,reg_tmp2	; \
	addu	reg_sum,reg_sum,reg_tmp3

#define	ADDH8(idx)	\
	lhu	reg_tmp0,idx(reg_w)		; \
	lhu	reg_tmp1,idx+2(reg_w)		; \
	lhu	reg_tmp2,idx+4(reg_w)		; \
	lhu	reg_tmp3,idx+6(reg_w)		; \
	lhu	reg_tmp4,idx+8(reg_w)		; \
	lhu	reg_tmp5,idx+10(reg_w)		; \
	lhu	reg_tmp6,idx+12(reg_w)		; \
	lhu	reg_tmp7,idx+14(reg_w)		; \
	addu	reg_sum,reg_sum,reg_tmp0	; \
	addu	reg_sum,reg_sum,reg_tmp1	; \
	addu	reg_sum,reg_sum,reg_tmp2	; \
	addu	reg_sum,reg_sum,reg_tmp3	; \
	addu	reg_sum,reg_sum,reg_tmp4	; \
	addu	reg_sum,reg_sum,reg_tmp5	; \
	addu	reg_sum,reg_sum,reg_tmp6	; \
	addu	reg_sum,reg_sum,reg_tmp7

#define	FORWARD_MLEN(n)	\
	subu	reg_mlen,reg_mlen,n

#define	FORWARD_W(n)	\
	addiu	reg_w,reg_w,n


#if defined(INET6) && defined(INET6_MD_CKSUM)

#if BYTE_ORDER == BIG_ENDIAN
#define	IPV6_ADDR_INT16_LINKLOCAL_MASK	0xffc0
#define	IPV6_ADDR_INT16_LINKLOCAL	0xfe80
#define	IPV6_ADDR_INT16_MC_MASK		0xff0f
#define	IPV6_ADDR_INT16_MC_LINKLOCAL	0xff01
#define	IPV6_ADDR_INT16_MC_INTFACELOCAL	0xff02
#else /* BYTE_ORDER == BIG_ENDIAN */
#define	IPV6_ADDR_INT16_LINKLOCAL_MASK	0xc0ff
#define	IPV6_ADDR_INT16_LINKLOCAL	0x80fe
#define	IPV6_ADDR_INT16_MC_MASK		0x0fff
#define	IPV6_ADDR_INT16_MC_LINKLOCAL	0x01ff
#define	IPV6_ADDR_INT16_MC_INTFACELOCAL	0x02ff
#endif /* BYTE_ORDER == BIG_ENDIAN */

NESTED(in6_cksum,64,ra)
	subu	sp,sp,64
	sw	ra,60(sp)
	sw	s0,56(sp)
	sw	s1,52(sp)

	move	reg_byte_swapped,zero
	andi	reg_sum,reg_in_nxt,0x00ff
	beq	reg_sum,zero,skip_in_offset
	 move	reg_len,reg_in_len
#if BYTE_ORDER == LITTLE_ENDIAN
	sll	reg_sum,reg_sum,8
#endif
	move	reg_tmp0,reg_in_len
	srl	reg_tmp0,reg_tmp0,16
	andi	reg_tmp1,reg_in_len,0xffff
#if BYTE_ORDER == LITTLE_ENDIAN
	sll	reg_tmp0,reg_tmp0,8
	sll	reg_tmp1,reg_tmp1,8
#endif
	addu	reg_sum,reg_sum,reg_tmp0
	lw	reg_w,M_DATA(reg_m)
	andi	reg_tmp0,reg_w,1
	bne	reg_tmp0,zero,in6_odd_header
	 addu	reg_sum,reg_sum,reg_tmp1

in6_even_header:
	# 2byte aligned case
	lhu	reg_tmp0,IP6_SRC(reg_w)
	lhu	reg_tmp1,IP6_SRC+2(reg_w)
	lhu	reg_tmp2,IP6_SRC+4(reg_w)
	lhu	reg_tmp3,IP6_SRC+6(reg_w)
	lhu	reg_tmp4,IP6_SRC+8(reg_w)
	lhu	reg_tmp5,IP6_SRC+10(reg_w)
	lhu	reg_tmp6,IP6_SRC+12(reg_w)
	lhu	reg_tmp7,IP6_SRC+14(reg_w)

	# ip6_clearscope
	#   brokable register: v1(reg_mlen), a3(reg_in_len)
	andi	v1,reg_tmp0,IPV6_ADDR_INT16_LINKLOCAL_MASK	# v1 = (addr16[0] & 0xffc0);
	li	a3,IPV6_ADDR_INT16_LINKLOCAL			# if (v1 == 0xfe80)
	beq	v1,a3,1f					#   goto 1f;
	 andi	v1,reg_tmp0,IPV6_ADDR_INT16_MC_MASK		# v1 = (addr16[0] & 0xff0f)
	li	a3,IPV6_ADDR_INT16_MC_LINKLOCAL			# if (v1 == 0xff01)
	beq	v1,a3,1f					#   goto 1f;
	li	a3,IPV6_ADDR_INT16_MC_INTFACELOCAL		# if (v0 != 0xff02)
	bne	v1,a3,2f					#   goto 2f;
	 nop
1:	move	reg_tmp1,zero
2:

	addu	reg_sum,reg_sum,reg_tmp0
	addu	reg_sum,reg_sum,reg_tmp1
	addu	reg_sum,reg_sum,reg_tmp2
	addu	reg_sum,reg_sum,reg_tmp3
	addu	reg_sum,reg_sum,reg_tmp4
	addu	reg_sum,reg_sum,reg_tmp5
	addu	reg_sum,reg_sum,reg_tmp6
	addu	reg_sum,reg_sum,reg_tmp7

	lhu	reg_tmp0,IP6_DST(reg_w)
	lhu	reg_tmp1,IP6_DST+2(reg_w)
	lhu	reg_tmp2,IP6_DST+4(reg_w)
	lhu	reg_tmp3,IP6_DST+6(reg_w)
	lhu	reg_tmp4,IP6_DST+8(reg_w)
	lhu	reg_tmp5,IP6_DST+10(reg_w)
	lhu	reg_tmp6,IP6_DST+12(reg_w)
	lhu	reg_tmp7,IP6_DST+14(reg_w)

	# ip6_clearscope
	#   brokable register: v1(reg_mlen), a3(reg_in_len)
	andi	v1,reg_tmp0,IPV6_ADDR_INT16_LINKLOCAL_MASK	# v1 = (addr16[0] & 0xffc0);
	li	a3,IPV6_ADDR_INT16_LINKLOCAL			# if (v1 == 0xfe80)
	beq	v1,a3,1f					#   goto 1f;
	 andi	v1,reg_tmp0,IPV6_ADDR_INT16_MC_MASK		# v1 = (addr16[0] & 0xff0f)
	li	a3,IPV6_ADDR_INT16_MC_LINKLOCAL			# if (v1 == 0xff01)
	beq	v1,a3,1f					#   goto 1f;
	li	a3,IPV6_ADDR_INT16_MC_INTFACELOCAL		# if (v0 != 0xff02)
	bne	v1,a3,2f					#   goto 2f;
	 nop
1:	move	reg_tmp1,zero
2:

	addu	reg_sum,reg_sum,reg_tmp0
	addu	reg_sum,reg_sum,reg_tmp1
	addu	reg_sum,reg_sum,reg_tmp2
	addu	reg_sum,reg_sum,reg_tmp3
	addu	reg_sum,reg_sum,reg_tmp4
	addu	reg_sum,reg_sum,reg_tmp5
	addu	reg_sum,reg_sum,reg_tmp6
	b	skip_in_offset
	 addu	reg_sum,reg_sum,reg_tmp7


in6_odd_header:
	# 1byte aligned case
	lbu	reg_tmp0,IP6_SRC(reg_w)
	lhu	reg_tmp1,IP6_SRC+1(reg_w)
	lhu	reg_tmp2,IP6_SRC+3(reg_w)
	lhu	reg_tmp3,IP6_SRC+5(reg_w)
	lhu	reg_tmp4,IP6_SRC+7(reg_w)
	lhu	reg_tmp5,IP6_SRC+9(reg_w)
	lhu	reg_tmp6,IP6_SRC+11(reg_w)
	lhu	reg_tmp7,IP6_SRC+13(reg_w)
	lhu	reg_tmp8,IP6_SRC+15(reg_w)

	# ip6_clearscope
	#   brokable register: t8, t9, v1(reg_mlen), a3(reg_in_len), s0(reg_byte_swapped)
#if BYTE_ORDER == BIG_ENDIAN
	sll	reg_tmp9,reg_tmp0,8
	srl	reg_byte_swapped,reg_tmp1,8
	or	reg_tmp9,reg_tmp9,reg_byte_swapped
#else /* BYTE_ORDER == BIG_ENDIAN */
	andi	reg_tmp9,reg_tmp1,0x00ff
	sll	reg_tmp9,reg_tmp9,8
	or	reg_tmp9,reg_tmp9,reg_tmp0
#endif /* BYTE_ORDER == BIG_ENDIAN */
	andi	v1,reg_tmp9,IPV6_ADDR_INT16_LINKLOCAL_MASK	# v1 = (addr16[0] & 0xffc0);
	li	a3,IPV6_ADDR_INT16_LINKLOCAL			# if (v1 == 0xfe80)
	beq	v1,a3,1f					#   goto 1f;
	 andi	v1,reg_tmp9,IPV6_ADDR_INT16_MC_MASK		# v1 = (addr16[0] & 0xff0f)
	li	a3,IPV6_ADDR_INT16_MC_LINKLOCAL			# if (v1 == 0xff01)
	beq	v1,a3,1f					#   goto 1f;
	li	a3,IPV6_ADDR_INT16_MC_INTFACELOCAL		# if (v0 != 0xff02)
	bne	v1,a3,2f					#   goto 2f;
	 nop
1:
#if BYTE_ORDER == BIG_ENDIAN
	andi	reg_tmp1,reg_tmp1,0xff00
	andi	reg_tmp2,reg_tmp2,0x00ff
#else /* BYTE_ORDER == BIG_ENDIAN */
	andi	reg_tmp1,reg_tmp1,0x00ff
	andi	reg_tmp2,reg_tmp2,0xff00
#endif /* BYTE_ORDER == BIG_ENDIAN */
2:

#if BYTE_ORDER == BIG_ENDIAN
	ROL
	addu	reg_sum,reg_sum,reg_tmp0
#else
	addu	reg_sum,reg_sum,reg_tmp0
	ROL
#endif
	addu	reg_sum,reg_sum,reg_tmp1
	addu	reg_sum,reg_sum,reg_tmp2
	addu	reg_sum,reg_sum,reg_tmp3
	addu	reg_sum,reg_sum,reg_tmp4
	addu	reg_sum,reg_sum,reg_tmp5
	addu	reg_sum,reg_sum,reg_tmp6
	addu	reg_sum,reg_sum,reg_tmp7
	addu	reg_sum,reg_sum,reg_tmp8

	lhu	reg_tmp0,IP6_DST+1(reg_w)
	lhu	reg_tmp1,IP6_DST+3(reg_w)
	lhu	reg_tmp2,IP6_DST+5(reg_w)
	lhu	reg_tmp3,IP6_DST+7(reg_w)
	lhu	reg_tmp4,IP6_DST+9(reg_w)
	lhu	reg_tmp5,IP6_DST+11(reg_w)
	lhu	reg_tmp6,IP6_DST+13(reg_w)
	lbu	reg_tmp7,IP6_DST+15(reg_w)

	# ip6_clearscope
	#   brokable register: t8, t9, v1(reg_mlen), a3(reg_in_len), s0(reg_byte_swapped)
#if BYTE_ORDER == BIG_ENDIAN
	andi	reg_tmp9,reg_tmp8,0x00ff
	sll	reg_tmp9,reg_tmp9,8
	srl	reg_byte_swapped,reg_tmp0,8
	or	reg_tmp9,reg_tmp9,reg_byte_swapped
#else /* BYTE_ORDER == BIG_ENDIAN */
	srl	reg_tmp9,reg_tmp8,8
	andi	reg_byte_swapped,reg_tmp0,0x00ff
	sll	reg_byte_swapped,reg_byte_swapped,8
	or	reg_tmp9,reg_tmp9,reg_byte_swapped
#endif /* BYTE_ORDER == BIG_ENDIAN */
	andi	v1,reg_tmp9,IPV6_ADDR_INT16_LINKLOCAL_MASK	# v1 = (addr16[0] & 0xffc0);
	li	a3,IPV6_ADDR_INT16_LINKLOCAL			# if (v1 == 0xfe80)
	beq	v1,a3,1f					#   goto 1f;
	 andi	v1,reg_tmp9,IPV6_ADDR_INT16_MC_MASK		# v1 = (addr16[0] & 0xff0f)
	li	a3,IPV6_ADDR_INT16_MC_LINKLOCAL			# if (v1 == 0xff01)
	beq	v1,a3,1f					#   goto 1f;
	li	a3,IPV6_ADDR_INT16_MC_INTFACELOCAL		# if (v0 != 0xff02)
	bne	v1,a3,2f					#   goto 2f;
	 nop
1:
#if BYTE_ORDER == BIG_ENDIAN
	andi	reg_tmp0,reg_tmp0,0xff00
	andi	reg_tmp1,reg_tmp1,0x00ff
#else /* BYTE_ORDER == BIG_ENDIAN */
	andi	reg_tmp0,reg_tmp0,0x00ff
	andi	reg_tmp1,reg_tmp1,0xff00
#endif /* BYTE_ORDER == BIG_ENDIAN */
2:

	addu	reg_sum,reg_sum,reg_tmp0
	addu	reg_sum,reg_sum,reg_tmp1
	addu	reg_sum,reg_sum,reg_tmp2
	addu	reg_sum,reg_sum,reg_tmp3
	addu	reg_sum,reg_sum,reg_tmp4
	addu	reg_sum,reg_sum,reg_tmp5
	addu	reg_sum,reg_sum,reg_tmp6
	REDUCE
#if BYTE_ORDER == BIG_ENDIAN
	ROL
	addu	reg_sum,reg_sum,reg_tmp7
#else
	addu	reg_sum,reg_sum,reg_tmp7
	ROL
#endif
	b	skip_in_offset
	 move	reg_byte_swapped,zero
END(in6_cksum)

#endif /* defined(INET6) && defined(INET6_MD_CKSUM) */



#ifdef INET

NESTED(in4_cksum,64,ra)
	subu	sp,sp,64
	sw	ra,60(sp)
	sw	s0,56(sp)
	sw	s1,52(sp)

	move	reg_byte_swapped,zero
	andi	reg_sum,reg_in_nxt,0x00ff
	beq	reg_sum,zero,skip_in_offset
	 move	reg_len,reg_in_len
#if BYTE_ORDER == LITTLE_ENDIAN
	sll	reg_sum,reg_sum,8
	sll	reg_in_len,reg_in_len,8
#endif
	lw	reg_w,M_DATA(reg_m)
	andi	reg_tmp0,reg_w,1
	bne	reg_tmp0,zero,1f
	 addu	reg_sum,reg_in_len

	# 2byte aligned case
	lhu	reg_tmp1,IP_SRC(reg_w)
	lhu	reg_tmp2,IP_SRC+2(reg_w)
	lhu	reg_tmp3,IP_DST(reg_w)
	lhu	reg_tmp4,IP_DST+2(reg_w)
	addu	reg_sum,reg_sum,reg_tmp1
	addu	reg_sum,reg_sum,reg_tmp2
	addu	reg_sum,reg_sum,reg_tmp3
	b	9f
	 addu	reg_sum,reg_sum,reg_tmp4

1:
	# 1byte aligned case
	lbu	reg_tmp1,IP_SRC(reg_w)
	lhu	reg_tmp2,IP_SRC+1(reg_w)
	lhu	reg_tmp3,IP_SRC+3(reg_w)
	lhu	reg_tmp4,IP_SRC+5(reg_w)
	lbu	reg_tmp5,IP_SRC+7(reg_w)
#if BYTE_ORDER == BIG_ENDIAN
	ROL
	addu	reg_sum,reg_sum,reg_tmp1
#else
	addu	reg_sum,reg_sum,reg_tmp1
	ROL
#endif
	addu	reg_sum,reg_sum,reg_tmp2
	addu	reg_sum,reg_sum,reg_tmp3
	addu	reg_sum,reg_sum,reg_tmp4
	REDUCE
#if BYTE_ORDER == BIG_ENDIAN
	ROL
	addu	reg_sum,reg_sum,reg_tmp5
#else
	addu	reg_sum,reg_sum,reg_tmp5
	ROL
#endif

9:

#endif /* INET */

skip_in_offset:						# for (;;) {
	lw	reg_mlen,M_LEN(reg_m)			#   mlen = m->m_len
	sltu	reg_tmp0,reg_in_off,reg_mlen		#   if (mlen > off)
	bne	reg_tmp0,zero,9f			#     break;
	 nop						#
	lw	reg_m,M_NEXT(reg_m)			#   m = m->m_next
	bne	reg_m,zero,skip_in_offset		#
	 subu	reg_in_off,reg_in_off,reg_mlen		#   off -= mlen
							# }

	beq	reg_m,zero,out_of_mbufs			# if (!m) goto out_of_mbufs
	 nop
9:

	beq	reg_len,zero,mbuf_loop_done
	 lw	reg_w,M_DATA(reg_m)
	beq	reg_mlen,zero,mbuf_loop_continue
	 subu	reg_mlen,reg_mlen,reg_in_off		# m_len -= off
	b	in_cksum_inloop
	 addu	reg_w,reg_in_off			# m_data += off

#ifdef INET
END(in4_cksum)
#endif

#if defined(INET) || (defined(INET6) && defined(INET6_MD_CKSUM))

NESTED(in_cksum,64,ra)
	subu	sp,sp,64
	sw	ra,60(sp)
	sw	s0,56(sp)
	sw	s1,52(sp)

	move	reg_sum,zero
	beq	reg_len,zero,mbuf_loop_done
	 move	reg_byte_swapped,zero

mbuf_loop:
	beq	reg_m,zero,out_of_mbufs
	 nop

	lw	reg_mlen,M_LEN(reg_m)
	lw	reg_w,M_DATA(reg_m)
	beq	reg_mlen,zero,mbuf_loop_continue
	#nop	# or execute next op (sltu ...) speculatively

in_cksum_inloop:
	sltu	reg_tmp0,reg_mlen,reg_len
	bne	reg_tmp0,zero,1f
	 nop
	move	reg_mlen,reg_len
1:
	subu	reg_len,reg_len,reg_mlen


	andi	reg_tmp0,reg_w,1
	beq	reg_tmp0,zero,1f
	#nop	# or execute next macro speculatively
	REDUCE
	ADDB
	FORWARD_MLEN(1)
1:


do_cksum64:
	sltu	reg_tmp0,reg_mlen,64
	bne	reg_tmp0,zero,do_cksum32_step1
	 sltu	reg_tmp0,reg_mlen,32
do_cksum64_step1:
	ADDH8(0)
	ADDH8(16)
	ADDH8(32)
	ADDH8(48)
	FORWARD_W(64)
	FORWARD_MLEN(64)

	sltu	reg_tmp0,reg_mlen,64
	beq	reg_tmp0,zero,do_cksum64_step1
	#nop	# or execute next (sltu ...) op speculatively


do_cksum32:
	sltu	reg_tmp0,reg_mlen,32
do_cksum32_step1:
	bne	reg_tmp0,zero,do_cksum16_step1
	 sltu	reg_tmp0,reg_mlen,16
	ADDH8(0)
	ADDH8(16)
	FORWARD_W(32)
	FORWARD_MLEN(32)


do_cksum16:
	sltu	reg_tmp0,reg_mlen,16
do_cksum16_step1:
	bne	reg_tmp0,zero,do_cksum8_step1
	 sltu	reg_tmp0,reg_mlen,8
	ADDH8(0)
	FORWARD_W(16)
	FORWARD_MLEN(16)


do_cksum8:
	sltu	reg_tmp0,reg_mlen,8
do_cksum8_step1:
	bne	reg_tmp0,zero,do_cksum4_step1
	 sltu	reg_tmp0,reg_mlen,4
	ADDH4(0)
	FORWARD_W(8)
	FORWARD_MLEN(8)


do_cksum4:
	sltu	reg_tmp0,reg_mlen,4
do_cksum4_step1:
	bne	reg_tmp0,zero,do_cksum2_step1
	 sltu	reg_tmp0,reg_mlen,2
	ADDHH(0)
	FORWARD_W(4)
	FORWARD_MLEN(4)
1:


do_cksum2:
	sltu	reg_tmp0,reg_mlen,2
do_cksum2_step1:
	bne	reg_tmp0,zero,1f
	#nop	# or execute next (ADDH;lhu reg_tmp0,...) op speculatively
	ADDH
	FORWARD_MLEN(2)
1:

do_cksum1:
	andi	reg_tmp0,reg_mlen,1
	beq	reg_tmp0,zero,1f
	#nop	# or execute next macro speculatively
	REDUCE
	ADDB
1:

mbuf_loop_continue:
	bne	reg_len,zero,mbuf_loop
	 lw	reg_m,M_NEXT(reg_m)

mbuf_loop_done:
	beq	reg_byte_swapped,zero,1f
	#nop	# or execute next macro speculatively
	REDUCE
	ROL
1:
	REDUCE
	REDUCE

in_cksum_return:
	not	v0,reg_sum
	lw	s1,52(sp)
	lw	s0,56(sp)
	lw	ra,60(sp)
	andi	v0,v0,0xffff
	j	ra
	addu	sp,sp,64


out_of_mbufs:
	sw	reg_sum,48(sp)
	sw	reg_byte_swapped,44(sp)

	la	a0,msg_out_of_data
	jal	_C_LABEL(printf)
	move	a1,reg_len

	lw	reg_sum,48(sp)
	b	mbuf_loop_done
	 lw	reg_byte_swapped,44(sp)


	.rdata
msg_out_of_data:
	.asciiz	"cksum: out of data (%d byte short)\n"
	.text

END(in_cksum)
#endif /* defined(INET) || (defined(INET6) && defined(INET6_MD_CKSUM)) */
