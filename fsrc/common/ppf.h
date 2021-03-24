/*************************************************************************/
/*
 * ppf.h defines the following preprocessing flags (the first value is default).
 *
 * __DEBUGGING__               debug or not: 0, 1
 * __FORTRAN_STANDARD__        which Fortran standard to follow: 2003, 2008
 * __USE_INTRINSIC_ALGEBRA__   use intrinsic procedures like matmul or not: 0, 1
 * __USE_POWELL_ALGEBRA__      use Powell's linear algebra procedures or not: 0, 1
 * __INTEGER_KIND__            the integer kind to be used: 0, 32, 64, 16
 * __REAL_PRECISION__          the real precision to be used: 64, 32, 128, 0
 * __USE_IEEE_ARITHMETIC__     use the IEEE_ARITHMETIC intrinsic or not: 0, 1
 * __USE_STORAGE_SIZE__        use the STORAGE_SIZE intrinsic or not: 0, 1
 * __USE_ISO_FORTRAN_ENV_INTREAL__ use the ISO_FORTRAN_ENV module or not: 0, 1
 *
 * You may change these flags, but make sure that your compiler is supportive
 * when changing __INTEGER_KIND__, __REAL_PRECISION__, __FORTRAN_STANDARD__,
 * __USE_IEEE_ARITHMETIC__ (Fortran 2003),
 * __USE_STORAGE_SIZE__ (Fortran 2008),
 * __USE_ISO_FORTRAN_ENV_INTREAL__ (Fortran 2008).
 *
 * Why not define these flags as parameters in the Fortran code, e.g.,
 *
 * logical, parameter :: __DEBUGGING__ = .false. ?
 *
 * Such a definition will work for __DEBUGGING__, but not for the flags that
 * depend on the compiler, for instance, __USE_IEEE_ARITHMETIC__.
*/
/*************************************************************************/


/*************************************************************************/
/* Are we debugging? */
#if defined __DEBUGGING__
#undef __DEBUGGING__
#endif
#define __DEBUGGING__ 1
/*************************************************************************/


/*************************************************************************/
/* Which Fortran standard to follow? */
#if defined __FORTRAN_STANDARD__
#undef __FORTRAN_STANDARD__
#endif
#define __FORTRAN_STANDARD__ 2003
/*************************************************************************/


/*************************************************************************/
/* Do we use the intrinsic algebra procedures (e.g., matmul)? */
/* If no, we use the procedures implemented in lina.F. */
#if defined __USE_INTRINSIC_ALGEBRA__
#undef __USE_INTRINSIC_ALGEBRA__
#endif
#define __USE_INTRINSIC_ALGEBRA__ 1
/*************************************************************************/


/*************************************************************************/
/* Do we use Powell's linear algebra procedures? */
/* If not, the implementation of some algebraic calculations will be
 * modified, mainly by replacing loops with matrix/vector operations.
 * This does not change Powell's algorithms, but it may not produce
 * exactly the same results as Powell's code due to properties of
 * floating-point arithmetic, e.g., the non-associativity of floating-point
 * addition and multiplication. */
#if defined __USE_POWELL_ALGEBRA__
#undef __USE_POWELL_ALGEBRA__
#endif
#define __USE_POWELL_ALGEBRA__ 1
/*************************************************************************/


/*************************************************************************/
/* Which integer kind to use?
 * 0 = default INTEGER, 16 = INTEGER*2, 32 = INTEGER*4, 64 = INTEGER*8.
 * Make sure that your compiler supports the selected kind. */
#if defined __INTEGER_KIND__
#undef __INTEGER_KIND__
#endif
#define __INTEGER_KIND__ 0
/* Fortran standards guarantee that 0 is supported, but not the others. */
/*************************************************************************/


/*************************************************************************/
/* Which real kind to use?
 * 0 = default REAL (SINGLE PRECISION), 32 = REAL*4, 64 = REAL*8, 128 = REAL*16.
 * Make sure that your compiler supports the selected kind.
 * Note: The default REAL (i.e., 0) is the single-precision REAL. */
#if defined __REAL_PRECISION__
#undef __REAL_PRECISION__
#endif
#define __REAL_PRECISION__ 64
/* Fortran standards guarantee that 0, 32, and 64 are supported, but not 128. */

/* Is quad precision available on this platform (compiler, hardware ...)? */
/* Note:
 * 1. Not all platforms support REAL128. For example, pgfortran 19 does not.
 * 2. It is not guaranteed that REAL128 has a wider range than REAL64. For
 *    example, REAL128 of nagfor 7.0 has a range of 291, while REAL64
 *    has a range of 307.
 * 3. It is rarely a good idea to use REAL128 as the working precision,
 *    which is probably inefficient and unnecessary. */
#if defined __QP_AVAILABLE__
#undef __QP_AVAILABLE__
#endif
/* Change the following line to set __QP_AVAILABLE__ to 1 if REAL128 is
 * available and if you intend to use it.
 * Note:
 * 1. Do NOT change is unless you are really sure.
 * 2. If the code is interfaced with MATLAB, then you still need to modify
 *    mexapi.F to set __USE_QP__ to 1. */
#define __QP_AVAILABLE__ 0

/* Revise __REAL_PRECISION__ according to __QP_AVAILABLE__ . */
#if __QP_AVAILABLE__ != 1 && __REAL_PRECISION__ > 64
#undef __REAL_PRECISION__
#define __REAL_PRECISION__ 64
#endif
/*************************************************************************/


/*************************************************************************/
/* Do we use the IEEE_ARITHMETIC intrinsic module? (Fortran 2003) */
#if defined __USE_IEEE_ARITHMETIC__
#undef __USE_IEEE_ARITHMETIC__
#endif
#define __USE_IEEE_ARITHMETIC__ 0

/* As of gfortran 5.5, it seems that the IEEE_ARITHMETIC of gfortran does
 * not support REAL128. */
#if defined __GFORTRAN__
#if __REAL_PRECISION__ <= 64 && __GNUC__ >= 5
#undef __USE_IEEE_ARITHMETIC__
#define __USE_IEEE_ARITHMETIC__ 1
#endif
#endif

#if defined __INTEL_COMPILER
#if __INTEL_COMPILER >= 1110
#undef __USE_IEEE_ARITHMETIC__
#define __USE_IEEE_ARITHMETIC__ 1
#endif
#endif

#if defined __NAG_COMPILER_RELEASE
#if __NAG_COMPILER_RELEASE >= 50
#undef __USE_IEEE_ARITHMETIC__
#define __USE_IEEE_ARITHMETIC__ 1
#endif
#endif

#if defined __PGI
#if __PGIC__ >= 11 && __PGIC_MINOR__ >= 1
#undef __USE_IEEE_ARITHMETIC__
#define __USE_IEEE_ARITHMETIC__ 1
#endif
#endif

#if defined __ibmxl__
#if __ibmxl_version__ >= 13 && __ibmxl_release__ >= 1
#undef __USE_IEEE_ARITHMETIC__
#define __USE_IEEE_ARITHMETIC__ 1
#endif
#endif

#if __FORTRAN_STANDARD__ < 2003
#undef __USE_IEEE_ARITHMETIC__
#define __USE_IEEE_ARITHMETIC__ 0
#endif
/*************************************************************************/


/*************************************************************************/
/* Do we use the STORAGE_SIZE intrinsic? (Fortran 2008) */
#if defined __USE_STORAGE_SIZE__
#undef __USE_STORAGE_SIZE__
#endif
#define __USE_STORAGE_SIZE__ 0

#if defined __GFORTRAN__
#if __GNUC__ >= 5 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 6)
#undef __USE_STORAGE_SIZE__
#define __USE_STORAGE_SIZE__ 1
#endif
#endif

#if defined __INTEL_COMPILER
#if __INTEL_COMPILER >= 1710
#undef __USE_STORAGE_SIZE__
#define __USE_STORAGE_SIZE__ 1
#endif
#endif

#if defined __NAG_COMPILER_RELEASE
#if __NAG_COMPILER_RELEASE >= 53
#undef __USE_STORAGE_SIZE__
#define __USE_STORAGE_SIZE__ 1
#endif
#endif

#if defined __PGI
#if __PGIC__ >= 15 && __PGIC_MINOR__ >= 4
#undef __USE_STORAGE_SIZE__
#define __USE_STORAGE_SIZE__ 1
#endif
#endif

#if defined __ibmxl__
#if __ibmxl_version__ >= 15 && __ibmxl_release__ >= 2
#undef __USE_STORAGE_SIZE__
#define __USE_STORAGE_SIZE__ 1
#endif
#endif

#if __FORTRAN_STANDARD__ < 2008
#undef __USE_STORAGE_SIZE__
#define __USE_STORAGE_SIZE__ 0
#endif
/*************************************************************************/


/*************************************************************************/
/* Do we use INT16, IN32, INT64, REAL32, REAL64, REAL128 from ISO_FORTRAN_ENV?
 * (Fortran 2008) */
#if defined __USE_ISO_FORTRAN_ENV_INTREAL__
#undef __USE_ISO_FORTRAN_ENV_INTREAL__
#endif
#define __USE_ISO_FORTRAN_ENV_INTREAL__ 0

#if defined __GFORTRAN__
#if __GNUC__ >= 5 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 5)
#undef __USE_ISO_FORTRAN_ENV_INTREAL__
#define __USE_ISO_FORTRAN_ENV_INTREAL__ 1
#endif
#endif

#if defined __INTEL_COMPILER
#if __INTEL_COMPILER >= 1640
#undef __USE_ISO_FORTRAN_ENV_INTREAL__
#define __USE_ISO_FORTRAN_ENV_INTREAL__ 1
#endif
#endif

#if defined __NAG_COMPILER_RELEASE
#if __NAG_COMPILER_RELEASE >= 53
#undef __USE_ISO_FORTRAN_ENV_INTREAL__
#define __USE_ISO_FORTRAN_ENV_INTREAL__ 1
#endif
#endif

#if defined __PGI
#if __PGIC__ >= 14 && __PGIC_MINOR__ >= 1
#undef __USE_ISO_FORTRAN_ENV_INTREAL__
#define __USE_ISO_FORTRAN_ENV_INTREAL__ 1
#endif
#endif

#if defined __ibmxl__
#if __ibmxl_version__ >= 14 && __ibmxl_release__ >= 1
#undef __USE_ISO_FORTRAN_ENV_INTREAL__
#define __USE_ISO_FORTRAN_ENV_INTREAL__ 1
#endif
#endif

#if __FORTRAN_STANDARD__ < 2008
#undef __USE_ISO_FORTRAN_ENV_INTREAL__
#define __USE_ISO_FORTRAN_ENV_INTREAL__ 0
#endif
/*************************************************************************/
