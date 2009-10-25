#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#define NEED_mro_get_linear_isa
#include "mro_compat.h"

#define INLINE_STR_EQ
#include "streq.h"

#define MY_CXT_KEY "Scalar::Util::Instance::_guts" XS_VERSION
typedef struct sui_cxt{
    GV* universal_isa;
} my_cxt_t;
START_MY_CXT

static MGVTBL scalar_util_instance_vtbl;

static const char*
canonicalize_package_name(const char* name){
    assert(name);
    /* "::Foo" -> "Foo" */
    if(name[0] == ':' && name[1] == ':'){
        name += 2;
    }

    /* "main::main::main::Foo" -> "Foo" */
    while(strnEQ(name, "main::", sizeof("main::")-1)){
        name += sizeof("main::")-1;
    }

    return name;
}

static int
check_isa(pTHX_ MAGIC* const mg, SV* const instance){
    dMY_CXT;
    const char* const klass_pv  = mg->mg_ptr;
    STRLEN const      klass_len = mg->mg_len;

    HV* const instance_stash = SvSTASH(SvRV(instance));
    GV* const instance_isa   = gv_fetchmeth_autoload(instance_stash, "isa", sizeof("isa")-1, 0);

    /* the instance has no own isa method */
    if(instance_isa == NULL || GvCV(instance_isa) == GvCV(MY_CXT.universal_isa)){
        HV* const klass_stash = (HV*)mg->mg_obj;

        if(klass_stash == instance_stash){
            return TRUE;
        }
        else{ /* look up @ISA hierarchy */
            AV*  const linearized_isa = mro_get_linear_isa(instance_stash);
            SV**       svp            = AvARRAY(linearized_isa);
            SV** const end            = svp + AvFILLp(linearized_isa) + 1; /* start + last index + 1 */

            while(svp != end){
                assert(SvPVX(*svp));
                if(strEQ(klass_pv, canonicalize_package_name(SvPVX(*svp)))){
                    return TRUE;
                }
                svp++;
            }
        }
        return FALSE;
    }
    /* the instance has its own isa method */
    else {
        int retval;
        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(instance);
        mPUSHp(klass_pv, klass_len);
        PUTBACK;

        call_sv((SV*)instance_isa, G_SCALAR);

        SPAGAIN;

        retval = SvTRUE(TOPs);
        (void)POPs;

        PUTBACK;

        FREETMPS;
        LEAVE;

        return retval;
    }
}

XS(XS_isa_checker); /* -W */
XS(XS_isa_checker){
    dVAR;
    dXSARGS;
    SV* sv;

    if(items != 1){
        if(items < 1){
            croak("Not enough arguments for is-a checker");
        }
        else{
            croak("Too many arguments for is-a checker");
        }
    }

    sv = ST(0);
    if( SvROK(sv) && SvOBJECT(SvRV(sv)) ){
        assert(XSANY.any_ptr != NULL);
        ST(0) = boolSV( check_isa(aTHX_ (MAGIC*)XSANY.any_ptr, sv) );
    }
    else {
        ST(0) = &PL_sv_no;
    }
    XSRETURN(1);
}

XS(XS_isa_checker_for_universal); /* -W */
XS(XS_isa_checker_for_universal){
    dVAR;
    dXSARGS;
    SV* sv;
    PERL_UNUSED_VAR(cv);

    if(items != 1){
        if(items < 1){
            croak("Not enough arguments for is-a checker");
        }
        else{
            croak("Too many arguments for is-a checker");
        }
    }

    sv = ST(0);
    ST(0) = boolSV( SvROK(sv) && SvOBJECT(SvRV(sv)) );
    XSRETURN(1);
}


MODULE = Scalar::Util::Instance    PACKAGE = Scalar::Util::Instance

PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    MY_CXT.universal_isa = CvGV(get_cv("UNIVERSAL::isa", GV_ADD));
    SvREFCNT_inc_simple_void_NN(MY_CXT.universal_isa);
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    MY_CXT.universal_isa = CvGV(get_cv("UNIVERSAL::isa", GV_ADD));
    SvREFCNT_inc_simple_void_NN(MY_CXT.universal_isa);
    PERL_UNUSED_VAR(items);
}

#endif /* !USE_ITHREADS */

SV*
generate_isa_checker_for(SV* klass)
CODE:
{
    STRLEN klass_len;
    const char* klass_pv;
    HV* stash;
    CV* xsub;

    if(!SvOK(klass)){
        croak("You must define a class name for generate_isa_checker");
    }
    klass_pv    = SvPV_const(klass, klass_len);

    if(strNE(klass_pv, "UNIVERSAL")){
        xsub = newXS(NULL, XS_isa_checker, __FILE__);

        stash = gv_stashpvn(klass_pv, klass_len, GV_ADD);

        CvXSUBANY(xsub).any_ptr = sv_magicext((SV*)xsub,
            (SV*)stash,
            PERL_MAGIC_ext,
            &scalar_util_instance_vtbl,
            canonicalize_package_name(klass_pv), klass_len);
    }
    else{
        xsub = newXS(NULL, XS_isa_checker_for_universal, __FILE__);
    }

    RETVAL = newRV_noinc((SV*)xsub);
}
OUTPUT:
    RETVAL

