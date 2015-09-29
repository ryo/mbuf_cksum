/*	$NetBSD: puchiko nyu- $	*/

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
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
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

#include <mips/asm.h>
#include <machine/param.h>
#include "assym.h"

	.set	noreorder

#define	reg_tmp0		t0
#define	reg_tmp1		t1
#define	reg_tmp2		t2
#define	reg_tmp3		t3
#define	reg_tmp4		t4
#define	reg_tmp5		t5
#define	reg_tmp6		t6
#define	reg_tmp7		t7

#define	reg_byte_swapped	s0
#define	reg_w			s1
#define	reg_mlen		v1
#define	reg_m			a0
#define	reg_len			a1
#define	reg_sum			v0


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
#else
#define	ADDB	\
	lbu	reg_tmp0,(reg_w)		; \
	addiu	reg_w,reg_w,1			; \
	addu	reg_sum,reg_sum,reg_tmp0	; \
	ROL					; \
	not	reg_byte_swapped,reg_byte_swapped
#endif

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




NESTED(in_cksum,32,ra)
	subu	sp,sp,32
	sw	ra,28(sp)
	sw	s0,24(sp)
	sw	s1,20(sp)


	move	reg_sum,zero
	move	reg_byte_swapped,zero

	beq	reg_len,zero,mbuf_loop_done
	nop
mbuf_loop:
	beq	reg_m,zero,out_of_mbufs
	nop

	lw	reg_mlen,M_LEN(reg_m)
	lw	reg_w,M_DATA(reg_m)
	beq	reg_mlen,zero,mbuf_loop_continue
	#nop

	sltu	reg_tmp0,reg_mlen,reg_len
	bne	reg_tmp0,zero,1f
	nop
	move	reg_mlen,reg_len
1:
	subu	reg_len,reg_len,reg_mlen


	andi	reg_tmp0,reg_w,1
	beq	reg_tmp0,zero,1f
	#nop
	REDUCE
	ADDB
	FORWARD_MLEN(1)
1:


	sltu	reg_tmp0,reg_mlen,64
	bne	reg_tmp0,zero,do_cksum32_step1
	sltu	reg_tmp0,reg_mlen,32
do_cksum64:
	ADDH8(0)
	ADDH8(16)
	ADDH8(32)
	ADDH8(48)
	FORWARD_W(64)
	FORWARD_MLEN(64)

	sltu	reg_tmp0,reg_mlen,64
	beq	reg_tmp0,zero,do_cksum64
	#nop

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
	nop
	ADDH
	FORWARD_MLEN(2)
1:


	REDUCE


do_cksum1:
	andi	reg_tmp0,reg_mlen,1
	beq	reg_tmp0,zero,1f
	nop
	ADDB
1:


mbuf_loop_continue:
	lw	reg_m,M_NEXT(reg_m)
	bne	reg_len,zero,mbuf_loop
	nop

mbuf_loop_done:
	beq	reg_byte_swapped,zero,1f
	#nop
	REDUCE
	ROL
1:
	REDUCE
	REDUCE

in_cksum_return:
	not	v0,reg_sum
	lw	s1,20(sp)
	lw	s0,24(sp)
	lw	ra,28(sp)
	andi	v0,v0,0xffff
	j	ra
	addu	sp,sp,32


out_of_mbufs:
	sw	reg_sum,16(sp)
	sw	reg_byte_swapped,12(sp)

	la	a0,msg_out_of_data
	jal	_C_LABEL(printf)
	move	a1,reg_len

	lw	reg_sum,16(sp)
	lw	reg_byte_swapped,12(sp)
	j	mbuf_loop_done
	nop

	.rdata
msg_out_of_data:
	.asciiz	"cksum: out of data (%d byte short)\n"
	.text


END(in_cksum)
