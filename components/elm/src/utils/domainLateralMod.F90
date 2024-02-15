module domainLateralMod

#include "shr_assert.h"
  !-----------------------------------------------------------------------
  ! This is a stub for the case when PETSc is unavailable
  !
  use shr_kind_mod, only : r8 => shr_kind_r8
  use shr_sys_mod , only : shr_sys_abort
  use spmdMod     , only : masterproc
  use elm_varctl  , only : iulog
  use spmdMod     , only : masterproc, iam, npes, mpicom, comp_id
  use abortutils  , only : endrun
  !
  ! !PUBLIC TYPES:
  implicit none
  private
  !
     
  type, public :: domainlateral_type
     integer :: dummy
  end type domainlateral_type

  type(domainlateral_type)    , public :: ldomain_lateral
  !
  ! !PUBLIC MEMBER FUNCTIONS:
  public domainlateral_init          ! allocates/nans domain types
  !
  !EOP
  !------------------------------------------------------------------------------

contains

  !------------------------------------------------------------------------------
  !BOP
  !
  ! !IROUTINE: domainlateral_init
  !
  ! !INTERFACE:
  subroutine domainlateral_init(domain_l, cellsOnCell_old, edgesOnCell_old, &
       nEdgesOnCell_old, areaCell_old, dcEdge_old, dvEdge_old, &
       nCells_loc_old, nEdges_loc_old, maxEdges)
    !
    ! !ARGUMENTS:
    implicit none
    !
    !
    type(domainlateral_type) :: domain_l                     ! domain datatype
    integer , intent(in)     :: cellsOnCell_old(:,:)         ! grid cell level connectivity information
    integer , intent(in)     :: edgesOnCell_old(:,:)         ! index to determine distance between neighbors from dcEdge [in natural order prior to domain decomposition]
    integer , intent(in)     :: nEdgesOnCell_old(:)          ! number of edges                                           [in natural order prior to domain decomposition]
    real(r8), intent(in)     :: dcEdge_old(:)                ! distance between neighbors                                [in natural order prior to domain decomposition]
    real(r8), intent(in)     :: dvEdge_old(:)                ! distance between vertices                                 [in natural order prior to domain decomposition]
    real(r8), intent(in)     :: areaCell_old(:)              ! area of grid cell                                         [in natural order prior to domain decomposition]
    integer , intent(in)     :: nCells_loc_old               ! number of local cell-to-cell connections                  [in natural order prior to domain decomposition]
    integer , intent(in)     :: nEdges_loc_old               ! number of edges                                           [in natural order prior to domain decomposition]
    integer , intent(in)     :: maxEdges                     ! max number of edges/neighbors

    character(len=*), parameter :: subname = 'domainlateral_init'

    call endrun(msg='ERROR ' // trim(subname) //': Requires '//&
         'PETSc, but the code was compiled without -DUSE_PETSC_LIB')

  end subroutine domainlateral_init

end module domainLateralMod
