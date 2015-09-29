#ifndef _KCOMPAT_H_
#define _KCOMPAT_H_

/*
 * XXX: define some macro inside "#ifdef _KERNEL ... #endif" in /usr/include/
 */
#define KASSERT(e)

#if 0
#define IPV6_ADDR_SCOPE_INTFACELOCAL	0x01
#define IPV6_ADDR_MC_SCOPE(a)	((a)->s6_addr[1] & 0x0f)

#define IN6_IS_ADDR_MC_INTFACELOCAL(a)	\
    (IN6_IS_ADDR_MULTICAST(a) &&	\
     (IPV6_ADDR_MC_SCOPE(a) == IPV6_ADDR_SCOPE_INTFACELOCAL))

#define IN6_IS_SCOPE_LINKLOCAL(a)	\
    ((IN6_IS_ADDR_LINKLOCAL(a)) ||	\
     (IN6_IS_ADDR_MC_LINKLOCAL(a)))

#define IN6_IS_SCOPE_EMBEDDABLE(__a)	\
    (IN6_IS_SCOPE_LINKLOCAL(__a) || IN6_IS_ADDR_MC_INTFACELOCAL(__a))
#endif

#endif /* _KCOMPAT_H_ */
