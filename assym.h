#define IP_SRC	12
#define IP_DST	16
#define IP6_SRC	8
#define IP6_DST	24

#if defined(__ILP64__) || defined(_LP64)
#define M_NEXT		(8*0)
/* #define M_NEXTPKT	(8*1) */
#define M_DATA		(8*2)
/* #define M_OWNER		(8*3) */
#define M_LEN		(8*4)
#else
#define M_NEXT		(4*0)
/* #define M_NEXTPKT	(4*1) */
#define M_DATA		(4*2)
/* #define M_OWNER		(4*3) */
#define M_LEN		(4*4)
#endif
