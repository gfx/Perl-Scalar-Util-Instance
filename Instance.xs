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
instance_isa(pTHX_ const MAGIC* const mg, SV* const instance){
    dMY_CXT;
    HV* const instance_stash = SvSTASH(SvRV(instance));
    GV* const instance_isa   = gv_fetchmeth_autoload(instance_stash, "isa", sizeof("isa")-1, 0);

    /* the instance has no own isa method */
    if(instance_isa == NULL || GvCV(instance_isa) == GvCV(MY_CXT.universal_isa)){
        HV* const klass_stash = (HV*)mg->mg_obj;

        if(klass_stash == instance_stash){
            return TRUE;
        }
        else{ /* look up @ISA hierarchy */
            const char* const klass_pv = mg->mg_ptr;
            AV*  const linearized_isa  = mro_get_linear_isa(instance_stash);
            SV**       svp             = AvARRAY(linearized_isa);
            SV** const end             = svp + AvFILLp(linearized_isa) + 1;

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
        const char* const klass_pv  = mg->mg_ptr;
        STRLEN const      klass_len = mg->mg_len;
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

XS(XS_isa_check); /* -W */
XS(XS_isa_check){
    dVAR;
    dXSARGS;
    SV* sv;

    assert(XSANY.any_ptr != NULL);

    if(items != 1){
        if(items < 1){
            croak("Not enough arguments for is-a predicate");
        }
        else{
            croak("Too many arguments for is-a predicate");
        }
    }

    sv = ST(0);
    SvGETMAGIC(sv);

    ST(0) = boolSV( SvROK(sv) && SvOBJECT(SvRV(sv)) && instance_isa(aTHX_ (MAGIC*)XSANY.any_ptr, sv) );
    XSRETURN(1);
}

XS(XS_isa_check_for_universal); /* -W */
XS(XS_isa_check_for_universal){
    dVAR;
    dXSARGS;
    SV* sv;
    PERL_UNUSED_VAR(cv);

    if(items != 1){
        if(items < 1){
            croak("Not enough arguments for is-a predicate");
        }
        else{
            croak("Too many arguments for is-a predicate");
        }
    }

    sv = ST(0);
    SvGETMAGIC(sv);

    ST(0) = boolSV( SvROK(sv) && SvOBJECT(SvRV(sv)) );
    XSRETURN(1);
}

static void
setup_my_cxt(pTHX_ pMY_CXT){
    MY_CXT.universal_isa = gv_fetchpvs("UNIVERSAL::isa", GV_ADD, SVt_PVCV);
    SvREFCNT_inc_simple_void_NN(MY_CXT.universal_isa);
}

MODULE = Scalar::Util::Instance    PACKAGE = Scalar::Util::Instance

PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    setup_my_cxt(aTHX_ aMY_CXT);
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    setup_my_cxt(aTHX_ aMY_CXT);
    PERL_UNUSED_VAR(items);
}

#endif /* !USE_ITHREADS */

void
generate_for(self, SV* klass, const char* predicate_name = NULL)
PPCODE:
{
    STRLEN klass_len;
    const char* klass_pv;
    HV* stash;
    CV* xsub;

    if(!SvOK(klass)){
        croak("You must define a class name for generate_for");
    }
    klass_pv = canonicalize_package_name( SvPV_const(klass, klass_len) );

    if(strNE(klass_pv, "UNIVERSAL")){
        xsub = newXS(predicate_name, XS_isa_check, __FILE__);

        stash = gv_stashpvn(klass_pv, klass_len, GV_ADD);

        CvXSUBANY(xsub).any_ptr = sv_magicext(
            (SV*)xsub,
            (SV*)stash, /* mg_obj */
            PERL_MAGIC_ext,
            &scalar_util_instance_vtbl,
            klass_pv,   /* mg_ptr */
            klass_len   /* mg_len */
        );
    }
    else{
        xsub = newXS(predicate_name, XS_isa_check_for_universal, __FILE__);
    }

    if(predicate_name == NULL){ /* anonymous predicate */
        XPUSHs( newRV_noinc((SV*)xsub) );
    }
}

