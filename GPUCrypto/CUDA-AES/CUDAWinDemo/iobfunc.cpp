#include "stdio.h" 

#if _MSC_VER >= 1900

_ACRTIMP_ALT FILE* __cdecl __acrt_iob_func(unsigned);

#ifdef __cplusplus 
extern "C"
#endif 

FILE* __cdecl __iob_func(unsigned i) {
	return __acrt_iob_func(i);
}

#endif /* _MSC_VER>=1900 */