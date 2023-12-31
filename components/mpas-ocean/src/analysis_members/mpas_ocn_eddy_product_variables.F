! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  ocn_eddy_product_variables
!
!> \brief MPAS ocean analysis mode member: eddy_product_variables
!> \author Mark Petersen; Alice Barthel
!> \date   Apr 2023
!> \details
!>  MPAS ocean analysis mode member: eddy_product_variables
!> computes:
!> SSH^2 SSHSquared
!> u^2 velocityZonalSquared
!> v^2  velocityMeridionalSquared
!> uT velocityZonalTimesTemperature
!> vT  velocityMeridionalTimesTemperature
!> uS velocityZonalTimesSalinity
!> vS  velocityMeridionalTimesSalinity
!> normalGMBolusVelocityTimesSalinity
!> normalMLEBolusVelocityTimesSalinity
!> normalMLEBolusVelocityTimesTemperature
!>
!> In future, could additionally compute:
!> uw velocityZonalTimesVertVel
!> vw  velocityMeridionalTimesVerVel
!> normalMLEVelocitySquared
!>
!> They you just stick these in the time-average AM.  We already time average u,v, and all tracers.
!> Then compute <v'T'> etc as a post processing step, same as POP, as follows:
!>
!> <v'T'> = <vT> - <v><T>
!> <(u')^2> = <u^2> - <u>^2
!>
!-----------------------------------------------------------------------

module ocn_eddy_product_variables

   use mpas_derived_types
   use mpas_pool_routines
   use mpas_dmpar
   use mpas_timekeeping
   use mpas_stream_manager

   use ocn_constants
   use ocn_config
   use ocn_diagnostics_variables

   implicit none
   private
   save

   !--------------------------------------------------------------------
   !
   ! Public parameters
   !
   !--------------------------------------------------------------------

   !--------------------------------------------------------------------
   !
   ! Public member functions
   !
   !--------------------------------------------------------------------

   public :: ocn_init_eddy_product_variables, &
             ocn_compute_eddy_product_variables, &
             ocn_restart_eddy_product_variables, &
             ocn_finalize_eddy_product_variables

   !--------------------------------------------------------------------
   !
   ! Private module variables
   !
   !--------------------------------------------------------------------

!***********************************************************************

contains

!***********************************************************************
!
!  routine ocn_init_eddy_product_variables
!
!> \brief   Initialize MPAS-Ocean analysis member
!> \author  Mark Petersen
!> \date    Oct 2016
!> \details
!>  This routine conducts all initializations required for the
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_init_eddy_product_variables(domain, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      type (domain_type), intent(inout) :: domain

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      err = 0

   end subroutine ocn_init_eddy_product_variables!}}}

!***********************************************************************
!
!  routine ocn_compute_eddy_product_variables
!
!> \brief   Compute MPAS-Ocean analysis member
!> \author  Mark Petersen
!> \date    Oct 2016
!> \details
!>  This routine conducts all computation required for this
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_compute_eddy_product_variables(domain, timeLevel, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      integer, intent(in) :: timeLevel

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      type (domain_type), intent(inout) :: domain

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      type (mpas_pool_type), pointer :: eddyProductVariablesAMPool
      type (dm_info) :: dminfo
      type (block_type), pointer :: block
      type (mpas_pool_type), pointer :: meshPool
      type (mpas_pool_type), pointer :: statePool
      type (mpas_pool_type), pointer :: tracersPool

      integer, pointer :: nEdges, nVertLevels, nCellsSolve
      integer :: iTracer, k, iCell, iEdge, cell1, cell2
      integer, pointer :: index_temperature, index_salinity
      integer, dimension(:), pointer :: maxLevelEdgeTop, maxLevelCell
      integer, dimension(:,:), pointer :: cellsOnEdge

      real (kind=RKIND), dimension(:), pointer :: ssh, SSHSquared
      real (kind=RKIND), dimension(:,:), pointer :: &
           velocityZonalSquared, velocityMeridionalSquared, velocityZonalTimesTemperature, velocityMeridionalTimesTemperature, &
           velocityZonalTimesSalinity, velocityMeridionalTimesSalinity, normalVelocityTimesSalinity, &
           velocityZonalTimesTemperature_GM, velocityMeridionalTimesTemperature_GM, normalVelocity, normalVelocitySquared, &
           normalVelocityTimesTemperature, normalGMBolusVelocityTimesTemperature, normalGMBolusVelocitySquared, &
           velocityZonalTimesSalinity_GM, velocityMeridionalTimesSalinity_GM, normalGMBolusVelocityTimesSalinity, &
           normalMLEVelocityTimesTemperature, normalMLEVelocityTimesSalinity, &
           velocityZonalTimesTemperature_MLE, velocityMeridionalTimesTemperature_MLE, &
           velocityZonalTimesSalinity_MLE, velocityMeridionalTimesSalinity_MLE
      real (kind=RKIND), dimension(:,:,:), pointer :: activeTracers

      err = 0

      dminfo = domain % dminfo

      block => domain % blocklist
      do while (associated(block))
         call mpas_pool_get_subpool(block % structs, 'state', statePool)
         call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
         call mpas_pool_get_subpool(statePool, 'tracers', tracersPool)
         call mpas_pool_get_subpool(block % structs, 'eddyProductVariablesAM', eddyProductVariablesAMPool)

         call mpas_pool_get_dimension(block % dimensions, 'nVertLevels', nVertLevels)
         call mpas_pool_get_dimension(block % dimensions, 'nCellsSolve', nCellsSolve)
         call mpas_pool_get_dimension(block % dimensions, 'nEdges', nEdges)

         call mpas_pool_get_array(statePool, 'normalVelocity', normalVelocity, 1)
         call mpas_pool_get_array(tracersPool, 'activeTracers', activeTracers, 1)
         call mpas_pool_get_dimension(tracersPool, 'index_temperature', index_temperature)
         call mpas_pool_get_dimension(tracersPool, 'index_salinity', index_salinity)

         call mpas_pool_get_array(statePool, 'ssh',ssh, 1)
         call mpas_pool_get_array(meshPool, 'maxLevelCell', maxLevelCell)
         call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
         call mpas_pool_get_array(meshPool, 'maxLevelEdgeTop', maxLevelEdgeTop)

         call mpas_pool_get_array(eddyProductVariablesAMPool, 'SSHSquared', SSHSquared)
         call mpas_pool_get_array(eddyProductVariablesAMPool, 'velocityZonalSquared', velocityZonalSquared)
         call mpas_pool_get_array(eddyProductVariablesAMPool, 'velocityMeridionalSquared', velocityMeridionalSquared)
         call mpas_pool_get_array(eddyProductVariablesAMPool, 'velocityZonalTimesTemperature', velocityZonalTimesTemperature)
         call mpas_pool_get_array(eddyProductVariablesAMPool, 'velocityMeridionalTimesTemperature', &
            velocityMeridionalTimesTemperature)
         call mpas_pool_get_array(eddyProductVariablesAMPool,'normalVelocityTimesTemperature', normalVelocityTimesTemperature)
         call mpas_pool_get_array(eddyProductVariablesAMPool,'normalVelocitySquared', normalVelocitySquared)
         call mpas_pool_get_array(eddyProductVariablesAMPool, 'velocityZonalTimesSalinity', velocityZonalTimesSalinity)
         call mpas_pool_get_array(eddyProductVariablesAMPool, 'velocityMeridionalTimesSalinity', &
            velocityMeridionalTimesSalinity)
         call mpas_pool_get_array(eddyProductVariablesAMPool,'normalVelocityTimesSalinity', normalVelocityTimesSalinity)

         ! if GM is active, include the GM variables.
         ! I repeated the block of code here for better performance, rather than
         ! split the GM and non-GM variables into separate loops.
         if (config_use_GM) then
            call mpas_pool_get_array(eddyProductVariablesAMPool,'velocityZonalTimesTemperature_GM', velocityZonalTimesTemperature_GM)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'velocityMeridionalTimesTemperature_GM', &
               velocityMeridionalTimesTemperature_GM)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'normalGMBolusVelocityTimesTemperature', normalGMBolusVelocityTimesTemperature)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'normalGMBolusVelocitySquared', normalGMBolusVelocitySquared)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'velocityZonalTimesSalinity_GM', velocityZonalTimesSalinity_GM)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'velocityMeridionalTimesSalinity_GM', &
               velocityMeridionalTimesSalinity_GM)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'normalGMBolusVelocityTimesSalinity', normalGMBolusVelocityTimesSalinity)

            !$omp parallel
            !$omp do schedule(runtime) private(cell1, cell2, k)
            do iEdge = 1,nEdges
               cell1 = cellsOnEdge(1,iEdge)
               cell2 = cellsOnEdge(2,iEdge)

               do k = 1, maxLevelEdgeTop(iEdge)
                  normalGMBolusVelocityTimesTemperature(k,iEdge) = 0.5_RKIND*(activeTracers(index_temperature,k,cell1) + &
                               activeTracers(index_temperature,k,cell2)) * normalGMBolusVelocity(k,iEdge)
                  normalGMBolusVelocitySquared(k,iEdge) = normalGMBolusVelocity(k,iEdge)**2
                  normalGMBolusVelocityTimesSalinity(k,iEdge) = 0.5_RKIND*(activeTracers(index_salinity,k,cell1) + &
                               activeTracers(index_salinity,k,cell2)) * normalGMBolusVelocity(k,iEdge)
               end do
            end do
            !$omp end do
            !$omp end parallel
            
            !$omp parallel
            !$omp do schedule(runtime) private(k)
            do iCell = 1,nCellsSolve
               do k = 1, maxLevelCell(iCell)
                  velocityZonalTimesTemperature_GM(k,iCell) = GMBolusVelocityZonal(k,iCell)*activeTracers(index_temperature,k,iCell)
                  velocityMeridionalTimesTemperature_GM(k,iCell) = GMBolusVelocityMeridional(k,iCell)*activeTracers(index_temperature,k,iCell)
                  velocityZonalTimesSalinity_GM(k,iCell) = GMBolusVelocityZonal(k,iCell)*activeTracers(index_salinity,k,iCell)
                  velocityMeridionalTimesSalinity_GM(k,iCell) = GMBolusVelocityMeridional(k,iCell)*activeTracers(index_salinity,k,iCell)
                end do
            end do
            !$omp end do
            !$omp end parallel
         endif

         ! if submeso is active, include the MLE variables.
         ! I split the MLE, GM and non-GM variables into separate loops for
         ! improved readability. 
         if (config_submesoscale_enable) then
            call mpas_pool_get_array(eddyProductVariablesAMPool,'velocityZonalTimesTemperature_MLE', velocityZonalTimesTemperature_MLE)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'velocityMeridionalTimesTemperature_MLE', &
               velocityMeridionalTimesTemperature_MLE)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'normalMLEVelocityTimesTemperature', normalMLEVelocityTimesTemperature)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'velocityZonalTimesSalinity_MLE', velocityZonalTimesSalinity_MLE)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'velocityMeridionalTimesSalinity_MLE', &
               velocityMeridionalTimesSalinity_MLE)
            call mpas_pool_get_array(eddyProductVariablesAMPool,'normalMLEVelocityTimesSalinity', normalMLEVelocityTimesSalinity)

            !$omp parallel
            !$omp do schedule(runtime) private(cell1, cell2, k)
            do iEdge = 1,nEdges
               cell1 = cellsOnEdge(1,iEdge)
               cell2 = cellsOnEdge(2,iEdge)

               do k = 1, maxLevelEdgeTop(iEdge)
                  normalMLEVelocityTimesTemperature(k,iEdge) = 0.5_RKIND*(activeTracers(index_temperature,k,cell1) + &
                               activeTracers(index_temperature,k,cell2)) * normalMLEVelocity(k,iEdge)
                  normalMLEVelocityTimesSalinity(k,iEdge) = 0.5_RKIND*(activeTracers(index_salinity,k,cell1) + &
                               activeTracers(index_salinity,k,cell2)) * normalMLEVelocity(k,iEdge)
               end do
            end do
            !$omp end do

            !$omp do schedule(runtime) private(k)
            do iCell = 1,nCellsSolve
               do k = 1, maxLevelCell(iCell)
                  velocityZonalTimesTemperature_MLE(k,iCell) = MLEVelocityZonal(k,iCell)*activeTracers(index_temperature,k,iCell)
                  velocityMeridionalTimesTemperature_MLE(k,iCell) = MLEVelocityMeridional(k,iCell)*activeTracers(index_temperature,k,iCell)
                  velocityZonalTimesSalinity_MLE(k,iCell) = MLEVelocityZonal(k,iCell)*activeTracers(index_salinity,k,iCell)
                  velocityMeridionalTimesSalinity_MLE(k,iCell) = MLEVelocityMeridional(k,iCell)*activeTracers(index_salinity,k,iCell)
                end do
            end do
            !$omp end do
            !$omp end parallel
         endif

         ! in any case, do the computation on resolved velocities
         !$omp parallel
         !$omp do schedule(runtime) private(cell1, cell2, k)
         do iEdge = 1,nEdges
            cell1 = cellsOnEdge(1,iEdge)
            cell2 = cellsOnEdge(2,iEdge)

            do k = 1, maxLevelEdgeTop(iEdge)
               normalVelocityTimesTemperature(k,iEdge) = 0.5_RKIND*(activeTracers(index_temperature,k,cell1) + &
                            activeTracers(index_temperature,k,cell2)) * normalVelocity(k,iEdge)
               normalVelocitySquared(k,iEdge) = normalVelocity(k,iEdge)**2
               normalVelocityTimesSalinity(k,iEdge) = 0.5_RKIND*(activeTracers(index_salinity,k,cell1) + &
                            activeTracers(index_salinity,k,cell2)) * normalVelocity(k,iEdge)
            end do
         end do
         !$omp end do
         !$omp end parallel

         !$omp parallel
         !$omp do schedule(runtime) private(k)
         do iCell = 1,nCellsSolve
            SSHSquared(iCell) = ssh(iCell)**2
            do k = 1, maxLevelCell(iCell)
               velocityZonalSquared(k,iCell) = velocityZonal(k,iCell)**2
               velocityMeridionalSquared(k,iCell) = velocityMeridional(k,iCell)**2
               velocityZonalTimesTemperature(k,iCell) = velocityZonal(k,iCell)*activeTracers(index_temperature,k,iCell)
               velocityMeridionalTimesTemperature(k,iCell) = velocityMeridional(k,iCell)*activeTracers(index_temperature,k,iCell)
               velocityZonalTimesSalinity(k,iCell) = velocityZonal(k,iCell)*activeTracers(index_salinity,k,iCell)
               velocityMeridionalTimesSalinity(k,iCell) = velocityMeridional(k,iCell)*activeTracers(index_salinity,k,iCell)
             end do
         end do
         !$omp end do
         !$omp end parallel

         block => block % next
      end do

   end subroutine ocn_compute_eddy_product_variables!}}}

!***********************************************************************
!
!  routine ocn_restart_eddy_product_variables
!
!> \brief   Save restart for MPAS-Ocean analysis member
!> \author  Mark Petersen
!> \date    Oct 2016
!> \details
!>  This routine conducts computation required to save a restart state
!>  for the MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_restart_eddy_product_variables(domain, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      type (domain_type), intent(inout) :: domain

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      err = 0

   end subroutine ocn_restart_eddy_product_variables!}}}

!***********************************************************************
!
!  routine ocn_finalize_eddy_product_variables
!
!> \brief   Finalize MPAS-Ocean analysis member
!> \author  Mark Petersen
!> \date    Oct 2016
!> \details
!>  This routine conducts all finalizations required for this
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_finalize_eddy_product_variables(domain, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      type (domain_type), intent(inout) :: domain

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      err = 0

   end subroutine ocn_finalize_eddy_product_variables!}}}

end module ocn_eddy_product_variables

! vim: foldmethod=marker
