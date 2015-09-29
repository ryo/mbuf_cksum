#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <machine/param.h>
#include <sys/mbuf.h>
#include <sys/param.h>

/* for in_cksum() */
extern uint16_t in_cksum_dummy(struct mbuf *, int);
extern uint16_t in_cksum_netinet(struct mbuf *, int);	/* sys/netinet/in_cksum.c */
extern uint16_t in_cksum_old(struct mbuf *, int);	/* sys/arch/<arch>/<arch>/in_cksum.S */
extern uint16_t in_cksum_new(struct mbuf *, int);	/* your optimized in_cksum() */

/* for cpu_in_cksum() */
extern uint16_t cpu_in_cksum_dummy(struct mbuf *, int, int, uint32_t);
extern uint16_t cpu_in_cksum_netinet(struct mbuf *, int, int, uint32_t);/* sys/netinet/cpu_in_cksum.c */
extern uint16_t cpu_in_cksum_old(struct mbuf *, int, int, uint32_t);	/* sys/arch/<arch>/<arch>/in_cksum.S */
extern uint16_t cpu_in_cksum_new(struct mbuf *, int, int, uint32_t);	/* your optimized cpu_in_cksum() */


/* for build dummy mbuf */
#define	MAXPACKETSIZE	65535		/* but usually 1500~8k? */
#define	NTEST		10000	/* random pattern test */
#define	NLOOP		300000	/* benchmark loop num */

static void dump_mbuf(struct mbuf *);
static void dump_mbufchain(struct mbuf *);
static struct mbuf *build_random_mbufchain(int, int, int, int, int, int, int *);
static void release_mbuf_chain(struct mbuf *);
static struct mbuf *mbuf_get(void);
static struct mbuf *mbuf_gethdr(void);


/* for benchmarks */
static uint16_t mbufbench_in_cksum(char *, int, uint16_t (*)(struct mbuf *, int), struct mbuf *, int);
static uint16_t mbufbench_cpu_in_cksum(char *, int, uint16_t (*)(struct mbuf *, int, int, uint32_t), struct mbuf *, int);
static void stopwatch_start(void);
static void stopwatch_end(char *, int);

static int random_mbuf_test_in_cksum(void);
static int random_mbuf_test_cpu_in_cksum(void);
static int benchmark_mbuf_test_in_cksum(void);
static int benchmark_mbuf_test_cpu_in_cksum(void);

/* misc */
unsigned int random_range(unsigned int, unsigned int);
static void usage(void);


int debug_mode;
int randomcheck_mode;
int benchmark_mode;
int exit_anyerror;
unsigned long random_seed;

int do_bench_cpu_in_cksum = 1;	/* if 1, do cpu_in_cksum() test */
int do_bench_in_cksum = 1;	/* if 1, do in_cksum() test */


static void
usage()
{
	printf("usage: mtest [options]\n");
	printf("	-s #	set random seed (default: PID)\n");
	printf("\n");
	printf("	-b	benchmark mode (default)\n");
	printf("	-r	random check mode\n");
	printf("\n");
	printf("	-d	debug mode\n");
	printf("	-e	exit quickly if any error\n");
	exit(EXIT_FAILURE);
}

int
main(int argc, char *argv[])
{
	int ch, anyerror;

	random_seed = getpid();

	while ((ch = getopt(argc, argv, "bdes:r")) != -1) {
		switch (ch) {
		case 'b':
			benchmark_mode = 1;
			break;
		case 'd':
			debug_mode = 1;
			break;
		case 'e':
			exit_anyerror = 1;
			break;
		case 's':
			random_seed = strtol(optarg, NULL, 10);
			break;
		case 'r':
			randomcheck_mode = 1;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	/* no options treat as "-b" */
	if (benchmark_mode == 0 && randomcheck_mode == 0)
		benchmark_mode = 1;


	/* if not exists symbol of in_cksum_old, don't test in_cksum() */
	if (in_cksum_dummy == in_cksum_old)
		do_bench_in_cksum = 0;

	/* if not exists symbol of cpu_in_cksum_old, don't test cpu_in_cksum() */
	if (cpu_in_cksum_dummy == cpu_in_cksum_old)
		do_bench_cpu_in_cksum = 0;


	/*
	 * show testing environment
	 */
	printf("environment:\n");
	printf("  MSIZE: %d\n", MSIZE);
	printf("  sizeof_mbuf: %d	# sizeof(struct mbuf)\n", (int)sizeof(struct mbuf));
	printf("  has_in_cksum: %d\n", do_bench_in_cksum);
	printf("  has_cpu_in_cksum: %d\n", do_bench_cpu_in_cksum);
	printf("  seed: %lu		# srandom(%lu)\n", random_seed, random_seed);
	printf("\n\n");
	srandom(random_seed);


	anyerror = 0;

	/* test and benchmark "cpu_in_cksum()" */
	if (do_bench_cpu_in_cksum) {
		if (randomcheck_mode)
			anyerror = random_mbuf_test_cpu_in_cksum();

		if (benchmark_mode)
			benchmark_mbuf_test_cpu_in_cksum();
	}

	/* test and benchmark "in_cksum()" */
	if (do_bench_in_cksum) {
		if (randomcheck_mode)
			anyerror = random_mbuf_test_in_cksum();

		if (benchmark_mode)
			benchmark_mbuf_test_in_cksum();
	}

	return anyerror ? EXIT_FAILURE : EXIT_SUCCESS;
}

static int
benchmark_mbuf_test_in_cksum()
{
	struct mbuf *m;
	int i, len;
	int nloop;

	nloop = NLOOP;

	m = build_random_mbufchain(1, MAXPACKETSIZE, MLEN / 2, MLEN, 0, 0, &len);
	printf("start cksum benchmark: %d loop, mbuf chain size=%d\n", nloop, m->m_pkthdr.len);
	if (debug_mode)
		dump_mbufchain(m);

	for (i = 0; i < 3; i++) {
		printf("\nbenchmark loop %d/3\n", i + 1);

		mbufbench_in_cksum("empty(dummy)", nloop, in_cksum_dummy, m, len);
		mbufbench_in_cksum("arch(old)",    nloop, in_cksum_old, m, len);
		mbufbench_in_cksum("arch(new)",    nloop, in_cksum_new, m, len);
		mbufbench_in_cksum("netinet",      nloop, in_cksum_netinet, m, len);
	}

	release_mbuf_chain(m);

	return 0;
}

static int
benchmark_mbuf_test_cpu_in_cksum()
{
	struct mbuf *m;
	int i, len;
	int nloop;

	nloop = NLOOP;

	m = build_random_mbufchain(1, MAXPACKETSIZE, MLEN / 2, MLEN, 0, 0, &len);
	printf("start cksum benchmark: %d loop, mbuf chain size=%d\n", nloop, m->m_pkthdr.len);
	if (debug_mode)
		dump_mbufchain(m);

	for (i = 0; i < 3; i++) {
		printf("\nbenchmark loop %d/3\n", i + 1);

		mbufbench_cpu_in_cksum("empty(dummy)", nloop, cpu_in_cksum_dummy, m, len);
		mbufbench_cpu_in_cksum("arch(old)",    nloop, cpu_in_cksum_old, m, len);
		mbufbench_cpu_in_cksum("arch(new)",    nloop, cpu_in_cksum_new, m, len);
		mbufbench_cpu_in_cksum("netinet",      nloop, cpu_in_cksum_netinet, m, len);
	}

	release_mbuf_chain(m);

	return 0;
}

static int
random_mbuf_test_in_cksum()
{
	int i, ntest, nerror;

	nerror = 0;
	ntest = NTEST;
	for (i = 0; i < ntest; i++) {
		uint32_t sum1, sum2, sum3;
		struct mbuf *m;
		int len;

		if ((i % 500) == 0) {
			printf("%d/%d random mbuf test\n", i, ntest);
			fflush(stdout);
		}

		m = build_random_mbufchain(1, MAXPACKETSIZE, 1, MLEN, 0, MLEN, &len);
		if (debug_mode)
			dump_mbufchain(m);

		sum1 = in_cksum_netinet(m, len);
		sum2 = in_cksum_old(m, len);
		sum3 = in_cksum_new(m, len);

		if (sum1 != sum2 || sum2 != sum3) {
			nerror++;
			printf("CKSUM RESULT ERROR: netinet=0x%08x, arch=0x%08x, arch.new=0x%08x\n", sum1, sum2, sum3);
			dump_mbufchain(m);
		}

		release_mbuf_chain(m);

		if (nerror && exit_anyerror)
			exit(EXIT_FAILURE);
	}

	if (nerror)
		printf("done %d tests, %d errors\n", ntest, nerror);
	else
		printf("done %d tests, No error\n", ntest);

	return nerror;
}

static int
random_mbuf_test_cpu_in_cksum()
{
	int i, ntest, nerror;

	nerror = 0;
	ntest = NTEST;
	for (i = 0; i < ntest; i++) {
		uint32_t sum1, sum2, sum3;
		struct mbuf *m;
		int len;

		if ((i % 500) == 0) {
			printf("%d/%d random mbuf test\n", i, ntest);
			fflush(stdout);
		}

		m = build_random_mbufchain(1, MAXPACKETSIZE, 1, MLEN, 0, MLEN, &len);
		if (debug_mode)
			dump_mbufchain(m);

		sum1 = cpu_in_cksum_netinet(m, len, 0, 0);
		sum2 = cpu_in_cksum_old(m, len, 0, 0);
		sum3 = cpu_in_cksum_new(m, len, 0, 0);

		if (sum1 != sum2 || sum2 != sum3) {
			nerror++;
			printf("CKSUM RESULT ERROR: netinet=0x%08x, arch=0x%08x, arch.new=0x%08x\n", sum1, sum2, sum3);
			dump_mbufchain(m);
		}

		release_mbuf_chain(m);

		if (nerror && exit_anyerror)
			exit(EXIT_FAILURE);
	}

	if (nerror)
		printf("done %d tests, %d errors\n", ntest, nerror);
	else
		printf("done %d tests, No error\n", ntest);

	return nerror;
}


static struct mbuf *
mbuf_get()
{
	struct mbuf *m;

	m = malloc(MSIZE);
	memset(m, 0, sizeof(struct m_hdr));

	m->m_data = m->m_dat;
	m->m_len = MLEN;

	return m;
}

static struct mbuf *
mbuf_gethdr()
{
	struct mbuf *m;

	m = malloc(MSIZE);
	memset(m, 0, sizeof(struct m_hdr) + sizeof(struct pkthdr));

	m->m_flags |= M_PKTHDR;
	m->m_data = m->m_pktdat;
	m->m_len = MHLEN;

	return m;
}

static void
mbuf_randomfill(struct mbuf *m)
{
	unsigned char *p;
	int i;

	p = mtod(m, unsigned char *);
	for (i = 0; i < m->m_len; i++) {
		p[i] = random();
	}
}

static struct mbuf *
build_random_mbufchain(int minpktsize, int maxpktsize, int minfragsize, int maxfragsize, int minadj, int maxadj, int *totallen)
{
	struct mbuf *m0 = NULL;
	struct mbuf *m = NULL;
	int i, pktlen, left, mlen, adj;

	left = pktlen = random_range(minpktsize, maxpktsize);

	for (i = 0; left > 0; left -= mlen, i++) {
		mlen = random_range(minfragsize, maxfragsize);

		if (i == 0) {
			/* top of mbuf has PKTHDR */
			m0 = m = mbuf_gethdr();
			m->m_pkthdr.len = pktlen;
		} else {
			m->m_next = mbuf_get();
			m = m->m_next;
		}
		mbuf_randomfill(m);


		if (mlen > m->m_len)
			mlen = m->m_len;

		/* trim offset randomly */
		adj = MIN(maxadj, m->m_len - mlen);
		m->m_data += random_range(minadj, adj);

		m->m_len = mlen;
	}

	*totallen = pktlen;
	return m0;
}

static void
release_mbuf_chain(struct mbuf *m)
{
	struct mbuf *n;

	while (m != NULL) {
		n = m->m_next;
		free(m);
		m = n;
	}
}

/*
 * return random number between <start> and <end>
 */
unsigned int
random_range(unsigned int start, unsigned int end)
{
	unsigned int range;

	if (end <= start)
		return start;

	range = end - start;
	return start + random() % (range + 1);
}

static uint16_t
mbufbench_in_cksum(char *label, int nloop, uint16_t (*in_cksum_func)(struct mbuf *, int), struct mbuf *m, int len)
{
	uint16_t sum = 0;
	int i;

	stopwatch_start();

	for (i = 0; i < nloop; i++)
		sum = in_cksum_func(m, len);

	stopwatch_end(label, nloop);

	return sum;
}

static uint16_t
mbufbench_cpu_in_cksum(char *label, int nloop, uint16_t (*cpu_in_cksum_func)(struct mbuf *, int, int, uint32_t), struct mbuf *m, int len)
{
	uint16_t sum = 0;
	int i;

	stopwatch_start();

	for (i = 0; i < nloop; i++)
		sum = cpu_in_cksum_func(m, len, 0, 0);

	stopwatch_end(label, nloop);

	return sum;
}

static void
dump_mbuf(struct mbuf *m)
{
	int i;
	uint8_t *p;

	p = (uint8_t *)(m->m_data);

	printf("m: %p\n", m);

	printf("  m_flags:");
	if (m->m_flags & M_EXT)    printf(" M_EXT");
	if (m->m_flags & M_PKTHDR) printf(" M_PKTHDR");
	if (m->m_flags & M_EOR)    printf(" M_EOR");
	printf("\n");

	printf("  m_next: %p\n", m->m_next);
	if (m->m_flags & M_PKTHDR) {
		printf("  m_pkthdr.len: %d\n", m->m_pkthdr.len);
		printf("  m_pktdat: %p\n", m->m_pktdat);
		printf("  m_data: %p # m_pktdat + %d\n", m->m_data, (int)(m->m_data - m->m_pktdat));
	} else {
		printf("  m_dat: %p\n", m->m_dat);
		printf("  m_data: %p # m_dat + %d\n", m->m_data, (int)(m->m_data - m->m_dat));
	}


	if ((m->m_data + m->m_len) > (char *)m + MSIZE)
		printf("  m_len: %d # WARNING: (m_len + m_data) is larger than MSIZE(%d)\n", m->m_len, MSIZE);
	else
		printf("  m_len: %d\n", m->m_len);

	printf("  data: |\n");
	for (i = 0; i < m->m_len; i++) {
		if ((i & 15) == 0)
			printf("    %p(%04x):", p, i);

		printf(" %02x", *p++);

		if ((i & 15) == 15)
			printf("\n");
	}
	if ((i & 15) != 0)
		printf("\n");

	printf("\n");
}

static void
dump_mbufchain(struct mbuf *m)
{
	for (; m != NULL; m = m->m_next)
		dump_mbuf(m);
}


struct timeval tv0, tv1;
struct rusage ru0, ru1;

static void
stopwatch_start()
{
	memset(&tv0, 0, sizeof(tv0));
	memset(&tv1, 0, sizeof(tv1));

	gettimeofday(&tv0, NULL);
	getrusage(RUSAGE_SELF, &ru0);
}

static void
stopwatch_end(char *label, int nloop)
{
	uint64_t usr, sys, wal;
	int rc;

	gettimeofday(&tv1, NULL);
	rc = getrusage(RUSAGE_SELF, &ru1);

	usr = (ru1.ru_utime.tv_sec * 1000000ULL + ru1.ru_utime.tv_usec) -
	      (ru0.ru_utime.tv_sec * 1000000ULL + ru0.ru_utime.tv_usec);

	sys = (ru1.ru_stime.tv_sec * 1000000ULL + ru1.ru_stime.tv_usec) -
	      (ru0.ru_stime.tv_sec * 1000000ULL + ru0.ru_stime.tv_usec);

	wal = (tv1.tv_sec * 1000000ULL + tv1.tv_usec) -
	      (tv0.tv_sec * 1000000ULL + tv0.tv_usec);

	printf("%-20s ", label);
	printf("  %8llu usec (usr)", (unsigned long long)usr);
//	printf("  %8llu usec (sys)", (unsigned long long)sys);	/* BROKEN? */
	printf("  %8llu usec (wallclock)", (unsigned long long)wal);

	printf("    %10llu times/sec", nloop * 1000000ULL / usr);
	printf("\n");

	fflush(stdout);
}

void
panic(const char *fmt, ...)
{
	int ret;
	va_list ap;

	va_start(ap, fmt);
	ret = vfprintf(stdout, fmt, ap);
	va_end(ap);
	fflush(stdout);
	exit(EXIT_FAILURE);
}
