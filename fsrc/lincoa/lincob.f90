!TODO:
! 1. Check whether it is possible to change the definition of RESCON, RESNEW, RESTMP, RESACT so that
! we do not need to encode information into their signs.
! 2. Use RESCON to evaluate CSTRV.
! 3. In FMSG, do not print CONSTR, which will not be computed due to 2.
!
module lincob_mod
!--------------------------------------------------------------------------------------------------!
! This module performs the major calculations of LINCOA.
!
! Coded by Zaikun ZHANG (www.zhangzk.net) based on Powell's code and the paper
!
! M. J. D. Powell, On fast trust region methods for quadratic models with linear constraints,
! Math. Program. Comput., 7:237--267, 2015
!
! Dedicated to late Professor M. J. D. Powell FRS (1936--2015).
!
! Started: February 2022
!
! Last Modified: Sunday, November 13, 2022 PM05:49:24
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: lincob


contains


subroutine lincob(calfun, iprint, maxfilt, maxfun, npt, A_orig, amat, b_orig, bvec, ctol, cweight, &
    & eta1, eta2, ftarget, gamma1, gamma2, rhobeg, rhoend, x, nf, chist, cstrv, f, fhist, xhist, info)
!--------------------------------------------------------------------------------------------------!
! This subroutine performs the actual calculations of LINCOA.
!
! The arguments IPRINT, MAXFILT, MAXFUN, MAXHIST, NPT, CTOL, CWEIGHT, ETA1, ETA2, FTARGET, GAMMA1,
! GAMMA2, RHOBEG, RHOEND, X, NF, F, XHIST, FHIST, CHIST, CSTRV and INFO are identical to the
! corresponding arguments in subroutine LINCOA.
! AMAT is a matrix whose columns are the constraint gradients, scaled so that they have unit length.
! B contains on entry the right hand sides of the constraints, scaled as above, but later B is
! modified for variables relative to XBASE.
! XBASE holds a shift of origin that should reduce the contributions from rounding errors to values
! of the model and Lagrange functions.
! XPT contains the interpolation point coordinates relative to XBASE.
! FVAL holds the values of F at the interpolation points.
! XSAV holds the best feasible vector of variables so far, without any shift of origin.
! XOPT is set to XSAV-XBASE, which is the displacement from XBASE of the feasible vector of variables
! that provides the least calculated F so far, this vector being the current trust region centre.
! GOPT holds the gradient of the quadratic model at XSAV = XBASE+XOPT.
! HQ holds the explicit second derivatives of the quadratic model.
! PQ contains the parameters of the implicit second derivatives of the quadratic model.
! BMAT holds the last N columns of the big inverse matrix H.
! ZMAT holds the factorization of the leading NPT by NPT submatrix of H, this factorization being
! ZMAT * Diag(DZ) * ZMAT^T, where the elements of DZ are plus or minus ONE, as specified by IDZ.
! D is employed for trial steps from XOPT.
! XNEW is the displacement from XBASE of the vector of variables for the current calculation of F,
! except that SUBROUTINE TRSTEP uses it for working space.
! IACT is an integer array for the indices of the active constraints.
! RESCON holds useful information about the constraint residuals. Every nonnegative RESCON(J) is the
! residual of the J-th constraint at the current trust region centre. Otherwise, if RESCON(J) is
! negative, the J-th constraint holds as a strict inequality at the trust region centre, its
! residual being at least |RESCON(J)|; further, the value of |RESCON(J)| is at least the current
! trust region radius DELTA.
! QFAC is the orthogonal part of the QR factorization of the matrix of active constraint gradients,
! these gradients being ordered in accordance with IACT. When NACT is less than N, columns are added
! to QFAC to complete an N by N orthogonal matrix, which is important for keeping calculated steps
! sufficiently close to the boundaries of the active constraints.
! RFAC is the upper triangular part of this QR factorization, beginning with the first diagonal
! element, followed by the two elements in the upper triangular part of the second column and so on.
!--------------------------------------------------------------------------------------------------!

! Generic models
use, non_intrinsic :: consts_mod, only : RP, IK, ZERO, ONE, TWO, HALF, TENTH, HUGENUM, MIN_MAXFILT, DEBUGGING
use, non_intrinsic :: debug_mod, only : assert
use, non_intrinsic :: evaluate_mod, only : evaluate
use, non_intrinsic :: history_mod, only : savehist, rangehist
use, non_intrinsic :: infnan_mod, only : is_nan, is_posinf
use, non_intrinsic :: infos_mod, only : NAN_INF_X, NAN_INF_F, FTARGET_ACHIEVED, INFO_DFT, &
    & MAXFUN_REACHED, SMALL_TR_RADIUS!, MAXTR_REACHED
use, non_intrinsic :: linalg_mod, only : matprod, maximum, eye, trueloc
use, non_intrinsic :: output_mod, only : fmsg
use, non_intrinsic :: pintrf_mod, only : OBJ
use, non_intrinsic :: powalg_mod, only : quadinc, omega_mul, hess_mul
use, non_intrinsic :: ratio_mod, only : redrat

! Solver-specific modules
use, non_intrinsic :: geometry_mod, only : geostep, setdrop_tr
use, non_intrinsic :: initialize_mod, only : initxf, inith
use, non_intrinsic :: shiftbase_mod, only : shiftbase
use, non_intrinsic :: trustregion_mod, only : trstep
use, non_intrinsic :: update_mod, only : updateq, updatexf
use, non_intrinsic :: powalg_mod, only : updateh

implicit none

! Inputs
procedure(OBJ) :: calfun  ! N.B.: INTENT cannot be specified if a dummy procedure is not a POINTER
integer(IK), intent(in) :: iprint
integer(IK), intent(in) :: maxfilt
integer(IK), intent(in) :: maxfun
integer(IK), intent(in) :: npt
real(RP), intent(in) :: A_orig(:, :)  ! A_ORIG(N, M) ; Better names? necessary?
real(RP), intent(in) :: amat(:, :)  ! AMAT(N, M) ; Better names? necessary?
real(RP), intent(in) :: b_orig(:) ! B_ORIG(M) ; Better names? necessary?
real(RP), intent(in) :: bvec(:)  ! BVEC(M) ; Better names? necessary?
real(RP), intent(in) :: ctol
real(RP), intent(in) :: cweight
real(RP), intent(in) :: eta1
real(RP), intent(in) :: eta2
real(RP), intent(in) :: ftarget
real(RP), intent(in) :: gamma1
real(RP), intent(in) :: gamma2
real(RP), intent(in) :: rhobeg
real(RP), intent(in) :: rhoend

! In-outputs
real(RP), intent(inout) :: x(:)  ! X(N)

! Outputs
integer(IK), intent(out) :: info
integer(IK), intent(out) :: nf
real(RP), intent(out) :: chist(:)  ! CHIST(MAXCHIST)
real(RP), intent(out) :: cstrv
real(RP), intent(out) :: f
real(RP), intent(out) :: fhist(:)  ! FHIST(MAXFHIST)
real(RP), intent(out) :: xhist(:, :)  ! XHIST(N, MAXXHIST)

! Local variables
character(len=*), parameter :: solver = 'LINCOA'
character(len=*), parameter :: srname = 'LINCOB'
integer(IK) :: iact(size(bvec))
integer(IK) :: m
integer(IK) :: maxchist
integer(IK) :: maxfhist
integer(IK) :: maxhist
integer(IK) :: maxxhist
integer(IK) :: n
real(RP) :: b(size(bvec))
real(RP) :: bmat(size(x), npt + size(x))
real(RP) :: fval(npt)
real(RP) :: gopt(size(x))
real(RP) :: hq(size(x), size(x))
real(RP) :: pq(npt)
real(RP) :: qfac(size(x), size(x))
real(RP) :: rescon(size(bvec))
real(RP) :: rfac(size(x), size(x))
real(RP) :: d(size(x))
real(RP) :: xbase(size(x))
real(RP) :: xnew(size(x))
real(RP) :: xopt(size(x))
real(RP) :: xpt(size(x), npt)
real(RP) :: zmat(npt, npt - size(x) - 1)
real(RP) :: delbar, delta, dffalt, diff, &
&        distsq(npt), fopt, ratio,     &
&        rho, dnorm, temp, &
&        qred, constr(size(bvec))
logical :: accurate_mod, adequate_geo
logical :: bad_trstep
logical :: close_itpset
logical :: small_trrad
!logical :: good_mod
logical :: feasible, shortd, improve_geo, reduce_rho, freduced
integer(IK) :: ij(2, max(0_IK, int(npt - 2 * size(x) - 1, IK)))
integer(IK) :: idz, itest, &
&           knew_tr, knew_geo, kopt, nact,      &
&           ngetact, subinfo
real(RP) :: fshift(npt)
real(RP) :: pqalt(npt), galt(size(x))
real(RP) :: dnormsav(5)

! Sizes.
m = int(size(bvec), kind(m))
n = int(size(x), kind(n))
maxxhist = int(size(xhist, 2), kind(maxxhist))
maxfhist = int(size(fhist), kind(maxfhist))
maxchist = int(size(chist), kind(maxchist))
maxhist = int(max(maxxhist, maxfhist, maxchist), kind(maxhist))

! Preconditions
if (DEBUGGING) then
    call assert(abs(iprint) <= 3, 'IPRINT is 0, 1, -1, 2, -2, 3, or -3', srname)
    call assert(m >= 0, 'M >= 0', srname)
    call assert(n >= 1, 'N >= 1', srname)
    call assert(npt >= n + 2, 'NPT >= N+2', srname)
    call assert(maxfun >= npt + 1, 'MAXFUN >= NPT+1', srname)
    call assert(size(A_orig, 1) == n .and. size(A_orig, 2) == m, 'SIZE(A_ORIG) == [N, M]', srname)
    call assert(size(b_orig) == m, 'SIZE(B_ORIG) == M', srname)
    call assert(size(amat, 1) == n .and. size(amat, 2) == m, 'SIZE(AMAT) == [N, M]', srname)
    call assert(rhobeg >= rhoend .and. rhoend > 0, 'RHOBEG >= RHOEND > 0', srname)
    call assert(eta1 >= 0 .and. eta1 <= eta2 .and. eta2 < 1, '0 <= ETA1 <= ETA2 < 1', srname)
    call assert(gamma1 > 0 .and. gamma1 < 1 .and. gamma2 > 1, '0 < GAMMA1 < 1 < GAMMA2', srname)
    call assert(maxfilt >= min(MIN_MAXFILT, maxfun) .and. maxfilt <= maxfun, &
        & 'MIN(MIN_MAXFILT, MAXFUN) <= MAXFILT <= MAXFUN', srname)
    call assert(maxhist >= 0 .and. maxhist <= maxfun, '0 <= MAXHIST <= MAXFUN', srname)
    call assert(size(xhist, 1) == n .and. maxxhist * (maxxhist - maxhist) == 0, &
        & 'SIZE(XHIST, 1) == N, SIZE(XHIST, 2) == 0 or MAXHIST', srname)
    call assert(maxfhist * (maxfhist - maxhist) == 0, 'SIZE(FHIST) == 0 or MAXHIST', srname)
    call assert(maxchist * (maxchist - maxhist) == 0, 'SIZE(CHIST) == 0 or MAXHIST', srname)
end if

!---------------------------------------------------------!
if (cweight < 0) then
    write (*, *) cweight  ! Temporary, to be removed.
end if
!---------------------------------------------------------!

!====================!
! Calculation starts !
!====================!

! Set the elements of XBASE, XPT, FVAL, XSAV, XOPT, GOPT, HQ, PQ, BMAT, and ZMAT or the first
! iteration. An important feature is that, if the interpolation point XPT(K, :) is not feasible,
! where K is any integer from [1,NPT], then a change is made to XPT(K, :) if necessary so that the
! constraint violation is at least 0.2*RHOBEG. Also KOPT is set so that XPT(KOPT, :) is the initial
! trust region centre.
b = bvec
call initxf(calfun, iprint, maxfun, A_orig, amat, b_orig, ctol, ftarget, rhobeg, x, b, &
    & ij, kopt, nf, chist, fhist, fval, xbase, xhist, xpt, subinfo)
xopt = xpt(:, kopt)
fopt = fval(kopt)
x = xbase + xopt
f = fopt
! For the output, we use A_ORIG and B_ORIG to evaluate the constraints.
cstrv = maximum([ZERO, matprod(x, A_orig) - b_orig])

if (subinfo /= INFO_DFT) then
    info = subinfo
    call rangehist(nf, xhist, fhist, chist)
    !close (16)
    return
end if

! Initialize BMAT, ZMAT, and IDZ.
call inith(ij, rhobeg, xpt, idz, bmat, zmat)

! Initialize the quadratic model.
hq = ZERO
pq = omega_mul(idz, zmat, fval)
gopt = matprod(bmat(:, 1:npt), fval) + hess_mul(xopt, xpt, pq)

! Initialize RESCON.
! RESCON holds information about the constraint residuals at the current trust region center XOPT.
! 1. RESCON(J) = B(J) - AMAT(:, J)^T*XOPT if and only if B(J) - AMAT(:, J)^T*XOPT <= DELTA. Note
! that RESCON >= 0 in this case, because the algorithm keeps XOPT to be feasible.
! 2. Otherwise, RESCON(J) is a negative value that B(J) - AMAT(:, J)^T*XOPT >= |RESCON(J)| >= DELTA.
! RESCON can be updated without calculating the constraints that are far from being active, so that
! we only need to evaluate the constraints that are nearly active. RESCON is initialized as follows.
! 1. Normally, RESCON = B - AMAT^T*XOPT (theoretically, B - AMAT^T*XOPT >= 0 since XOPT is feasible)
! 2. If RESCON(J) >= RHOBEG (current trust-region radius), its sign is flipped.
rescon = max(b - matprod(xopt, amat), ZERO)  ! Calculation changed
rescon(trueloc(rescon >= rhobeg)) = -rescon(trueloc(rescon >= rhobeg))
!!MATLAB: rescon(rescon >= rhobeg) = -rescon(rescon >= rhobeg)

qfac = eye(n)
rfac = ZERO
rho = rhobeg
delta = rho
qred = ZERO
ratio = -ONE
knew_tr = 0
knew_geo = 0
feasible = .false.
shortd = .false.
improve_geo = .false.
nact = 0
itest = 3
dnormsav = HUGENUM
info = INFO_DFT

! Begin the iterative procedure.
! After solving a trust-region subproblem, we use three boolean variables to control the workflow.
! SHORTD: Is the trust-region trial step too short to invoke a function evaluation?
! IMPROVE_GEO: Should we improve the geometry?
! REDUCE_RHO: Should we reduce rho?
! LINCOA never sets IMPROVE_GEO and REDUCE_RHO to TRUE simultaneously.
do while (.true.)
    ! Shift XBASE if XOPT may be too far from XBASE.
    ! Zaikun 20220528: The criteria is different from those in NEWUOA or BOBYQA, particularly here
    ! |XOPT| is compared with DELTA instead of DNORM. What about unifying the criteria, preferably
    ! to the one here? What about comparing with RHO? What about calling SHIFTBASE only before
    ! TRSTEP but not GEOSTEP (consider GEOSTEP as a postprocessor).
    if (sum(xopt**2) >= 1.0E4_RP * delta**2) then
        b = b - matprod(xopt, amat)
        call shiftbase(xbase, xopt, xpt, zmat, bmat, pq, hq, idz)
    end if

    ! Generate the next trust region step D by calling TRSTEP. Note that D is feasible.
    call trstep(amat, delta, gopt, hq, pq, rescon, xpt, iact, nact, qfac, rfac, ngetact, d)
    dnorm = min(delta, sqrt(sum(d**2)))

    ! A trust region step is applied whenever its length is at least 0.5*DELTA. It is also
    ! applied if its length is at least 0.1999*DELTA and if a line search of TRSTEP has caused a
    ! change to the active set, indicated by NGETACT >= 2 (note that NGETACT is at least 1).
    ! Otherwise, the trust region step is considered too short to try.
    shortd = ((dnorm < HALF * delta .and. ngetact < 2) .or. dnorm < 0.1999_RP * delta)
    !------------------------------------------------------------------------------------------!
    ! The SHORTD defined above needs NGETACT, which relies on Powell's trust region subproblem
    ! solver. If a different subproblem solver is used, we can take the following SHORTD adopted
    ! from UOBYQA, NEWUOA and BOBYQA.
    ! !SHORTD = (DNORM < HALF * RHO)
    !------------------------------------------------------------------------------------------!

    ! DNORMSAV saves the DNORM of last few (five) trust-region iterations. It will be used to
    ! decide whether we should improve the geometry of the interpolation set or reduce RHO when
    ! SHORTD is TRUE. Note that it does not record the geometry steps.
    dnormsav = [dnormsav(2:size(dnormsav)), dnorm]

    ! In some cases, we reset DNORMSAV to HUGENUM. This indicates a preference of improving the
    ! geometry of the interpolation set to reducing RHO in the subsequent three or more
    ! iterations. This is important for the performance of LINCOA.
    if (delta > rho .or. .not. shortd) then  ! Another possibility: IF (DELTA > RHO) THEN
        dnormsav = HUGENUM
    end if

    ! Set QRED to the reduction of the quadratic model when the move D is made from XOPT. QRED
    ! should be positive If it is nonpositive due to rounding errors, we will not take this step.
    qred = -quadinc(d, xpt, gopt, pq, hq) ! QRED = Q(XOPT) - Q(XOPT + D)

    if (shortd .or. .not. qred > 0) then
        ! In this case, do nothing but reducing DELTA. Afterward, DELTA < DNORM may occur.
        ! N.B.: 1. This value of DELTA will be discarded if REDUCE_RHO turns out TRUE later.
        ! 2. Powell's code does not shrink DELTA when QRED > 0 is FALSE (i.e., when VQUAD >= 0 in
        ! Powell's code, where VQUAD = -QRED). Consequently, the algorithm may  be stuck in an
        ! infinite cycling, because both REDUCE_RHO and IMPROVE_GEO may end up with FALSE in this
        ! case, which did happen in tests.
        ! 3. The factor HALF works better than TENTH used in NEWUOA/BOBYQA.
        ! 4. The factor 1.4 below aligns with the update of DELTA after a trust-region step.
        delta = HALF * delta
        if (delta <= 1.4_RP * rho) then
            delta = rho
        end if
    else
        ! Calculate the next value of the objective function. The difference between the actual new
        ! value of F and the value predicted by the model is recorded in DIFF.
        if (nf >= maxfun) then
            info = MAXFUN_REACHED
            exit
        end if
        xnew = xopt + d
        x = xbase + xnew

        if (is_nan(sum(abs(x)))) then
            f = sum(x)  ! Set F to NaN
            if (nf == 1) then
                fopt = f
                xopt = ZERO
            end if
            info = NAN_INF_X
            exit
        end if
        call evaluate(calfun, x, f)
        ! For the output, we use A_ORIG and B_ORIG to evaluate the constraints (so RESCON is
        ! not usable).
        constr = matprod(x, A_orig) - b_orig
        cstrv = maximum([ZERO, constr])

        nf = nf + 1_IK
        call fmsg(solver, iprint, nf, f, x, cstrv, constr)
        call savehist(nf, x, xhist, f, fhist, cstrv, chist)
        if (is_nan(f) .or. is_posinf(f)) then
            info = NAN_INF_F
            exit
        end if
        diff = f - fopt + qred

        ! Set DFFALT to the difference between the new value of F and the value predicted by
        ! the alternative model.
        if (itest < 3) then
            fshift = fval - fval(kopt)
            ! Zaikun 20220418: Can we reuse PQALT and GALT in TRYQALT?
            pqalt = omega_mul(idz, zmat, fshift)
            galt = matprod(bmat(:, 1:npt), fshift) + hess_mul(xopt, xpt, pqalt)
            dffalt = f - fopt - quadinc(d, xpt, galt, pqalt)
        else
            dffalt = diff
            itest = 0
        end if

        ! Pick the next value of DELTA after a trust region step.
        !ratio = (fopt - f) / qred
        ratio = redrat(fopt - f, qred, eta1)  ! Needed? Or just take the ratio since QRED > 0?
        if (ratio <= TENTH) then
            delta = HALF * delta
        else if (ratio <= 0.7_RP) then
            delta = max(HALF * delta, dnorm)
        else
            temp = sqrt(TWO) * delta
            delta = max(HALF * delta, dnorm + dnorm)
            delta = min(delta, temp)  ! This does not exist in NEWUOA/BOBYQA. It works well.
        end if
        if (delta <= 1.4_RP * rho) then
            delta = rho
        end if
        !if (delta <= 1.5_RP * rho) delta = rho  ! This is wrong!
        ! N.B.: The factor in the line above should be smaller than SQRT(2). Imagine a very
        ! successful step with DENORM = the un-updated DELTA = RHO. Then the scheme will
        ! first update DELTA to SQRT(2)*RHO. If this factor were not smaller than SQRT(2),
        ! then DELTA will be reset to RHO, which is not reasonable as D is very successful.

        freduced = (f < fopt)

        ! Update BMAT, ZMAT and IDZ, so that the KNEW-th interpolation point can be moved. If
        ! D is a trust region step, then KNEW is ZERO at present, but a positive value is picked
        ! by subroutine UPDATE.
        ! TODO: 1. Take FREDUCED into consideration in SETDROP_TR, particularly DISTSQ.
        ! 2. Test different definitions of WEIGHT in SETDROP_TR. See BOBYQA.
        knew_tr = setdrop_tr(idz, kopt, freduced, bmat, d, xpt, zmat)
        if (knew_tr > 0) then
            call updateh(knew_tr, kopt, idz, d, xpt, bmat, zmat)

            ! If ITEST is increased to 3, then the next quadratic model is the one whose second
            ! derivative matrix is least subject to the new interpolation conditions. Otherwise the
            ! new model is constructed by the symmetric Broyden method in the usual way.
            if (abs(dffalt) >= TENTH * abs(diff)) then
                itest = 0
            else
                itest = itest + 1
            end if

            ! Update the second derivatives of the model by the symmetric Broyden method, using PQW
            ! for the second derivative parameters of the new KNEW-th Lagrange function. The
            ! contribution from the old parameter PQ(KNEW) is included in the second derivative
            ! matrix HQ.
            call updateq(idz, knew_tr, kopt, freduced, bmat, d, f, fval, xnew, xpt, zmat, gopt, hq, pq)
            call updatexf(knew_tr, freduced, d, f, kopt, fval, xpt, fopt, xopt)
            if (fopt <= ftarget) then
                info = FTARGET_ACHIEVED
                exit
            end if

            ! Update RESCON.
            ! 1. RESCON(J) = B(J) - AMAT(:, J)^T*XOPT if and only if B(J) - AMAT(:, J)^T*XOPT <= DELTA.
            ! 2. Otherwise, RESCON(J) is a negative value that B(J) - AMAT(:, J)^T*XOPT >= |RESCON(J)| >= DELTA.
            if (freduced) then
                dnorm = sqrt(sum(d**2))
                where (abs(rescon) >= dnorm + delta)
                    rescon = min(-abs(rescon) + dnorm, -delta)
                elsewhere
                    rescon = max(b - matprod(xopt, amat), ZERO)  ! Calculation changed
                end where
                rescon(trueloc(rescon >= delta)) = -rescon(trueloc(rescon >= delta))
                !!MATLAB:
                !!mask = (rescon >= delta+dnorm);
                !!rescon(mask) = max(rescon(mask) - dnorm, delta);
                !!rescon(~mask) = max(b(~mask) - (xopt'*amat(:, ~mask))', 0);
                !!rescon(rescon >= rhobeg) = -rescon(rescon >= rhobeg)
            end if

            ! Replace the current model by the least Frobenius norm interpolant if this interpolant
            ! gives substantial reductions in the predictions of values of F at feasible points.
            if (itest == 3) then
                fshift = fval - fval(kopt)
                pq = omega_mul(idz, zmat, fshift)
                hq = ZERO
                gopt = matprod(bmat(:, 1:npt), fshift) + hess_mul(xopt, xpt, pq)
            end if
        end if
    end if


    !----------------------------------------------------------------------------------------------!
    ! Before the next trust-region iteration, we may improve the geometry of XPT or reduce RHO
    ! according to IMPROVE_GEO and REDUCE_RHO, which in turn depend on the following indicators.
    ! ACCURATE_MOD: Are the recent models sufficiently accurate? Used only if SHORTD is TRUE.
    accurate_mod = all(dnormsav <= HALF * rho) .or. all(dnormsav(3:size(dnormsav)) <= TENTH * rho)
    ! CLOSE_ITPSET: Are the interpolation points close to XOPT?
    distsq = sum((xpt - spread(xopt, dim=2, ncopies=npt))**2, dim=1)
    !!MATLAB: distsq = sum((xpt - xopt).^2)  % xopt should be a column! Implicit expansion
    close_itpset = all(distsq <= 4.0_RP * delta**2)  ! Behaves the same as Powell's version.
    ! Below are some alternative definitions of CLOSE_ITPSET.
    ! !close_itpset = all(distsq <= 4.0_RP * rho**2)  ! Behaves the same as Powell's version.
    ! !close_itpset = all(distsq <= max(delta**2, 4.0_RP * rho**2))  ! Powell's code.
    ! !close_itpset = all(distsq <= rho**2)  ! Does not work as well as Powell's version.
    ! !close_itpset = all(distsq <= 10.0_RP * rho**2)  ! Does not work as well as Powell's version.
    ! !close_itpset = all(distsq <= delta**2)  ! Does not work as well as Powell's version.
    ! !close_itpset = all(distsq <= 10.0_RP * delta**2)  ! Does not work as well as Powell's version.
    ! !close_itpset = all(distsq <= max((2.0_RP * delta)**2, (10.0_RP * rho)**2))  ! Powell's BOBYQA.
    ! ADEQUATE_GEO: Is the geometry of the interpolation set "adequate"?
    adequate_geo = (shortd .and. accurate_mod) .or. close_itpset
    ! SMALL_TRRAD: Is the trust-region radius small?  This indicator seems not impactive.
    small_trrad = (max(delta, dnorm) <= rho)  ! Behaves the same as Powell's version.
    !small_trrad = (delsav <= rho)  ! Powell's code. DELSAV = unupdated DELTA.

    ! IMPROVE_GEO and REDUCE_RHO are defined as follows.
    ! BAD_TRSTEP (for IMPROVE_GEO): Is the last trust-region step bad?
    bad_trstep = (shortd .or. (.not. qred > 0) .or. ratio <= TENTH .or. knew_tr == 0)
    improve_geo = bad_trstep .and. .not. adequate_geo
    ! BAD_TRSTEP (for REDUCE_RHO): Is the last trust-region step bad?
    bad_trstep = (shortd .or. (.not. qred > 0) .or. ratio <= 0 .or. knew_tr == 0)
    reduce_rho = bad_trstep .and. adequate_geo .and. small_trrad

    ! Equivalently, REDUCE_RHO can be set as follows. It shows that REDUCE_RHO is TRUE in two cases.
    ! !bad_trstep = (shortd .or. (.not. qred > 0) .or. ratio <= 0 .or. knew_tr == 0)
    ! !reduce_rho = (shortd .and. accurate_mod) .or. (bad_trstep .and. close_itpset .and. small_trrad)

    ! With REDUCE_RHO properly defined, we can also set IMPROVE_GEO as follows.
    ! !bad_trstep = (shortd .or. (.not. qred > 0) .or. ratio <= TENTH .or. knew_tr == 0)
    ! !improve_geo = bad_trstep .and. (.not. reduce_rho) .and. (.not. close_itpset)

    ! With IMPROVE_GEO properly defined, we can also set REDUCE_RHO as follows.
    ! !bad_trstep = (shortd .or. (.not. qred > 0) .or. ratio <= 0 .or. knew_tr == 0)
    ! !reduce_rho = bad_trstep .and. (.not. improve_geo) .and. small_trrad

    ! LINCOA never sets IMPROVE_GEO and REDUCE_RHO to TRUE simultaneously.
    !call assert(.not. (improve_geo .and. reduce_rho), 'IMPROVE_GEO or REDUCE_RHO is false', srname)
    !
    ! If SHORTD is TRUE or QRED > 0 is FALSE, then either REDUCE_RHO or IMPROVE_GEO is TRUE unless
    ! CLOSE_ITPSET is TRUE but SMALL_TRRAD is FALSE.
    !call assert((.not. shortd .and. qred > 0) .or. (improve_geo .or. reduce_rho .or. &
    !    & (close_itpset .and. .not. small_trrad)), 'If SHORTD is TRUE or QRED > 0 is FALSE, then either&
    !    & IMPROVE_GEO or REDUCE_RHO is TRUE unless CLOSE_ITPSET is TRUE but SMALL_TRRAD is FALSE', srname)
    !----------------------------------------------------------------------------------------------!


    ! Since IMPROVE_GEO and REDUCE_RHO are never TRUE simultaneously, the following two blocks are
    ! exchangeable: IF (IMPROVE_GEO) ... END IF and IF (REDUCE_RHO) ... END IF.

    if (improve_geo) then
        ! Shift XBASE if XOPT may be too far from XBASE.
        ! Zaikun 20220528: The criteria is different from those in NEWUOA or BOBYQA, particularly here
        ! |XOPT| is compared with DELTA instead of DNORM. What about unifying the criteria, preferably
        ! to the one here? What about comparing with RHO? What about calling SHIFTBASE only before
        ! TRSTEP but not GEOSTEP (consider GEOSTEP as a postprocessor).
        if (sum(xopt**2) >= 1.0E4_RP * delta**2) then
            b = b - matprod(xopt, amat)
            call shiftbase(xbase, xopt, xpt, zmat, bmat, pq, hq, idz)
        end if

        knew_geo = int(maxloc(distsq, dim=1), kind(knew_geo))

        ! Alternatively, KNEW > 0, and the model step is calculated within a trust region of radius DELBAR.
        delbar = max(TENTH * delta, rho)  ! This differs from NEWUOA/BOBYQA. Possible improvement?
        call geostep(iact, idz, knew_geo, kopt, nact, amat, bmat, delbar, qfac, rescon, xpt, zmat, feasible, d)

        ! Set QRED to the reduction of the quadratic model when the move D is made from XOPT.
        qred = -quadinc(d, xpt, gopt, pq, hq)

        ! Calculate the next value of the objective function. The difference between the actual new
        ! value of F and the value predicted by the model is recorded in DIFF.
        if (nf >= maxfun) then
            info = MAXFUN_REACHED
            exit
        end if
        xnew = xopt + d
        x = xbase + xnew

        if (is_nan(sum(abs(x)))) then
            f = sum(x)  ! Set F to NaN
            if (nf == 1) then
                fopt = f
                xopt = ZERO
            end if
            info = NAN_INF_X
            exit
        end if
        call evaluate(calfun, x, f)
        ! For the output, we use A_ORIG and B_ORIG to evaluate the constraints (so RESCON is not usable).
        constr = matprod(x, A_orig) - b_orig
        cstrv = maximum([ZERO, constr])
        nf = nf + 1_IK

        call fmsg(solver, iprint, nf, f, x, cstrv, constr)
        call savehist(nf, x, xhist, f, fhist, cstrv, chist)
        if (is_nan(f) .or. is_posinf(f)) then
            info = NAN_INF_F
            exit
        end if
        diff = f - fopt + qred

        ! If X is feasible, then set DFFALT to the difference between the new value of F and the
        ! value predicted by the alternative model. This must be done before IDZ, ZMAT, XOPT, and
        ! XPT are updated.
        if (feasible .and. itest < 3) then
            !if (itest < 3) then
            fshift = fval - fval(kopt)
            ! Zaikun 20220418: Can we reuse PQALT and GALT in TRYQALT?
            pqalt = omega_mul(idz, zmat, fshift)
            galt = matprod(bmat(:, 1:npt), fshift) + hess_mul(xopt, xpt, pqalt)
            dffalt = f - fopt - quadinc(d, xpt, galt, pqalt)
        end if
        if (itest == 3) then
            dffalt = diff
            itest = 0
        end if

        ! If ITEST is increased to 3, then the next quadratic model is the one whose second
        ! derivative matrix is least subject to the new interpolation conditions. Otherwise the
        ! new model is constructed by the symmetric Broyden method in the usual way.
        if (feasible) then
            !if (.true.) then
            if (abs(dffalt) >= TENTH * abs(diff)) then
                itest = 0
            else
                itest = itest + 1
            end if
        end if

        ! Update BMAT, ZMAT and IDZ, so that the KNEW-th interpolation point can be moved. If
        ! D is a trust region step, then KNEW is ZERO at present, but a positive value is picked
        ! by subroutine UPDATE.
        call updateh(knew_geo, kopt, idz, d, xpt, bmat, zmat)

        ! Update the second derivatives of the model by the symmetric Broyden method, using PQW for
        ! the second derivative parameters of the new KNEW-th Lagrange function. The contribution
        ! from the old parameter PQ(KNEW) is included in the second derivative matrix HQ.
        freduced = (f < fopt .and. feasible)
        call updateq(idz, knew_geo, kopt, freduced, bmat, d, f, fval, xnew, xpt, zmat, gopt, hq, pq)
        call updatexf(knew_geo, freduced, d, f, kopt, fval, xpt, fopt, xopt)
        if (fopt <= ftarget) then
            info = FTARGET_ACHIEVED
            exit
        end if

        ! Update RESCON.
        ! 1. RESCON(J) = B(J) - AMAT(:, J)^T*XOPT if and only if B(J) - AMAT(:, J)^T*XOPT <= DELTA.
        ! 2. Otherwise, RESCON(J) is a negative value that B(J) - AMAT(:, J)^T*XOPT >= |RESCON(J)| >= DELTA.
        if (freduced) then
            dnorm = sqrt(sum(d**2))
            where (abs(rescon) >= dnorm + delta)
                rescon = min(-abs(rescon) + dnorm, -delta)
            elsewhere
                rescon = max(b - matprod(xopt, amat), ZERO)  ! Calculation changed
            end where
            rescon(trueloc(rescon >= delta)) = -rescon(trueloc(rescon >= delta))
            !!MATLAB:
            !!mask = (rescon >= delta+dnorm);
            !!rescon(mask) = max(rescon(mask) - dnorm, delta);
            !!rescon(~mask) = max(b(~mask) - (xopt'*amat(:, ~mask))', 0);
            !!rescon(rescon >= rhobeg) = -rescon(rescon >= rhobeg)
        end if

        ! Replace the current model by the least Frobenius norm interpolant if this interpolant
        ! gives substantial reductions in the predictions of values of F at feasible points.
        if (itest == 3) then
            fshift = fval - fval(kopt)
            pq = omega_mul(idz, zmat, fshift)
            hq = ZERO
            gopt = matprod(bmat(:, 1:npt), fshift) + hess_mul(xopt, xpt, pq)
        end if
    end if

    ! The calculations with the current value of RHO are complete. Pick the next value of RHO.
    if (reduce_rho) then
        if (rho <= rhoend) then
            info = SMALL_TR_RADIUS
            exit
        end if
        delta = HALF * rho
        if (rho > 250.0_RP * rhoend) then
            rho = TENTH * rho
        else if (rho <= 16.0_RP * rhoend) then
            rho = rhoend
        else
            rho = sqrt(rho * rhoend)
        end if
        delta = max(delta, rho)
        dnormsav = HUGENUM
    end if
end do

! Return from the calculation, after trying the Newton-Raphson step if it has not been tried before.
! Zaikun 20220926: Is it possible that XOPT+D has been evaluated?
if (info == SMALL_TR_RADIUS .and. shortd .and. nf < maxfun) then
    x = xbase + (xopt + d)
    call evaluate(calfun, x, f)
    ! For the output, we use A_ORIG and B_ORIG to evaluate the constraints (so RESCON is not usable).
    constr = matprod(x, A_orig) - b_orig
    cstrv = maximum([ZERO, constr])
    nf = nf + 1_IK
    call fmsg(solver, iprint, nf, f, x, cstrv, constr)
    call savehist(nf, x, xhist, f, fhist, cstrv, chist)
    feasible = .true. ! Why? Consistent with the meaning of FEASIBLE???
end if

if (fopt <= f .or. is_nan(f) .or. .not. feasible) then
    x = xbase + xopt
    f = fopt
end if

cstrv = maximum([ZERO, matprod(x, A_orig) - b_orig])

! Arrange CHIST, FHIST, and XHIST so that they are in the chronological order.
call rangehist(nf, xhist, fhist, chist)

!====================!
!  Calculation ends  !
!====================!

! Postconditions

!close (16)

end subroutine lincob


end module lincob_mod
