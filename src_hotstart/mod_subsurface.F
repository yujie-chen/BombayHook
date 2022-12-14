!------------------------------------
! Subsurface module
!------------------------------------

# if defined (SUBSURFACE)

MODULE SUBSURFACE_MODULE
  USE PARAM
  USE GLOBAL,ONLY : Mloc,Nloc,Mloc1,Nloc1,Nghost,  &
                    Mglob,Nglob, &
                    Ibeg,Iend,Jbeg,Jend,Iend1,Jend1,  &
                    DX,DY, DX2,DY2,DXDY, &
                    H,H0,H_u,H_v,ETA,U,V,P,Q,PQ,  &
                    MASK,MASKu,MASKv,MaxDepth, &
                    MinDepth,MASK,DT,tmp4preview, &
                    dt_over_dx,dt_over_dy,TIME, ETA_INITIAL
                 
  USE INPUT_Util
#if defined (PARALLEL)
  USE GLOBAL,ONLY : myid,ier, npx,npy,PX,PY,n_west,n_east,n_suth,n_nrth
  USE MPI
# endif
  IMPLICIT NONE
  SAVE

  LOGICAL :: SATUATION =.TRUE.
  LOGICAL :: OUT_ETA_GROUND = .FALSE.
  LOGICAL :: OUT_P_GROUND = .FALSE.
  LOGICAL :: OUT_Q_GROUND = .FALSE.
  LOGICAL :: OUT_MASK_GROUND = .FALSE.
  LOGICAL :: OUT_MASKu_GROUND = .FALSE.
  LOGICAL :: OUT_MASKv_GROUND = .FALSE.

  REAL(SP):: PLOT_INTV_ground,PLOT_COUNT_ground
  REAL(SP),DIMENSION(:,:),ALLOCATABLE::PORO_ground,ETA_ground,P_ground,Q_ground, &
                         Du_ground,Su_ground,Dv_ground,Sv_ground,  &
                         KAu_ground,KAv_ground,DepthX,DepthY, &
                         ETAu_ground,ETAv_ground,POROgrn
  INTEGER, DIMENSION(:,:),ALLOCATABLE::MASK_ground,MASKu_ground,MASKv_ground
  REAL(SP) :: S_constant,KA_constant,POR_constant

! statistics

    REAL(SP), DIMENSION(:,:),ALLOCATABLE :: MaxEtaGrn,MinEtaGrn
    REAL(SP) :: StartTimeStatistics

#if defined (PARALLEL)
    REAL(SP) :: myvar
# endif 

CONTAINS

! ------------------------------  
SUBROUTINE SUBSURFACE_INITIAL
  USE GLOBAL,ONLY : itmp1,itmp2,itmp3,itmp4,itmp5
                    
  USE Input_Util
  IMPLICIT NONE

  CHARACTER(LEN=80) FILE_NAME
  INTEGER::LINE
  INTEGER :: ierr

! read parameters from input.txt
      FILE_NAME='input.txt'

      CALL GET_LOGICAL_VAL(SATUATION,FILE_NAME,'SATUATION',line,ierr)

      IF(ierr==1)THEN
        SATUATION = .TRUE.
# if defined (PARALLEL)
      if (myid.eq.0) THEN
         WRITE(*,'(A80)')'No SATUATION defined, USE defalt: TRUE'
         WRITE(3,'(A80)')'No SATUATION defined, USE defalt: TRUE'
      endif
# else
         WRITE(*,'(A80)')'No SATUATION defined, USE defalt: TRUE'
         WRITE(3,'(A80)')'No SATUATION defined, USE defalt: TRUE'
# endif
       ENDIF

      CALL GET_LOGICAL_VAL(OUT_P_GROUND,FILE_NAME,'P_GROUND',line,ierr)
      CALL GET_LOGICAL_VAL(OUT_Q_GROUND,FILE_NAME,'Q_GROUND',line,ierr)
      CALL GET_LOGICAL_VAL(OUT_ETA_GROUND,FILE_NAME,'ETA_GROUND',line,ierr)
      CALL GET_LOGICAL_VAL(OUT_MASK_GROUND,FILE_NAME,'MASK_GROUND',line,ierr)
      CALL GET_LOGICAL_VAL(OUT_MASKu_GROUND,FILE_NAME,'MASKu_GROUND',line,ierr)
      CALL GET_LOGICAL_VAL(OUT_MASKv_GROUND,FILE_NAME,'MASKv_GROUND',line,ierr)

      CALL GET_Float_VAL(KA_constant,FILE_NAME,'Kappa',line,ierr)
      IF(ierr==1)THEN
        KA_constant = 0.01
# if defined (PARALLEL)
      if (myid.eq.0) THEN
         WRITE(*,'(A80)')'Kappa: Use default,', '0.01'
         WRITE(3,'(A80)')'Kappa: Use default,', '0.01'
      endif
# else
         WRITE(*,'(A80)')'Kappa: Use default,', '0.01'
         WRITE(3,'(A80)')'Kappa: Use default,', '0.01'
# endif
      ENDIF

! constant porosity
      CALL GET_Float_VAL(POR_constant,FILE_NAME,'POROSITY_GROUND',line,ierr)
      IF(ierr==1)THEN
        POR_constant = 0.3
# if defined (PARALLEL)
      if (myid.eq.0) THEN
         WRITE(*,'(A80)')'POROgrn: Use default,', '0.3'
         WRITE(3,'(A80)')'POROgrn: Use default,', '0.3'
      endif
# else
         WRITE(*,'(A80)')'POROgrn: Use default,', '0.3'
         WRITE(3,'(A80)')'POROgrn: Use default,', '0.3'
# endif
      ENDIF

      CALL GET_Float_VAL(S_constant,FILE_NAME,'HardBottom',line,ierr)
      IF(ierr==1)THEN
        S_constant = MaxDepth
# if defined (PARALLEL)
      if (myid.eq.0) THEN
         WRITE(*,'(A80)')'S_constant: Use default,', 'MaxDepth'
         WRITE(3,'(A80)')'S_constant: Use default,', 'MaxDepth'
      endif
# else
         WRITE(*,'(A80)')'S_constant: Use default,', 'MaxDepth'
         WRITE(3,'(A80)')'S_constant: Use default,', 'MaxDepth'
# endif
      ENDIF

      CALL GET_Float_VAL(StartTimeStatistics,FILE_NAME,'StartTimeStatistics',line,ierr)
      IF(ierr==1)THEN
        StartTimeStatistics = 0.0
# if defined (PARALLEL)
      if (myid.eq.0) THEN
         WRITE(*,'(A40,A40)')'StartTimeStatistics: Use default,', 'ZERO'
         WRITE(3,'(A40,A40)')'StartTimeStatistics: Use default,', 'ZERO'
      endif
# else
         WRITE(*,'(A40,A40)')'StartTimeStatistics: Use default,', 'ZERO'
         WRITE(3,'(A40,A40)')'StartTimeStatistics: Use default,', 'ZERO'
# endif
      ENDIF

! ALLOCATION

        ALLOCATE(ETA_ground(Mloc,Nloc),P_ground(Mloc1,Nloc),Q_ground(Mloc,Nloc1), &
                 Du_ground(Mloc1,Nloc),Dv_ground(Mloc,Nloc1), &
                 Su_ground(Mloc1,Nloc),Sv_ground(Mloc,Nloc1), &
                 KAu_ground(Mloc1,Nloc),KAv_ground(Mloc,Nloc1), &
                 MASK_ground(Mloc,Nloc),MASKu_ground(Mloc1,Nloc), &
                 POROgrn(Mloc,Nloc), &
                 MASKv_ground(Mloc,Nloc1), &
                 DepthX(Mloc1,Nloc),DepthY(Mloc,Nloc1), &
                 ETAu_ground(Mloc1,Nloc),ETAv_ground(Mloc,Nloc1))

    ALLOCATE(MaxEtaGrn(Mloc,Nloc),MinEtaGrn(Mloc,Nloc))

    MaxEtaGrn = -1.0*LARGE
    MinEtaGrn = LARGE

! assign variables

    MASKu_ground = 0
    MASKv_ground = 0
    MASK_ground = 0

!  hotstart
    ETA_ground = ETA_INITIAL
    ETAu_ground = ETA_INITIAL
    ETAv_ground = ETA_INITIAL
    P_ground = ZERO
    Q_ground = ZERO
    Du_ground = ZERO
    Dv_ground = ZERO

    Su_ground = S_constant
    Sv_ground = S_constant
    KAu_ground = KA_constant 
    KAv_ground = KA_constant
    POROgrn = POR_constant

    CALL UPDATE_GROUND_MASK_ETA


END SUBROUTINE SUBSURFACE_INITIAL

!------------------------

SUBROUTINE UPDATE_GROUND_MASK_ETA


! depthx and depthy
! update with time
     DepthX = H_u
     DepthY = H_v

! eta at u v points

   DO J=1,Nloc
   DO I=Ibeg,Iend1
       ETAu_ground(I,J)=0.5_SP*(ETA_ground(I-1,J)+ETA_ground(I,J))
   ENDDO
   ENDDO

   DO J=Jbeg,Jend1
   DO I=1,Mloc
       ETAv_ground(I,J)=0.5_SP*(ETA_ground(I,J-1)+ETA_ground(I,J))
   ENDDO
   ENDDO

# if defined (PARALLEL)
     CALL PHI_EXCH_2(ETAu_ground)
     CALL PHI_EXCH_3(ETAv_ground)
# endif

! thickness

    DO J=1,Nloc
    DO I=1,Mloc1
      IF(MASKu(I,J) == 0)THEN
        Du_ground(I,J) = Su_ground(I,J) +ETAu_ground(I,J)
      ELSE
        Du_ground(I,J) = Su_ground(I,J)-DepthX(I,J)+ETAu_ground(I,J)
      ENDIF
    ENDDO
    ENDDO

    DO J=1,Nloc1
    DO I=1,Mloc
      IF(MASKv(I,J) == 0)THEN
        Dv_ground(I,J) = Sv_ground(I,J) +ETAv_ground(I,J)
      ELSE
        Dv_ground(I,J) = Sv_ground(I,J)-DepthY(I,J)+ETAv_ground(I,J)
      ENDIF
    ENDDO
    ENDDO


END SUBROUTINE UPDATE_GROUND_MASK_ETA

SUBROUTINE UPDATE_SUBSURFACE
  USE GLOBAL,ONLY : itmp1,itmp2,itmp3,itmp4,itmp5,SMALL

  IMPLICIT NONE
  INTEGER::ISTEP,ISTAGE,IVAR

     CALL UPDATE_GROUND_MASK_ETA

     DO J=Jbeg,Jend
     DO I=Ibeg,Iend1
       IF(MASKu(I,J)==0)THEN
       P_ground(I,J) = - KAu_ground(I,J)*Du_ground(I,J) &
                    *(ETA_ground(I,J)-ETA_ground(I-1,J))/DX
       ENDIF
     ENDDO
     ENDDO

     DO J=Jbeg,Jend1
     DO I=Ibeg,Iend
       IF(MASKu(I,J)==0)THEN
       Q_ground(I,J) = - KAv_ground(I,J)*Dv_ground(I,J) &
                    *(ETA_ground(I,J)-ETA_ground(I,J-1))/DY
       ENDIF
     ENDDO
     ENDDO

# if defined (PARALLEL)
     CALL PHI_EXCH_2(P_ground)
     CALL PHI_EXCH_3(Q_ground)
# endif     


     DO J=Jbeg,Jend
     DO I=Ibeg,Iend
       IF(MASK(I,J)==0)THEN
         ETA_ground(I,J) = ETA_ground(I,J)  &
              -1.0_SP/POROgrn(I,J)*((P_ground(I+1,J)-P_ground(I,J))*DT/DX  &
              +(Q_ground(I,J+1)-Q_ground(I,J))*DT/DY)
       ELSE
         ETA_ground(I,J) = ETA(I,J)
       ENDIF
     ENDDO
     ENDDO

# if defined (PARALLEL)
     CALL PHI_EXCH_1(ETA_ground)
# endif

    CALL FILLIN_GRN_GHOST

     IF(TIME>StartTimeStatistics)THEN
       DO J=1,Nloc
       DO I=1,Mloc
         IF (MASK(I,J) < 1.0_SP)THEN
           IF(ETA_ground(I,J)>MaxEtaGrn(I,J))MaxEtaGrn(I,J)=ETA_ground(I,J)
           IF(ETA_ground(I,J)<MinEtaGrn(I,J))MinEtaGrn(I,J)=ETA_ground(I,J)
         ENDIF       
       ENDDO
       ENDDO
     ENDIF


END SUBROUTINE UPDATE_SUBSURFACE


SUBROUTINE FILLIN_GRN_GHOST

!	west
#	if defined(PARALLEL)
	if(	n_west .eq.	MPI_PROC_NULL	)then
#	endif

		DO J=1,Nloc
		DO I=1,Nghost
            ETA_ground(I,J) = ETA_ground(Ibeg,J)
			P_ground(I,J)=P_ground(Ibeg,J)
			Du_ground(I,J)=Du_ground(Ibeg,J)
		ENDDO
		ENDDO

		DO J=Jbeg,Jend1
		DO I=1,Nghost
			Q_ground(I,J)=Q_ground(Ibeg,J)
			Dv_ground(I,J)=Dv_ground(Ibeg,J)
		ENDDO
		ENDDO

#	if defined(PARALLEL)
	endif
#	endif

!	east
#	if defined(PARALLEL)
	if(	n_east .eq.	MPI_PROC_NULL	)then
#	endif

		DO J=1,Nloc
		DO I=Iend1+1,Mloc1
            ETA_ground(I-1,J) = ETA_ground(Iend,J)
			P_ground(I,J)=P_ground(Iend1,J)
			Du_ground(I,J)=Du_ground(Iend1,J)
		ENDDO
		ENDDO

		DO J=Jbeg,Jend1
		DO I=Iend1,Mloc
			Q_ground(I,J)=Q_ground(Iend,J)
			Dv_ground(I,J)=Dv_ground(Iend,J)
		ENDDO
		ENDDO

#	if defined(PARALLEL)
	endif
#	endif

!	south
#	if defined(PARALLEL)
	if(	n_suth .eq.	MPI_PROC_NULL	)then
#	endif

		DO J=1,Nghost
		DO I=1,Mloc
                        ETA_ground(I,J) = ETA_ground(I,Jbeg)
			Q_ground(I,J)=Q_ground(I,Jbeg)
			Dv_ground(I,J)=Dv_ground(I,Jbeg)
		ENDDO
		ENDDO

		DO J=1,Nghost
		DO I=Ibeg,Iend1
			P_ground(I,J)=P_ground(I,Jbeg)
			Du_ground(I,J)=Du_ground(I,Jbeg)
		ENDDO
		ENDDO

#	if defined(PARALLEL)
	endif
#	endif

!	north
#	if defined(PARALLEL)
	if(	n_nrth .eq.	MPI_PROC_NULL	)then
#	endif

		DO J=Jend1+1,Nloc1
		DO I=1,Mloc
                        ETA_ground(I,J-1) = ETA_ground(I,Jend)
			Q_ground(I,J)=Q_ground(I,Jend1)
			Dv_ground(I,J)=Dv_ground(I,Jend1)
		ENDDO
		ENDDO

		DO J=Jend1,Nloc
		DO I=Ibeg,Iend1
			P_ground(I,J)=P_ground(I,Jend)
			Du_ground(I,J)=Du_ground(I,Jend)
		ENDDO
		ENDDO

#	if defined(PARALLEL)
	endif
#	endif


END SUBROUTINE FILLIN_GRN_GHOST

END MODULE SUBSURFACE_MODULE
# endif
! end the module

