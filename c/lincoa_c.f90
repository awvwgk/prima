module lincoa_c_mod
!--------------------------------------------------------------------------------------------------!
! lincoa_c_mod provides lincoa_c, a simplified interface to lincoa for interoperability with C
!
! Dedicated to the late Professor M. J. D. Powell FRS (1936--2015).
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: lincoa_c


contains


subroutine lincoa_c(cobj_ptr, data_ptr, n, x, f, cstrv, m_ineq, Aineq, bineq, m_eq, Aeq, beq, xl, xu, &
    & nf, rhobeg, rhoend, ftarget, maxfun, npt, iprint, callback_ptr, info) bind(C)
use, intrinsic :: iso_c_binding, only : C_DOUBLE, C_INT, C_FUNPTR, C_PTR, C_ASSOCIATED, C_F_PROCPOINTER, C_F_POINTER
use, non_intrinsic :: cintrf_mod, only : COBJ, CCALLBACK
use, non_intrinsic :: consts_mod, only : RP, IK
use, non_intrinsic :: infnan_mod, only : is_nan
use, non_intrinsic :: lincoa_mod, only : lincoa
use, non_intrinsic :: memory_mod, only : safealloc
implicit none

! Compulsory arguments
type(C_FUNPTR), intent(IN), value :: cobj_ptr
type(C_PTR), intent(in), value :: data_ptr
integer(C_INT), intent(in), value :: n
! We cannot use assumed-shape arrays for C interoperability
real(C_DOUBLE), intent(inout) :: x(n)
real(C_DOUBLE), intent(out) :: f
real(C_DOUBLE), intent(out) :: cstrv
integer(C_INT), intent(in), value :: m_ineq
real(C_DOUBLE), intent(in) :: Aineq(n, m_ineq)
real(C_DOUBLE), intent(in) :: bineq(m_ineq)
integer(C_INT), intent(in), value :: m_eq
real(C_DOUBLE), intent(in) :: Aeq(n, m_eq)
real(C_DOUBLE), intent(in) :: beq(m_eq)
type(C_PTR), intent(in), value :: xl
type(C_PTR), intent(in), value :: xu
integer(C_INT), intent(out) :: nf
real(C_DOUBLE), intent(in), value :: rhobeg
real(C_DOUBLE), intent(in), value :: rhoend
real(C_DOUBLE), intent(in), value :: ftarget
integer(C_INT), intent(in), value :: maxfun
integer(C_INT), intent(in), value :: npt
integer(C_INT), intent(in), value :: iprint
type(C_FUNPTR), intent(in), value :: callback_ptr
integer(C_INT), intent(out) :: info

! Local variables
integer(IK) :: info_loc
integer(IK) :: iprint_loc
integer(IK), allocatable :: maxfun_loc
integer(IK), allocatable :: npt_loc
integer(IK) :: nf_loc
real(RP) :: Aineq_loc(m_ineq, n)
real(RP) :: bineq_loc(m_ineq)
real(RP) :: Aeq_loc(m_eq, n)
real(RP) :: beq_loc(m_eq)
real(RP) :: cstrv_loc
real(RP) :: f_loc
real(RP), allocatable :: rhobeg_loc
real(RP), allocatable :: rhoend_loc
real(RP) :: ftarget_loc
real(RP) :: x_loc(n)
real(C_DOUBLE), pointer :: xl_loc_interm(:)
real(RP), allocatable :: xl_loc(:)
real(C_DOUBLE), pointer :: xu_loc_interm(:)
real(RP), allocatable :: xu_loc(:)
! The initialization to null is necessary to avoid a bug with the newer Intel compiler ifx.
! See details here: https://fortran-lang.discourse.group/t/strange-issue-with-ifx-compiler-and-assume-recursion/7013
! The bug was observed in all versions of ifx up to 2024.0.1. Once this bug is fixed we should remove the
! initialization to null because it implies the 'save' attribute, which is undesirable.
procedure(COBJ), pointer :: obj_ptr => null()
procedure(CCALLBACK), pointer :: cb_ptr => null()

! Read the inputs and convert them to the Fortran side types
! Note that `transpose` is needed when reading 2D arrays, since they are stored in the row-major
! order in c but column-major in Fortran.
x_loc = real(x, kind(x_loc))
Aineq_loc = real(transpose(Aineq), kind(Aineq_loc))
bineq_loc = real(bineq, kind(bineq_loc))
Aeq_loc = real(transpose(Aeq), kind(Aeq_loc))
beq_loc = real(beq, kind(beq_loc))
if (C_ASSOCIATED(xl)) then
    call C_F_POINTER(xl, xl_loc_interm, shape=[n])
    call safealloc(xl_loc, int(n, IK))
    xl_loc = real(xl_loc_interm, kind(xl_loc))
end if
if (C_ASSOCIATED(xu)) then
    call C_F_POINTER(xu, xu_loc_interm, shape=[n])
    call safealloc(xu_loc, int(n, IK))
    xu_loc = real(xu_loc_interm, kind(xu_loc))
end if
if (.not. is_nan(rhobeg)) then
    rhobeg_loc = real(rhobeg, kind(rhobeg_loc))
end if
if (.not. is_nan(rhoend)) then
    rhoend_loc = real(rhoend, kind(rhoend_loc))
end if
ftarget_loc = real(ftarget, kind(ftarget_loc))
if (maxfun /= 0) then
    maxfun_loc = int(maxfun, kind(maxfun_loc))
end if
if (npt /= 0) then
    npt_loc = int(npt, kind(npt_loc))
end if
iprint_loc = int(iprint, kind(iprint_loc))
call C_F_PROCPOINTER(cobj_ptr, obj_ptr)

! Call the Fortran code
if (C_ASSOCIATED(callback_ptr)) then
    ! If a C callback function is provided, we convert it to a Fortran procedure pointer and capture
    ! that pointer in the closure below.
    call C_F_PROCPOINTER(callback_ptr, cb_ptr)
    ! We then provide the closure to the algorithm.
    call lincoa(calfun, x_loc, f_loc, cstrv=cstrv_loc, Aineq=Aineq_loc, bineq=bineq_loc, Aeq=Aeq_loc, &
        & beq=beq_loc, xl=xl_loc, xu=xu_loc, nf=nf_loc, rhobeg=rhobeg_loc, rhoend=rhoend_loc, &
        & ftarget=ftarget_loc, maxfun=maxfun_loc, npt=npt_loc, iprint=iprint_loc, & 
        & callback_fcn=callback_fcn, info=info_loc)
else
    call lincoa(calfun, x_loc, f_loc, cstrv=cstrv_loc, Aineq=Aineq_loc, bineq=bineq_loc, Aeq=Aeq_loc, &
        & beq=beq_loc, xl=xl_loc, xu=xu_loc, nf=nf_loc, rhobeg=rhobeg_loc, rhoend=rhoend_loc, &
        & ftarget=ftarget_loc, maxfun=maxfun_loc, npt=npt_loc, iprint=iprint_loc, &
        & info=info_loc)
end if


! Write the outputs
x = real(x_loc, kind(x))
f = real(f_loc, kind(f))
cstrv = real(cstrv_loc, kind(cstrv))
nf = int(nf_loc, kind(nf))
info = int(info_loc, kind(info))

contains

!--------------------------------------------------------------------------------------------------!
! This subroutine defines `calfun` using the C function pointer with an internal subroutine.
! This allows to avoid passing the C function pointer by a module variable, which is thread-unsafe.
! A possible security downside is that the compiler must allow for an executable stack.
! This subroutine is identical across 4 out of 5 algorithms; COBYLA requires a slightly different
! signature.
!--------------------------------------------------------------------------------------------------!
subroutine calfun(x_sub, f_sub)
use, intrinsic :: iso_c_binding, only : C_DOUBLE
use, non_intrinsic :: consts_mod, only : RP
implicit none
real(RP), intent(in) :: x_sub(:) ! We name some variables _sub to avoid masking the parent variables
real(RP), intent(out) :: f_sub

! Local variables
real(C_DOUBLE) :: x_sub_loc(size(x_sub))
real(C_DOUBLE) :: f_sub_loc

! Read the inputs and convert them to the types specified in COBJ
x_sub_loc = real(x_sub, kind(x_sub_loc))

! Call the C objective function
call obj_ptr(x_sub_loc, f_sub_loc, data_ptr)

! Write the output
f_sub = real(f_sub_loc, kind(f_sub))

end subroutine calfun


!--------------------------------------------------------------------------------------------------!
! This subroutine defines `callback_fcn` using the C function pointer with an internal subroutine.
! This allows to avoid passing the C function pointer by a module variable, which is thread-unsafe.
! A possible security downside is that the compiler must allow for an executable stack.
! This subroutine is identical across all 5 algorithms.
!--------------------------------------------------------------------------------------------------!
subroutine callback_fcn(x_sub, f_sub, nf_sub, tr, cstrv_sub, nlconstr_sub, terminate)
use, intrinsic :: iso_c_binding, only : C_DOUBLE, C_INT, C_BOOL
use, non_intrinsic :: consts_mod, only : RP, IK
use, non_intrinsic :: memory_mod, only : safealloc
implicit none
real(RP), intent(in) :: x_sub(:) ! We name some variables _sub to avoid masking the parent variables
real(RP), intent(in) :: f_sub
integer(IK), intent(in) :: nf_sub
integer(IK), intent(in) :: tr
real(RP), intent(in), optional :: cstrv_sub
real(RP), intent(in), optional :: nlconstr_sub(:)
logical, intent(out), optional :: terminate

! Local variables
integer(C_INT) :: n_sub_loc
real(C_DOUBLE) :: x_sub_loc(size(x_sub))
real(C_DOUBLE) :: f_sub_loc
integer(C_INT) :: nf_sub_loc
integer(C_INT) :: tr_loc
real(C_DOUBLE) :: cstrv_sub_loc
integer(C_INT) :: m_nlconstr
real(C_DOUBLE), allocatable :: nlconstr_sub_loc(:)
logical(C_BOOL) :: terminate_loc

! Read the inputs and convert them to the types specified in CCALLBACK
n_sub_loc = size(x_sub)
x_sub_loc = real(x_sub, kind(x_sub_loc))
f_sub_loc = real(f_sub, kind(f_sub_loc))
nf_sub_loc = int(nf_sub, kind(nf_sub_loc))
tr_loc = int(tr, kind(tr_loc))

! Set the constraint violation to a sensible default value if it is not provided.
if (present(cstrv_sub)) then
    cstrv_sub_loc = real(cstrv_sub, kind(cstrv_sub_loc))
else
    cstrv_sub_loc = 0.0_C_DOUBLE
end if

! Set the nonlinear constraints to a sensible default value if it is not provided.
if (present(nlconstr_sub)) then
    m_nlconstr = int(size(nlconstr_sub), C_INT)
    call safealloc(nlconstr_sub_loc, int(m_nlconstr, IK))
    nlconstr_sub_loc = real(nlconstr_sub, kind(nlconstr_sub_loc))
else
    m_nlconstr = 0_C_INT
    nlconstr_sub_loc = [real(C_DOUBLE) ::]
end if

! Call the C callback function
call cb_ptr(n_sub_loc, x_sub_loc, f_sub_loc, nf_sub_loc, tr_loc, cstrv_sub_loc, m_nlconstr, nlconstr_sub_loc, terminate_loc)

! Write the output
if ( present(terminate) ) then
    terminate = logical(terminate_loc, kind(terminate))
end if

! Deallocate resources
if (allocated(nlconstr_sub_loc)) deallocate(nlconstr_sub_loc)

end subroutine callback_fcn

end subroutine lincoa_c


end module lincoa_c_mod
