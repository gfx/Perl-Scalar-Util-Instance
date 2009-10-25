#ifndef INLINED_STR_EQ_H
#define INLINED_STR_EQ_H

#ifdef INLINE_STR_EQ

#if (!defined(__cplusplus__) || !defined(__STDC_VERSION__) ||  (__STDC_VERSION__ < 199901L)) && !defined(inline)
#define inline
#endif


#undef strnEQ
static inline int
strnEQ(const char* const x, const char* const y, size_t const n){
    size_t i;
    for(i = 0; i < n; i++){
        if(x[i] != y[i]){
            return FALSE;
        }
    }
    return TRUE;
}
#undef strEQ
static inline int
strEQ(const char* const x, const char* const y){
    size_t i;
    for(i = 0; ; i++){
        if(x[i] != y[i]){
            return FALSE;
        }
        else if(x[i] == '\0'){
            return TRUE; /* y[i] is also '\0' */
        }
    }
    return TRUE; /* not reached */
}

#endif /* !INLINE_STR_EQ */

#endif /* include guard */
