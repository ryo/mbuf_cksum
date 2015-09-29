CC	?= cc
LD	= ${CC}

CFLAGS	= -pipe -Wall -O2 -fomit-frame-pointer
#CFLAGS	= -pipe -Wall -O2 -fomit-frame-pointer -fno-PIC
#CFLAGS	= -pipe -Wall -O2 -fno-PIC
#CFLAGS	+= -g
CFLAGS	+= -DIN_CKSUM_STANDALONE_TEST
CFLAGS	+= -DINET
CFLAGS	+= -DINET6 -DINET6_MD_CKSUM

KCFLAGS	= -D_LOCORE -D_KERNEL

# XXX: from bsd.own.mk
MACHINE_CPU=    ${MACHINE_ARCH:C/mipse[bl]/mips/:C/mips64e[bl]/mips/:C/sh3e[bl]/sh3/:S/m68000/m68k/:S/armeb/arm/:S/powerpc64/powerpc/}

.if exists (${MACHINE_CPU}/Makefile.inc)
.include "${MACHINE_CPU}/Makefile.inc"
.endif


NETBSDSRCDIR = /usr/src
IN_CKSUM_NETINET     = ${NETBSDSRCDIR}/sys/netinet/in_cksum.c
IN4_CKSUM_NETINET    = ${NETBSDSRCDIR}/sys/netinet/in4_cksum.c
CPU_IN_CKSUM_NETINET = ${NETBSDSRCDIR}/sys/netinet/cpu_in_cksum.c

PROGRAM	= mcheck

all:
	$(CC) --include kcompat.h -I . -Din_cksum=in_cksum_netinet -Din4_cksum=in4_cksum_netinet -Dcpu_in_cksum=cpu_in_cksum_netinet $(CFLAGS)            -c $(IN_CKSUM_NETINET)     -o netinet_in_cksum.o
	$(CC)                     -I . -Din_cksum=in_cksum_netinet -Din4_cksum=in4_cksum_netinet -Dcpu_in_cksum=cpu_in_cksum_netinet $(CFLAGS)            -c $(IN4_CKSUM_NETINET)    -o netinet_in4_cksum.o
	$(CC)                     -I . -Din_cksum=in_cksum_netinet -Din4_cksum=in4_cksum_netinet -Dcpu_in_cksum=cpu_in_cksum_netinet $(CFLAGS)            -c $(CPU_IN_CKSUM_NETINET) -o netinet_cpu_in_cksum.o
	$(CC)                     -I . -Din_cksum=in_cksum_old     -Din4_cksum=in4_cksum_old     -Dcpu_in_cksum=cpu_in_cksum_old     $(CFLAGS) $(KCFLAGS) -c $(CPU_IN_CKSUM_OLD)     -o arch_cpu_in_cksum_old.o
	$(CC)                     -I . -Din_cksum=in_cksum_new     -Din4_cksum=in4_cksum_new     -Dcpu_in_cksum=cpu_in_cksum_new     $(CFLAGS) $(KCFLAGS) -c $(CPU_IN_CKSUM_NEW)     -o arch_cpu_in_cksum_new.o
	$(CC) $(CFLAGS) -c -o dummy.o dummy.c
	$(CC) $(CFLAGS) -c -o mcheck.o mcheck.c
	$(LD) -o $(PROGRAM) *.o

clean:
	rm -f *.o $(PROGRAM)

