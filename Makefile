# =============================================================================
# Vlad's minc tools builder script
#
# PURPOSE: Build ALL or a subset of the MNI-BIC tools 
#
# DETAILS:
#     This script is supposed to download one or more packages, and the build em.
# Now since one may not always want to compile the kitchen sink, Vlad has
# conveniently provided an assortment of tagets which will permit you to
# build various subsets of the totality.  Here are some options:
#
# (a) make minc-full
#     -> this makes a bunch of stuff (but not ALL, ... not really)
#     -> for those of you who don't like reading Makefiles, "minc-full" 
#        includes: netcdf, hdf5, minc,
#                  bicpl, N3, conglomerate, glim_image, mni_autoreg,
#                  mincblob, mni_perllib, ray_trace, mincbet
#
# (b) make minc-only
#     -> just makes minc and dependencies (netcdf, hdf5)
#
# (c) make minc-with-itk
#     -> just like it sounds: minc + itk + ezminc
#      
# (d) make visual
#     -> make the visualization programs: register + Display + postf
#     -> I suspect that these have been segregated from the "all" build
#        since these programs are trickier to build ... i.e. more 
#        dependencies, therefore more to go wrong.
#
#
#
#
# EXAMPLES:
#
# [A] >> make minc-only INSTALL_DIR=`realpath install_dir`  BUILD_DIR=`realpath build_dir`
#
# Notes --
# (1) we are building a relatively small install comprising minc (and dependencies) only 
# (2) INSTALL_DIR = the directory root to which you expect the built packages
#     to be installed. For example, this could be "/usr/local/bic" ... but if
#     it is, you had better be running as root. Default is the current dir.
# (3) we use the "realpath" program to expand out my local dir (eg. "install_dir")
#     into a full absolute path name. It would appear as if this Makefile does not
#     like relative paths. If on Debian/Ubuntu, type "sudo apt-get realpath".
# (4) BUILD_DIR is a temporary build directory. Feel free to wipe it out when 
#     the build is complete. Default is the current dir.
#
#
# [B] >>make minc-with-itk INSTALL_DIR=`realpath install_dir`  BUILD_DIR=`realpath build_dir`
#
# Notes -- 
# (1) the same as above, but add ezminc, itk, and their dependencies
#
#
# [C] >>make minc-full INSTALL_DIR=`realpath install_dir`  BUILD_DIR=`realpath build_dir` PARALLEL_BUILD=-j2
#     >>make visual INSTALL_DIR=`realpath install_dir`  BUILD_DIR=`realpath build_dir`
#     >>make models  INSTALL_DIR=`realpath install_dir`  BUILD_DIR=`realpath build_dir`
#
# Notes -- 
# (1) make all ... and use up to 2 cores
# (2) make register, Display and postf (needs the previous make to finish first)
#     NB: currently (20May2011) Display needs to have its final link line corrected in order
#         to produce an executable
# (3) install a whack of MNI-BIC models for use with mritotal, etc.
#
#
# DEPENDENCIES:
#  Ubuntu Lucid 10.04 LTS
#     (i) You do not want nor need netcdf or hdf5 from the repos, as we build  
#         these from source. If these are around, get rid of them if you can,
#         else linking could end of grabbing the wrong version
#    (ii) apt-get the following before you start:
#         -> build-essential (for compilers, make, etc)
#         -> realpath (see above)
#         -> zlib1g-dev (minc)
#         -> bison (minc)
#         -> flex (minc)
#         -> libx11-dev (ray-trace)
#         -> glutg3-dev (ray-trace)
#         -> libxmu-dev, libxi-dev (ray-trace)
#
#  sudo apt-get install build-essential realpath \
#                       zlib1g-dev bison flex \
#                       libx11-dev glutg3-dev libxmu-dev libxi-dev
#
#  
#  Ubuntu 11.04 
#  
#  sudo apt-get install build-essential realpath \
#                       zlib1g-dev bison flex \
#                       libx11-dev glutg3-dev libxmu-dev libxi-dev \
#                       automake libtool
#  
# =============================================================================
#

.DEFAULT_GOAL = help

.PHONY : create_output_dirs output_dirs clean list models \
         minc-only minc-full minc-with-itk ezminc  \
         bicpl ebtks conglomerate n3 mincmorph mincblob oobicpl ray_trace \
         mni-models_average305-lin mni-models_colin27-lin mni-models_icbm152-lin \
         mni-models_icbm152-nl-6gen mni-models_icbm152-nl-40gen mni_autoreg_model \
         help

help :
	@echo      This script is supposed to download one or more packages, and the build em.
	@echo  Now since one may not always want to compile the kitchen sink, Vlad has
	@echo  conveniently provided an assortment of tagets which will permit you to
	@echo  build various subsets of the totality.  Here are some options\:
	@echo 
	@echo  \(a\) make minc-full
	@echo      -\> this makes a bunch of stuff \(but not ALL, ... not really\)
	@echo      -\> for those of you who don\'t like reading Makefiles, \"minc-full\"
	@echo         includes: netcdf, hdf5, minc,
	@echo                   bicpl, N3, conglomerate, glim_image, mni_autoreg,
	@echo                   mincblob, mni_perllib, ray_trace, mincbet
	@echo 
	@echo  \(b\) make minc-only
	@echo      -\> just makes minc and dependencies \(netcdf, hdf5\)
	@echo 
	@echo  \(c\) make minc-with-itk
	@echo      -\> just like it sounds: minc + itk + ezminc
	@echo       
	@echo  \(d\) make visual
	@echo      -\> make the visualization programs: register, Display, and postf 
	@echo      -\> I suspect that these have been segregated from the \"all\" build
	@echo         since these programs are trickier to build ... i.e. more 
	@echo         dependencies, therefore more to go wrong.
	@echo 
	@echo EXAMPLE\:
	@echo make minc-only INSTALL_DIR=\`realpath install_dir\`  BUILD_DIR=\`realpath build_dir\` PARALLEL_BUILD=-j2



# some important environment variables
# default to current dir
BUILD_DIR?=$(shell pwd)
# default to current dir
INSTALL_DIR?=$(shell pwd)
# specify number of parallel tasks in building 
PARALLEL_BUILD?=-j1
#                                      (number of cores you can use for compiling)
WGET := wget -c                      # wget command
CMAKE := $(INSTALL_DIR)/bin/cmake    # where to find CMAKE (allow for over-ride)

# define output directories used by the build/install process
output_dirs := $(BUILD_DIR)/src \
			$(INSTALL_DIR)/include \
			$(INSTALL_DIR)/lib \
			$(INSTALL_DIR)/bin \
			$(INSTALL_DIR)/share/mni-models \
			$(INSTALL_DIR)/share/mni_autoreg \
			$(INSTALL_DIR)/share/man/man1 \
			$(INSTALL_DIR)/share/man/man3




# *****************************************************************************
# Package versions
# *****************************************************************************
#
NETCDF_VER       := 4.0.1
HDF5_VER         := 1.8.7
#MINC_VER         := 9e69692
MINC_VER         := 90b5d40
BICPL_VER        := 1.4.6
EBTKS_VER        := 1.6.4
OOBICPL_VER      := 0.4.4
N3_VER           := 1.12.0
CLASSIFY_VER     := 1.1.0
CONGLOMERATE_VER := 1.6.6
MNI_AUTOREG_VER  := 0.99.6
MNI_PERLLIB_VER  := 0.08
MINCBLOB_VER     := 1.2.1
MINCMORPH_VER    := 1.4
RAYTRACE_VER     := 1.0.3
GLIMIMAGE_VER    := 1.2
ITK_VER          := 3.20.0
FFTW_VER         := 3.2.2
CMAKE_VER        := 2.8.4
GSL_VER          := 1.15
GETOPT_TABULAR_VER := 0.3
EZMINC_VER       := 92519b5
NETPBM_VER       := 10.35.74
VTK_VER          := 5.6.1
FLTK_VER         := 1.3.x-r7725
REGISTER_VER     := 1.4.0
DISPLAY_VER      := 1.5.0
POSTF_VER        := 1.0.03
INORMALIZE_VER   := 1.0.2
ARGUMENTS_VER    := 0.2.1
PCRE_VER         := 8.12
PCREPP_VER       := 0.9.5
#
# The ones added for the MICe quarantine
#
BICINVENTOR_VER         := 0.3.1
LAPLACIAN_THICKNESS_VER := 1.1.2
MINCANTS_VER            := 1p9_p1
MINCANTS_VER_SHORT      := 1p9
MICE_MINC_TOOLS_VER     := 0.1
MOUSE_THICKNESS_VER     := 0.1
PERL_TEST_FILES_VER     := 0.14
PMP_VER                 := 0.7.10
PYTHON_VER              := 2.7.2
PYMINC_VER              := 0.2
NUMPY_VER               := 1.6.1
SCIPY_VER               := 0.9.0
R_VER                   := 2.13.1
XFMAVG_VER              := 1.0.0
# RMINC_VER               := 0.5.10
MBM_VER                 := 0.6.1
TAGTOXFM_BSPLINE_VER    := 1.0
COIN_3D_VER             := 3.1.3
QUARTER_VER             := 1.0.0
BRAIN_VIEW2_VER         := 0.2-01-sept-2011
#
# end of added for MICe
#
MNI_MODELS_AVERAGE305_LIN_VER  := 1.1
MNI_MODELS_COLIN27_LIN_VER     := 1.1
MNI_MODELS_ICBM_LIN_VER        := 1.1
MNI_MODELS_ICBM_NL_6GEN_VER    := 1.0
MNI_MODELS_ICBM_NL_40GEN_VER   := 1.0
MNI_AUTOREG_MODEL_VER          := 1.1


# *****************************************************************************
# Name and path of compressed source packages following download 
# ... that is, where they are expected to be unless not yet downloaded
# *****************************************************************************
#
archives := \
$(BUILD_DIR)/src/netcdf-$(NETCDF_VER).tar.gz \
$(BUILD_DIR)/src/hdf5-$(HDF5_VER).tar.gz \
$(BUILD_DIR)/src/mcvaneede-minc-$(MINC_VER).tar.gz \
$(BUILD_DIR)/src/bicpl-$(BICPL_VER).tar.gz \
$(BUILD_DIR)/src/ebtks-$(EBTKS_VER).tar.gz \
$(BUILD_DIR)/src/oobicpl-$(OOBICPL_VER).tar.gz \
$(BUILD_DIR)/src/N3-$(N3_VER).tar.gz \
$(BUILD_DIR)/src/classify-$(CLASSIFY_VER).tar.gz \
$(BUILD_DIR)/src/conglomerate-$(CONGLOMERATE_VER).tar.gz \
$(BUILD_DIR)/src/mni_autoreg-$(MNI_AUTOREG_VER).tar.gz \
$(BUILD_DIR)/src/mni_perllib-$(MNI_PERLLIB_VER).tar.gz \
$(BUILD_DIR)/src/mincblob-$(MINCBLOB_VER).tar.gz \
$(BUILD_DIR)/src/mincmorph-$(MINCMORPH_VER).tar.gz \
$(BUILD_DIR)/src/ray_trace-$(RAYTRACE_VER).tar.gz \
$(BUILD_DIR)/src/glim_image-$(GLIMIMAGE_VER).tar.gz \
$(BUILD_DIR)/src/InsightToolkit-$(ITK_VER).tar.gz \
$(BUILD_DIR)/src/fftw-$(FFTW_VER).tar.gz \
$(BUILD_DIR)/src/cmake-$(CMAKE_VER).tar.gz \
$(BUILD_DIR)/src/gsl-$(GSL_VER).tar.gz \
$(BUILD_DIR)/src/Getopt-Tabular-$(GETOPT_TABULAR_VER).tar.gz \
$(BUILD_DIR)/src/vfonov-EZminc-$(EZMINC_VER).tar.gz  \
$(BUILD_DIR)/src/netpbm-$(NETPBM_VER).tar.gz \
$(BUILD_DIR)/src/Register-$(REGISTER_VER).tar.gz \
$(BUILD_DIR)/src/Display-$(DISPLAY_VER).tar.gz \
$(BUILD_DIR)/src/postf-$(POSTF_VER).tar.gz \
$(BUILD_DIR)/src/inormalize-${INORMALIZE_VER}.tar.gz \
$(BUILD_DIR)/src/arguments-$(ARGUMENTS_VER).tar.gz \
$(BUILD_DIR)/src/pcre-$(PCRE_VER).tar.gz \
$(BUILD_DIR)/src//pcre++-$(PCREPP_VER).tar.gz \
$(BUILD_DIR)/src/mni-models_average305-lin-$(MNI_MODELS_AVERAGE305_LIN_VER).tar.gz  \
$(BUILD_DIR)/src/mni-models_colin27-lin-$(MNI_MODELS_COLIN27_LIN_VER).tar.gz     \
$(BUILD_DIR)/src/mni-models_icbm152-lin-$(MNI_MODELS_ICBM_LIN_VER).tar.gz     \
$(BUILD_DIR)/src/mni-models_icbm152-nl-$(MNI_MODELS_ICBM_NL_6GEN_VER).tar.gz  \
$(BUILD_DIR)/src/mni-models_icbm152-nl-2009-$(MNI_MODELS_ICBM_NL_40GEN_VER).tar.gz  \
$(BUILD_DIR)/src/mni_autoreg_model-$(MNI_AUTOREG_MODEL_VER).tar.gz \
$(BUILD_DIR)/src/bicInventor-$(BICINVENTOR_VER).tar.gz \
$(BUILD_DIR)/src/laplacian_thickness-$(LAPLACIAN_THICKNESS_VER).tar.gz \
$(BUILD_DIR)/src/mincANTS_$(MINCANTS_VER).tar.gz \
$(BUILD_DIR)/src/mice-minc-tools-$(MICE_MINC_TOOLS_VER).tar.gz \
$(BUILD_DIR)/src/mouse-thickness-$(MOUSE_THICKNESS_VER).tar.gz \
$(BUILD_DIR)/src/Test-Files-$(PERL_TEST_FILES_VER).tar.gz \
$(BUILD_DIR)/src/PMP-$(PMP_VER).tar.gz \
$(BUILD_DIR)/src/pyminc-$(PYMINC_VER).tar.gz \
$(BUILD_DIR)/src/numpy-$(NUMPY_VER).tar.gz \
$(BUILD_DIR)/src/scipy-$(SCIPY_VER).tar.gz \
$(BUILD_DIR)/src/R-$(R_VER).tar.gz \
$(BUILD_DIR)/src/MBM-$(MBM_VER).tar.gz \
$(BUILD_DIR)/src/tagtoxfm_bspline_$(TAGTOXFM_BSPLINE_VER).tar.gz \
$(BUILD_DIR)/src/Coin-$(COIN_3D_VER).tar.gz \
$(BUILD_DIR)/src/Quarter-$(QUARTER_VER).tar.gz \
$(BUILD_DIR)/src/brain-view2-$(BRAIN_VIEW2_VER).tar.gz

# $(BUILD_DIR)/src/RMINC-$(RMINC_VER).tar.gz \

# *****************************************************************************
# Install target files
# ... these are the files that Make uses to check whether the target
#     needs to be rebuilt or not. 
# ... Make will look for these files and :
#     (1) if non-existent, will rebuild the package
#     (2) if existent, but out-of-date, will also rebuild  
# *****************************************************************************
#
netcdf         := $(INSTALL_DIR)/lib/libnetcdf.a $(INSTALL_DIR)/include/netcdf.h
hdf5           := $(INSTALL_DIR)/lib/libhdf5.a $(INSTALL_DIR)/include/hdf5.h
minc           := $(INSTALL_DIR)/lib/libminc2.a $(INSTALL_DIR)/include/minc2.h
fftw           := $(INSTALL_DIR)/lib/libfftw3f.a $(INSTALL_DIR)/include/fftw3.h
gsl            := $(INSTALL_DIR)/lib/libgsl.a $(INSTALL_DIR)/include/gsl/gsl_math.h
bicpl          := $(INSTALL_DIR)/lib/libbicpl.a $(INSTALL_DIR)/include/bicpl.h
itk            := $(INSTALL_DIR)/lib/InsightToolkit/UseITK.cmake
ezminc         := $(INSTALL_DIR)/lib/libminc_io.a $(INSTALL_DIR)/include/minc_1_rw.h $(INSTALL_DIR)/lib/libminc4itk.a
cmake          := $(INSTALL_DIR)/bin/cmake
bicpl          := $(INSTALL_DIR)/include/bicpl.h $(INSTALL_DIR)/lib/libbicpl.a
netpbm         := $(INSTALL_DIR)/lib/libnetpbm.a
n3             := $(INSTALL_DIR)/bin/nu_correct
ebtks          := $(INSTALL_DIR)/lib/libEBTKS.a
oobicpl        := $(INSTALL_DIR)/lib/liboobicpl.a
conglomerate   := $(INSTALL_DIR)/bin/mincdefrag
glim_image     := $(INSTALL_DIR)/bin/glim_image
mni_autoreg    := $(INSTALL_DIR)/bin/minctracc
mincblob       := $(INSTALL_DIR)/bin/mincblob
mincmorph      := $(INSTALL_DIR)/bin/mincmorph
ray_trace      := $(INSTALL_DIR)/bin/ray_trace
getopt_tabular := $(INSTALL_DIR)/perl/Getopt/Tabular.pm
mni_perllib    := $(INSTALL_DIR)/perl/MNI.pm
register       := $(INSTALL_DIR)/bin/register
Display        := $(INSTALL_DIR)/bin/Display
postf          := $(INSTALL_DIR)/bin/postf
vtk            := $(INSTALL_DIR)/lib/vtk-5.6/UseVTK.cmake
fltk           := $(INSTALL_DIR)/lib/FLTK-1.3/UseFLTK.cmake
classify       := $(INSTALL_DIR)/bin/classify
inormalize     := $(INSTALL_DIR)/bin/inormalize
arguments      := $(INSTALL_DIR)/lib/libarguments.a
pcre           := $(INSTALL_DIR)/lib/libpcre.a
pcrepp         := $(INSTALL_DIR)/lib/libpcre++.a
#
# The ones added for the MICe quarantine
#
bicinventor         := $(INSTALL_DIR)/lib/libbicInventor.a $(INSTALL_DIR)/bin/iv2bicobj
laplacian_thickness := $(INSTALL_DIR)/bin/laplacian_thickness
mincANTS            := $(INSTALL_DIR)/bin/mincANTS
mice_minc_tools     := $(INSTALL_DIR)/bin/minc_displacement $(INSTALL_DIR)/bin/lin_from_nlin
mouse_thickness     := $(INSTALL_DIR)/bin/MICe_thickness
perl_test_files     := $(INSTALL_DIR)/perl/Test/Files.pm
pmp                 := $(INSTALL_DIR)/perl/PMP/PMP.pm
python              := $(INSTALL_DIR)/bin/python
pyminc              := $(INSTALL_DIR)/python/pyminc/volumes/volumes.py
numpy               := $(INSTALL_DIR)/python/numpy/numarray/numerictypes.py
scipy               := $(INSTALL_DIR)/python/scipy/interpolate/interpolate.py
R                   := $(INSTALL_DIR)/bin/R
xfmavg              := $(INSTALL_DIR)/bin/xfmavg
RMINC               := $(INSTALL_DIR)/lib/R/library/RMINC/libs/RMINC.so
MBM                 := $(INSTALL_DIR)/bin/MICe-build-model.pl
tagtoxfm_bspline    := $(INSTALL_DIR)/bin/tagtoxfm_bspline
coin3d              := $(INSTALL_DIR)/lib/libCoin.la
quarter             := $(INSTALL_DIR)/lib/libQuarter.la
brain_view2         := $(INSTALL_DIR)/bin/brain-view2
#
# end of added for MICe
#
mni-models_average305-lin   := $(INSTALL_DIR)/share/mni-models/average305_t1_tal_lin.mnc.gz
mni-models_colin27-lin      := $(INSTALL_DIR)/share/mni-models/colin27_t1_tal_lin.mnc.gz
mni-models_icbm152-lin      := $(INSTALL_DIR)/share/mni-models/icbm_avg_152_t2_tal_lin.mnc.gz
mni-models_icbm152-nl-6gen  := $(INSTALL_DIR)/share/mni-models/icbm_avg_152_t1_tal_nlin_symmetric_VI.mnc.gz
mni-models_icbm152-nl-40gen := $(INSTALL_DIR)/share/mni-models/mni_icbm152_t1_tal_nlin_sym_09a.mnc.gz
mni_autoreg_model           := $(INSTALL_DIR)/share/mni_autoreg/average_305.mnc.gz



# *****************************************************************************
#
# Top-level targets
#
# *****************************************************************************
#
minc-full : create_output_dirs bicpl n3 conglomerate glim_image mni_autoreg mincblob mni_perllib ray_trace ezminc mincbet classify mincmorph inormalize

minc-with-itk : $(output_dirs) minc itk ezminc vtk

minc : $(output_dirs) $(minc) $(hdf5) $(netcdf)
minc-only : $(output_dirs) $(minc) $(hdf5) $(netcdf)

models : $(output_dirs) mni-models_average305-lin \
                        mni-models_colin27-lin \
                        mni-models_icbm152-lin \
                        mni-models_icbm152-nl-6gen \
                        mni-models_icbm152-nl-40gen \
                        mni_autoreg_model

minc-extra : $(output_dirs) fftw getopt_tabular oobicpl pcre pcrepp 

MICe : $(output_dirs) coin3d bicinventor mincANTS mice_minc_tools mouse_thickness perl_test_files python pyminc numpy scipy R xfmavg RMINC tagtoxfm_bspline quarter brain_view2

MICe-fuzzy: $(output_dirs) laplacian_thickness pmp MBM 

full-MICe-quarantine : minc-full visual minc-extra MICe

full-SciNet-MICe-quarantine: minc-full minc-extra MICe

clean : 
	rm -rf $(source_dirs)

ezminc : $(output_dirs)  $(ezminc)  
itk : $(output_dirs)  $(itk)
vtk : $(output_dirs) $(vtk)
fltk : $(output_dirs) $(fltk)
bicpl : $(output_dirs) $(bicpl)
ebtks : $(output_dirs) $(ebtks)
n3 : $(output_dirs) $(n3)
oobicpl : $(output_dirs) $(oobicpl)
conglomerate : $(output_dirs)  $(conglomerate)
mincmorph : $(output_dirs) $(mincmorph)
mincblob : $(output_dirs) $(mincblob)
mincbet : $(output_dirs) $(mincbet)
ray_trace : $(output_dirs) $(ray_trace)
getopt_tabular : $(output_dirs) $(getopt_tabular)
mni_perllib : $(output_dirs) $(mni_perllib)
visual : $(output_dirs)  $(postf) $(register) $(Display)
register : $(output_dirs) $(register)
Display : $(output_dirs) $(Display)
postf : $(output_dirs) $(postf)
cmake : $(output_dirs) $(cmake)
classify : $(output_dirs) $(classify) 
fftw : $(output_dirs) $(fftw)
glim_image : $(output_dirs) $(glim_image)
mni_autoreg : $(output_dirs) $(mni_autoreg)
inormalize : $(output_dirs)  $(inormalize)
arguments : $(output_dirs) $(arguments) 
pcre      : $(output_dirs) $(pcre)
pcrepp    : $(output_dirs) $(pcrepp)
mni-models_average305-lin : $(mni-models_average305-lin)
mni-models_colin27-lin : $(mni-models_colin27-lin)
mni-models_icbm152-lin : $(mni-models_icbm152-lin)
mni-models_icbm152-nl-6gen : $(mni-models_icbm152-nl-6gen)
mni-models_icbm152-nl-40gen : $(mni-models_icbm152-nl-40gen)
mni_autoreg_model : $(mni_autoreg_model)

#
# The ones added for the MICe quarantine
#
bicinventor: $(output_dirs) $(bicinventor)
laplacian_thickness : $(output_dirs) $(laplacian_thickness)
mincANTS : $(output_dirs) $(mincANTS)
mice_minc_tools : $(output_dirs) $(mice_minc_tools)
mouse_thickness : $(output_dirs) $(mouse_thickness)
perl_test_files : $(output_dirs) $(perl_test_files)
pmp : $(output_dirs) $(pmp)
python : $(output_dirs) $(python)
pyminc : $(output_dirs) $(pyminc)
numpy : $(output_dirs) $(numpy)
scipy : $(output_dirs) $(scipy)
R : $(output_dirs) $(R)
xfmavg : $(output_dirs) $(xfmavg)
RMINC : $(output_dirs) $(RMINC)
MBM : $(output_dirs) $(MBM)
tagtoxfm_bspline : $(output_dirs) $(tagtoxfm_bspline)
coin3d : $(output_dirs) $(coin3d)
quarter: $(output_dirs) $(quarter)
brain_view2 : $(output_dirs) $(brain_view2)
#
# end of added for MICe
#


# *****************************************************************************
#
# Targets involved in the unpacking of downloaded tarballs
#
# *****************************************************************************
#
$(BUILD_DIR)/src/ezminc :  $(BUILD_DIR)/src/ezminc-$(EZMINC_VER).tar.gz  
	cd $(BUILD_DIR)/src && tar zxf  $<
	touch $@

$(BUILD_DIR)/src/VTK : $(BUILD_DIR)/src/vtk-$(VTK_VER).tar.gz
	cd $(BUILD_DIR)/src && tar zxf  $<
	touch $@

$(BUILD_DIR)/src/fltk-$(FLTK_VER) :  $(BUILD_DIR)/src/fltk-$(FLTK_VER).tar.bz2
	cd $(BUILD_DIR)/src && tar jxf  $<
	touch $@
#
# The ones added for the MICe quarantine
#
$(BUILD_DIR)/src/Python-$(PYTHON_VER): $(BUILD_DIR)/src/Python-$(PYTHON_VER).tgz
	cd $(BUILD_DIR)/src && tar zxf  $<
	touch $@
#
# end of added for MICe
#

# strip the .tar.gz suffix from the tarball to create the source directory name 
source_dirs := $(archives:.tar.gz=)
#
# here we see the use of a static pattern rule in which the target names
# ... are used to generate the dependency names (one for each target)
# ... In this case, we append ".tar.gz" to each source dir name ... which really
# ... should equal the value in $(archives), yes?
$(source_dirs) : % : %.tar.gz
	$(shell echo cd $(BUILD_DIR)/src && echo tar zxf  $< )
	cd $(BUILD_DIR)/src && tar zxf  $<
	touch $@



# *****************************************************************************
#
# Targets involved in downloading the compressed sources
#
# *****************************************************************************
#
$(BUILD_DIR)/src/netcdf-$(NETCDF_VER).tar.gz : 
	$(WGET) ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-$(NETCDF_VER).tar.gz \
 -O $(BUILD_DIR)/src/netcdf-$(NETCDF_VER).tar.gz

$(BUILD_DIR)/src/hdf5-$(HDF5_VER).tar.gz : 
	$(WGET) http://www.hdfgroup.org/ftp/HDF5/hdf5-1.8.7/src/hdf5-$(HDF5_VER).tar.gz \
 -O $(BUILD_DIR)/src/hdf5-$(HDF5_VER).tar.gz

$(BUILD_DIR)/src/mcvaneede-minc-$(MINC_VER).tar.gz : 
	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/mcvaneede-minc-$(MINC_VER).tar.gz \
	-O $(BUILD_DIR)/src/mcvaneede-minc-$(MINC_VER).tar.gz

$(BUILD_DIR)/src/bicpl-$(BICPL_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/bicpl-$(BICPL_VER).tar.gz  \
  -O $(BUILD_DIR)/src/bicpl-$(BICPL_VER).tar.gz

$(BUILD_DIR)/src/ebtks-$(EBTKS_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/ebtks-$(EBTKS_VER).tar.gz  \
 -O $(BUILD_DIR)/src/ebtks-$(EBTKS_VER).tar.gz

$(BUILD_DIR)/src/ebtks-1.6.4-VF.patch.gz : 
	$(WGET) http://www.bic.mni.mcgill.ca/~vfonov/software/ebtks-1.6.4-VF.patch.gz \
 -O $(BUILD_DIR)/src/ebtks-1.6.4-VF.patch.gz

$(BUILD_DIR)/src/oobicpl-$(OOBICPL_VER).tar.gz : 
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/oobicpl-$(OOBICPL_VER).tar.gz \
 -O $(BUILD_DIR)/src/oobicpl-$(OOBICPL_VER).tar.gz

$(BUILD_DIR)/src/N3-$(N3_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/N3-$(N3_VER).tar.gz \
 -O $(BUILD_DIR)/src/N3-$(N3_VER).tar.gz

$(BUILD_DIR)/src/classify-$(CLASSIFY_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/classify-$(CLASSIFY_VER).tar.gz \
 -O $(BUILD_DIR)/src/classify-$(CLASSIFY_VER).tar.gz

$(BUILD_DIR)/src/conglomerate-$(CONGLOMERATE_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/conglomerate-$(CONGLOMERATE_VER).tar.gz \
 -O $(BUILD_DIR)/src/conglomerate-$(CONGLOMERATE_VER).tar.gz

$(BUILD_DIR)/src/mni_autoreg-$(MNI_AUTOREG_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/mni_autoreg-$(MNI_AUTOREG_VER).tar.gz \
 -O $(BUILD_DIR)/src/mni_autoreg-$(MNI_AUTOREG_VER).tar.gz

$(BUILD_DIR)/src/mni_perllib-$(MNI_PERLLIB_VER).tar.gz :
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/mni_perllib-$(MNI_PERLLIB_VER).tar.gz \
 -O $(BUILD_DIR)/src/mni_perllib-$(MNI_PERLLIB_VER).tar.gz

$(BUILD_DIR)/src/mincblob-$(MINCBLOB_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/mincblob-$(MINCBLOB_VER).tar.gz \
 -O $(BUILD_DIR)/src/mincblob-$(MINCBLOB_VER).tar.gz

$(BUILD_DIR)/src/mincmorph-$(MINCMORPH_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/mincmorph-$(MINCMORPH_VER).tar.gz \
 -O $(BUILD_DIR)/src/mincmorph-$(MINCMORPH_VER).tar.gz

$(BUILD_DIR)/src/ray_trace-$(RAYTRACE_VER).tar.gz : 
	$(WGET)  http://packages.bic.mni.mcgill.ca/tgz/ray_trace-$(RAYTRACE_VER).tar.gz \
 -O $(BUILD_DIR)/src/ray_trace-$(RAYTRACE_VER).tar.gz

$(BUILD_DIR)/src/glim_image-$(GLIMIMAGE_VER).tar.gz : 
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/glim_image-$(GLIMIMAGE_VER).tar.gz \
 -O $(BUILD_DIR)/src/glim_image-$(GLIMIMAGE_VER).tar.gz

$(BUILD_DIR)/src/InsightToolkit-$(ITK_VER).tar.gz : 
	$(WGET) http://downloads.sourceforge.net/project/itk/itk/$(ITK_VER:.0=)/InsightToolkit-$(ITK_VER).tar.gz \
 -O $(BUILD_DIR)/src/InsightToolkit-$(ITK_VER).tar.gz

$(BUILD_DIR)/src/vtk-$(VTK_VER).tar.gz : 
	$(WGET) http://www.vtk.org/files/release/5.6/vtk-$(VTK_VER).tar.gz \
 -O $(BUILD_DIR)/src/vtk-$(VTK_VER).tar.gz

$(BUILD_DIR)/src/fltk-$(FLTK_VER).tar.bz2 : 
	$(WGET) http://ftp2.easysw.com/pub/fltk/snapshots/fltk-$(FLTK_VER).tar.bz2 \
 -O $(BUILD_DIR)/src/fltk-$(FLTK_VER).tar.bz2

$(BUILD_DIR)/src/fftw-$(FFTW_VER).tar.gz :
	$(WGET)  http://www.fftw.org/fftw-$(FFTW_VER).tar.gz \
 -O $(BUILD_DIR)/src/fftw-$(FFTW_VER).tar.gz

$(BUILD_DIR)/src/cmake-$(CMAKE_VER).tar.gz :
	$(WGET)  http://www.cmake.org/files/v2.8/cmake-$(CMAKE_VER).tar.gz \
 -O $(BUILD_DIR)/src/cmake-$(CMAKE_VER).tar.gz

$(BUILD_DIR)/src/gsl-$(GSL_VER).tar.gz :
	$(WGET) http://mirrors.ibiblio.org/pub/mirrors/gnu/ftp/gnu/gsl/gsl-$(GSL_VER).tar.gz \
 -O $(BUILD_DIR)/src/gsl-$(GSL_VER).tar.gz

$(BUILD_DIR)/src/Getopt-Tabular-$(GETOPT_TABULAR_VER).tar.gz : 
	$(WGET) http://search.cpan.org/CPAN/authors/id/G/GW/GWARD/Getopt-Tabular-$(GETOPT_TABULAR_VER).tar.gz \
 -O $(BUILD_DIR)/src/Getopt-Tabular-$(GETOPT_TABULAR_VER).tar.gz

$(BUILD_DIR)/src/arguments-$(ARGUMENTS_VER).tar.gz : 
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/arguments-$(ARGUMENTS_VER).tar.gz \
 -O $(BUILD_DIR)/src/arguments-$(ARGUMENTS_VER).tar.gz

$(BUILD_DIR)/src/pcre-$(PCRE_VER).tar.gz :
	$(WGET) http://downloads.sourceforge.net/project/pcre/pcre/$(PCRE_VER)/pcre-$(PCRE_VER).tar.gz \
 -O $(BUILD_DIR)/src/pcre-$(PCRE_VER).tar.gz

$(BUILD_DIR)/src//pcre++-$(PCREPP_VER).tar.gz :
	$(WGET) http://www.daemon.de/idisk/Apps/pcre++/pcre++-$(PCREPP_VER).tar.gz \
 -O $(BUILD_DIR)/src//pcre++-$(PCREPP_VER).tar.gz

$(BUILD_DIR)/src/vfonov-EZminc-$(EZMINC_VER).tar.gz : 
	$(WGET) --no-check-certificate https://github.com/vfonov/EZminc/tarball/92519b508742e8a37a82 \
 -O $(BUILD_DIR)/src/vfonov-EZminc-$(EZMINC_VER).tar.gz

$(BUILD_DIR)/src/netpbm-$(NETPBM_VER).tar.gz : 
	$(WGET) 'http://downloads.sourceforge.net/project/netpbm/super_stable/$(NETPBM_VER)/netpbm-$(NETPBM_VER).tgz?use_mirror=cdnetworks-us-1' \
             -O $(BUILD_DIR)/src/netpbm-$(NETPBM_VER).tar.gz

$(BUILD_DIR)/src/Display-$(DISPLAY_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/Display-$(DISPLAY_VER).tar.gz \
 -O $(BUILD_DIR)/src/Display-$(DISPLAY_VER).tar.gz

$(BUILD_DIR)/src/Register-$(REGISTER_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/Register-$(REGISTER_VER).tar.gz \
 -O $(BUILD_DIR)/src/Register-$(REGISTER_VER).tar.gz

$(BUILD_DIR)/src/postf-$(POSTF_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/postf-$(POSTF_VER).tar.gz \
 -O $(BUILD_DIR)/src/postf-$(POSTF_VER).tar.gz
 
$(BUILD_DIR)/src/inormalize-${INORMALIZE_VER}.tar.gz : 
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/inormalize-$(INORMALIZE_VER).tar.gz \
 -O $(BUILD_DIR)/src/inormalize-$(INORMALIZE_VER).tar.gz

$(BUILD_DIR)/src/mni-models_average305-lin-$(MNI_MODELS_AVERAGE305_LIN_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/mni-models_average305-lin-$(MNI_MODELS_AVERAGE305_LIN_VER).tar.gz \
 -O $(BUILD_DIR)/src/mni-models_average305-lin-$(MNI_MODELS_AVERAGE305_LIN_VER).tar.gz

$(BUILD_DIR)/src/mni-models_colin27-lin-$(MNI_MODELS_COLIN27_LIN_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/mni-models_colin27-lin-$(MNI_MODELS_COLIN27_LIN_VER).tar.gz \
 -O $(BUILD_DIR)/src/mni-models_colin27-lin-$(MNI_MODELS_COLIN27_LIN_VER).tar.gz

$(BUILD_DIR)/src/mni-models_icbm152-lin-$(MNI_MODELS_ICBM_LIN_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/mni-models_icbm152-lin-$(MNI_MODELS_ICBM_LIN_VER).tar.gz \
 -O $(BUILD_DIR)/src/mni-models_icbm152-lin-$(MNI_MODELS_ICBM_LIN_VER).tar.gz

$(BUILD_DIR)/src/mni-models_icbm152-nl-$(MNI_MODELS_ICBM_NL_6GEN_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/mni-models_icbm152-nl-$(MNI_MODELS_ICBM_NL_6GEN_VER).tar.gz \
 -O $(BUILD_DIR)/src/mni-models_icbm152-nl-$(MNI_MODELS_ICBM_NL_6GEN_VER).tar.gz

$(BUILD_DIR)/src/mni-models_icbm152-nl-2009-$(MNI_MODELS_ICBM_NL_40GEN_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/mni-models_icbm152-nl-2009-$(MNI_MODELS_ICBM_NL_40GEN_VER).tar.gz \
 -O $(BUILD_DIR)/src/mni-models_icbm152-nl-2009-$(MNI_MODELS_ICBM_NL_40GEN_VER).tar.gz

$(BUILD_DIR)/src/mni_autoreg_model-$(MNI_AUTOREG_MODEL_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/mni_autoreg_model-$(MNI_AUTOREG_MODEL_VER).tar.gz \
 -O $(BUILD_DIR)/src/mni_autoreg_model-$(MNI_AUTOREG_MODEL_VER).tar.gz


#
# The ones added for the MICe quarantine
#
$(BUILD_DIR)/src/bicInventor-$(BICINVENTOR_VER).tar.gz :
	$(WGET) http://packages.bic.mni.mcgill.ca/tgz/bicInventor-$(BICINVENTOR_VER).tar.gz \
 -O $(BUILD_DIR)/src/bicInventor-$(BICINVENTOR_VER).tar.gz

# $(BUILD_DIR)/src/laplacian_thickness-$(LAPLACIAN_THICKNESS_VER).tar.gz :
# 	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/laplacian_thickness-$(LAPLACIAN_THICKNESS_VER).tar.gz \
#  -O $(BUILD_DIR)/src/laplacian_thickness-$(LAPLACIAN_THICKNESS_VER).tar.gz

$(BUILD_DIR)/src/mincANTS_$(MINCANTS_VER).tar.gz :
	$(WGET) http://www.bic.mni.mcgill.ca/~vfonov/software/mincANTS_$(MINCANTS_VER).tar.gz \
 -O $(BUILD_DIR)/src/mincANTS_$(MINCANTS_VER).tar.gz && \
	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/patch_WarpVTKPolyDataMultiTransform_issue.diff \
 -O $(BUILD_DIR)/src/patch_WarpVTKPolyDataMultiTransform_issue.diff

$(BUILD_DIR)/src/mice-minc-tools-$(MICE_MINC_TOOLS_VER).tar.gz :
	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/mice-minc-tools-$(MICE_MINC_TOOLS_VER).tar.gz \
 -O $(BUILD_DIR)/src/mice-minc-tools-$(MICE_MINC_TOOLS_VER).tar.gz

$(BUILD_DIR)/src/mouse-thickness-$(MOUSE_THICKNESS_VER).tar.gz :
	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/mouse-thickness-$(MOUSE_THICKNESS_VER).tar.gz \
 -O $(BUILD_DIR)/src/mouse-thickness-$(MOUSE_THICKNESS_VER).tar.gz

$(BUILD_DIR)/src/Test-Files-$(PERL_TEST_FILES_VER).tar.gz : 
	$(WGET) http://search.cpan.org/CPAN/authors/id/P/PH/PHILCROW/Test-Files-$(PERL_TEST_FILES_VER).tar.gz \
 -O $(BUILD_DIR)/src/Test-Files-$(PERL_TEST_FILES_VER).tar.gz

# $(BUILD_DIR)/src/PMP-$(PMP_VER).tar.gz : 
# 	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/PMP-$(PMP_VER).tar.gz \
#  -O $(BUILD_DIR)/src/PMP-$(PMP_VER).tar.gz

$(BUILD_DIR)/src/Python-$(PYTHON_VER).tgz : 
	$(WGET) http://www.python.org/ftp/python/$(PYTHON_VER)/Python-$(PYTHON_VER).tgz \
 -O $(BUILD_DIR)/src/Python-$(PYTHON_VER).tgz

$(BUILD_DIR)/src/pyminc-$(PYMINC_VER).tar.gz : 
	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/pyminc-$(PYMINC_VER).tar.gz \
 -O $(BUILD_DIR)/src/pyminc-$(PYMINC_VER).tar.gz

$(BUILD_DIR)/src/numpy-$(NUMPY_VER).tar.gz : 
	$(WGET) http://sourceforge.net/projects/numpy/files/NumPy/$(NUMPY_VER)/numpy-$(NUMPY_VER).tar.gz \
 -O $(BUILD_DIR)/src/numpy-$(NUMPY_VER).tar.gz

$(BUILD_DIR)/src/scipy-$(SCIPY_VER).tar.gz : 
	$(WGET) http://sourceforge.net/projects/scipy/files/scipy/$(SCIPY_VER)/scipy-$(SCIPY_VER).tar.gz \
 -O $(BUILD_DIR)/src/scipy-$(SCIPY_VER).tar.gz

$(BUILD_DIR)/src/R-$(R_VER).tar.gz : 
	$(WGET) http://probability.ca/cran/src/base/R-2/R-$(R_VER).tar.gz \
 -O $(BUILD_DIR)/src/R-$(R_VER).tar.gz

$(BUILD_DIR)/src/xfmavg :
	$(WGET) http://packages.bic.mni.mcgill.ca/scripts/xfmavg \
 -O $(BUILD_DIR)/src/xfmavg

$(BUILD_DIR)/src/RMINC-$(RMINC_VER).tar.gz :
	$(WGET)  --no-check-certificate  https://wiki.phenogenomics.ca/download/attachments/1868718/RMINC_$(RMINC_VER).tar.gz \
 -O $(BUILD_DIR)/src/RMINC-$(RMINC_VER).tar.gz

# $(BUILD_DIR)/src/MBM-$(MBM_VER).tar.gz :
# 	$(WGET) --no-check-certificate  https://wiki.phenogenomics.ca/download/attachments/1868718/MBM-$(MBM_VER).tar.gz \
#  -O $(BUILD_DIR)/src/MBM-$(MBM_VER).tar.gz

$(BUILD_DIR)/src/tagtoxfm_bspline_$(TAGTOXFM_BSPLINE_VER).tar.gz :
	$(WGET) --no-check-certificate  https://wiki.phenogenomics.ca/download/attachments/1868718/tagtoxfm_bspline_$(TAGTOXFM_BSPLINE_VER).tar.gz \
 -O $(BUILD_DIR)/src/tagtoxfm_bspline_$(TAGTOXFM_BSPLINE_VER).tar.gz

$(BUILD_DIR)/src/Coin-$(COIN_3D_VER).tar.gz :
	$(WGET) http://ftp.coin3d.org/coin/src/all/Coin-$(COIN_3D_VER).tar.gz \
 -O $(BUILD_DIR)/src/Coin-$(COIN_3D_VER).tar.gz

$(BUILD_DIR)/src/Quarter-$(QUARTER_VER).tar.gz :
	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/Quarter-$(QUARTER_VER).tar.gz \
 -O $(BUILD_DIR)/src/Quarter-$(QUARTER_VER).tar.gz

$(BUILD_DIR)/src/brain-view2-$(BRAIN_VIEW2_VER).tar.gz :
	$(WGET) --no-check-certificate https://wiki.phenogenomics.ca/download/attachments/1868718/brain-view2-$(BRAIN_VIEW2_VER).tar.gz \
 -O $(BUILD_DIR)/src/brain-view2-$(BRAIN_VIEW2_VER).tar.gz
#
# end of added for MICe
#




# *****************************************************************************
# Targets for configure & compile
# ... the assumption is that source packages have already been downloaded 
#     and unpacked
# *****************************************************************************
#
$(netcdf) : $(BUILD_DIR)/src/netcdf-$(NETCDF_VER)
	cd $(BUILD_DIR)/src/netcdf-$(NETCDF_VER) && \
	./configure --prefix=$(INSTALL_DIR) \
	            --with-pic \
	            --disable-netcdf4 \
	            --disable-hdf4 \
	            --disable-dap \
	            --disable-cxx \
	            --disable-f77 \
	            --disable-f90 \
	            --disable-examples \
	            --enable-v2 \
	            --disable-docs &&\
	make clean && \
	make && \
	make install

$(hdf5) : $(BUILD_DIR)/src/hdf5-$(HDF5_VER)
	cd $(BUILD_DIR)/src/hdf5-$(HDF5_VER) && \
	./configure --prefix=$(INSTALL_DIR) \
	            --with-pic \
	            --enable-cxx \
	            --disable-fortran  \
	            --disable-hl && \
	make clean && \
	make $(PARALLEL_BUILD) && \
	make install && \
	cp $(BUILD_DIR)/src/hdf5-$(HDF5_VER)/c++/src/H5Cpp.h $(INSTALL_DIR)/include/H5Cpp.h

$(fftw) : $(BUILD_DIR)/src/fftw-$(FFTW_VER)
	cd $(BUILD_DIR)/src/fftw-$(FFTW_VER) && \
	./configure --prefix=$(INSTALL_DIR) --enable-float --enable-threads  && \
	make clean  && \
	make $(PARALLEL_BUILD)  && \
	make install 

# ====================================================================================================================
# existence of the package build directory is the dependency ...
# ... if it's not there, then go off and WGET and unzip/untar
$(cmake) : $(BUILD_DIR)/src/cmake-$(CMAKE_VER)
	$(warning In CMAKE recipe ... TGT is $(cmake) ... DEP is $(BUILD_DIR)/src/cmake-$(CMAKE_VER))
	cd $(BUILD_DIR)/src/cmake-$(CMAKE_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean && \
	make && \
	make install && \
	touch $(INSTALL_DIR)/bin/cmake

$(gsl) : $(BUILD_DIR)/src/gsl-$(GSL_VER)
	cd $(BUILD_DIR)/src/gsl-$(GSL_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean && \
	make $(PARALLEL_BUILD) && \
	make install

$(minc) : $(BUILD_DIR)/src/mcvaneede-minc-$(MINC_VER) $(netcdf) $(hdf5)
	cd $(BUILD_DIR)/src/mcvaneede-minc-$(MINC_VER) && \
	./autogen.sh && \
	./configure --prefix=$(INSTALL_DIR) \
	            --with-build-path=$(INSTALL_DIR)  \
	            --with-pic   && make clean  && \
	make $(PARALLEL_BUILD) && \
	make install 

$(ebtks) : $(BUILD_DIR)/src/ebtks-$(EBTKS_VER) $(minc)
	cd $(BUILD_DIR)/src/ebtks-$(EBTKS_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2 && make clean  && \
	make $(PARALLEL_BUILD) && \
	make install

$(netpbm) : $(BUILD_DIR)/src/netpbm-$(NETPBM_VER)
	cd $(BUILD_DIR)/src/netpbm-$(NETPBM_VER)  && \
	wget http://www.bic.mni.mcgill.ca/~vfonov/software/netpbm.config -O Makefile.config && \
	make clean && \
	make && \
	rm -rf $(BUILD_DIR)/src/netpbm-$(NETPBM_VER)/pkg && \
	make package pkgdir=$(BUILD_DIR)/src/netpbm-$(NETPBM_VER)/pkg 
	cp $(BUILD_DIR)/src/netpbm-$(NETPBM_VER)/pkg/link/libnetpbm.a $(INSTALL_DIR)/lib 
	cp $(BUILD_DIR)/src/netpbm-$(NETPBM_VER)/pkg/include/*.h $(INSTALL_DIR)/include

$(bicpl) : $(BUILD_DIR)/src/bicpl-$(BICPL_VER) $(netpbm) $(minc) 
	cd $(BUILD_DIR)/src/bicpl-$(BICPL_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 --with-image-netpbm  && \
	make clean   && \
	make $(PARALLEL_BUILD) && make install

$(oobicpl) : $(BUILD_DIR)/src/oobicpl-$(OOBICPL_VER) $(bicpl) $(arguments) $(pcre) $(pcrepp)
	cd $(BUILD_DIR)/src/oobicpl-$(OOBICPL_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 --with-image-netpbm  && \
	make clean   && \
	make $(PARALLEL_BUILD) && \
	make install

$(n3) : $(BUILD_DIR)/src/N3-$(N3_VER) $(ebtks) $(minc) 
	cd $(BUILD_DIR)/src/N3-$(N3_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2 && make clean  && \
	make $(PARALLEL_BUILD) && \
	make install

$(conglomerate) : $(BUILD_DIR)/src/conglomerate-$(CONGLOMERATE_VER) 
	cd $(BUILD_DIR)/src/conglomerate-$(CONGLOMERATE_VER)  && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2  && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install

$(glim_image) : $(BUILD_DIR)/src/glim_image-$(GLIMIMAGE_VER) $(minc)
	cd $(BUILD_DIR)/src/glim_image-$(GLIMIMAGE_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2 && \
	make clean  && \
	make $(PARALLEL_BUILD) && \
	make install 

$(mni_autoreg) : $(BUILD_DIR)/src/mni_autoreg-$(MNI_AUTOREG_VER) $(minc)
	cd $(BUILD_DIR)/src/mni_autoreg-$(MNI_AUTOREG_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 && \
	make clean  && \
	make $(PARALLEL_BUILD) && \
	make install


$(mni_perllib) : $(BUILD_DIR)/src/mni_perllib-$(MNI_PERLLIB_VER) 
	$(warning In perllib recipe ...)
	ls -l
	cd $(BUILD_DIR)/src/mni_perllib-$(MNI_PERLLIB_VER) && \
	echo -e $(INSTALL_DIR) \\n\\n\\n > dummy_response_file && \
	echo perl ./Makefile.PL SITEPREFIX=$(INSTALL_DIR) \
	                   INSTALLDIRS=site \
	                   INSTALLSITELIB=$(INSTALL_DIR)/perl \
	                   INSTALLSITEBIN=$(INSTALL_DIR)/bin \
	                   INSTALLSITEARCH=$(INSTALL_DIR)/perl \
	                   INSTALLSITESCRIPT=$(INSTALL_DIR)/bin \
	                   INSTALLSITEMAN1DIR=$(INSTALL_DIR)/share/man/man1 \
	                   INSTALLSITEMAN3DIR=$(INSTALL_DIR)/share/man/man3 < dummy_response_file  && \
	perl ./Makefile.PL SITEPREFIX=$(INSTALL_DIR) \
	                   INSTALLDIRS=site \
	                   INSTALLSITELIB=$(INSTALL_DIR)/perl \
	                   INSTALLSITEBIN=$(INSTALL_DIR)/bin \
	                   INSTALLSITEARCH=$(INSTALL_DIR)/perl \
	                   INSTALLSITESCRIPT=$(INSTALL_DIR)/bin \
	                   INSTALLSITEMAN1DIR=$(INSTALL_DIR)/share/man/man1 \
	                   INSTALLSITEMAN3DIR=$(INSTALL_DIR)/share/man/man3 < dummy_response_file  && \
	make && \
	make install && \
	touch $(mni_perllib)

$(getopt_tabular) : $(BUILD_DIR)/src/Getopt-Tabular-$(GETOPT_TABULAR_VER)
	cd $(BUILD_DIR)/src/Getopt-Tabular-$(GETOPT_TABULAR_VER) && \
	perl ./Makefile.PL SITEPREFIX=$(INSTALL_DIR) \
	        INSTALLDIRS=site \
	        INSTALLSITELIB=$(INSTALL_DIR)/perl \
	        INSTALLSITEBIN=$(INSTALL_DIR)/bin \
	        INSTALLSITEARCH=$(INSTALL_DIR)/perl \
	        INSTALLSITESCRIPT=$(INSTALL_DIR)/bin \
		INSTALLSITEMAN1DIR=$(INSTALL_DIR) INSTALLSITEMAN3DIR=$(INSTALL_DIR) && \
	make && \
	make install
	touch $(getopt_tabular)

$(mincblob) : $(BUILD_DIR)/src/mincblob-$(MINCBLOB_VER) $(minc)
	cd $(BUILD_DIR)/src/mincblob-$(MINCBLOB_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2 && \
	make clean  && \
	make $(PARALLEL_BUILD)  && \
	make install

$(mincmorph) : $(BUILD_DIR)/src/mincmorph-$(MINCMORPH_VER) $(minc)
	cd $(BUILD_DIR)/src/mincmorph-$(MINCMORPH_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2  && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install

$(ray_trace) : $(BUILD_DIR)/src/ray_trace-$(RAYTRACE_VER) $(minc)
	cd $(BUILD_DIR)/src/ray_trace-$(RAYTRACE_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2  && \
	make clean  && \
	make $(PARALLEL_BUILD)  && \
	make install

$(classify) : $(BUILD_DIR)/src/classify-$(CLASSIFY_VER) minc
	cd $(BUILD_DIR)/src/classify-$(CLASSIFY_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2  && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install

$(register) : $(BUILD_DIR)/src/Register-$(REGISTER_VER) $(bicpl)
	cd $(BUILD_DIR)/src/Register-1.4.0 && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2 --with-x && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 

# build Display: add the LIBS argument so that we link against the netpbm lib (built earlier)
$(Display) :$(BUILD_DIR)/src/Display-$(DISPLAY_VER) $(bicpl)
	cd $(BUILD_DIR)/src/Display-1.5.0 && \
	aclocal -I m4 && \
	autoheader && \
	libtoolize --automake && \
	automake --add-missing --copy && \
	autoconf && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2 --with-x LDFLAGS="-L$(INSTALL_DIR)/lib" LIBS="-lnetpbm" && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 

$(postf) : $(BUILD_DIR)/src/postf-$(POSTF_VER) $(bicpl)
	cd $(BUILD_DIR)/src/postf-$(POSTF_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2 --with-x && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 

$(inormalize) : $(BUILD_DIR)/src/inormalize-$(INORMALIZE_VER) $(ebtks)
	cd $(BUILD_DIR)/src/inormalize-$(INORMALIZE_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR)  --with-minc2 && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 


$(arguments) : $(BUILD_DIR)/src/arguments-$(ARGUMENTS_VER)
	cd $(BUILD_DIR)/src/arguments-$(ARGUMENTS_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --disable-dependency-tracking && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 


$(pcre) : $(BUILD_DIR)/src/pcre-$(PCRE_VER)
	cd $(BUILD_DIR)/src/pcre-$(PCRE_VER) && \
	./configure --prefix=$(INSTALL_DIR) --disable-dependency-tracking && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 


$(pcrepp) : $(BUILD_DIR)/src//pcre++-$(PCREPP_VER)
	cd $(BUILD_DIR)/src//pcre++-$(PCREPP_VER) && \
	./configure --prefix=$(INSTALL_DIR) --disable-dependency-tracking --with-pcre-lib=$(INSTALL_DIR)/lib --with-pcre-include=$(INSTALL_DIR)/include && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 


#
# The ones added for the MICe quarantine
#

$(bicinventor) : $(BUILD_DIR)/src/bicInventor-$(BICINVENTOR_VER)
	cd $(BUILD_DIR)/src/bicInventor-$(BICINVENTOR_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 

$(laplacian_thickness) : $(BUILD_DIR)/src/laplacian_thickness-$(LAPLACIAN_THICKNESS_VER)
	cd $(BUILD_DIR)/src/laplacian_thickness-$(LAPLACIAN_THICKNESS_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 

$(mice_minc_tools) : $(BUILD_DIR)/src/mice-minc-tools-$(MICE_MINC_TOOLS_VER)
	cd $(BUILD_DIR)/src/mice-minc-tools-$(MICE_MINC_TOOLS_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 

$(mouse_thickness) : $(BUILD_DIR)/src/mouse-thickness-$(MOUSE_THICKNESS_VER)
	cd $(BUILD_DIR)/src/mouse-thickness-$(MOUSE_THICKNESS_VER) && \
	./autogen.sh && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 

$(perl_test_files) : $(BUILD_DIR)/src/Test-Files-$(PERL_TEST_FILES_VER)
	cd $(BUILD_DIR)/src/Test-Files-$(PERL_TEST_FILES_VER) && \
	perl ./Makefile.PL SITEPREFIX=$(INSTALL_DIR) \
	        INSTALLDIRS=site \
	        INSTALLSITELIB=$(INSTALL_DIR)/perl \
	        INSTALLSITEBIN=$(INSTALL_DIR)/bin \
	        INSTALLSITEARCH=$(INSTALL_DIR)/perl \
	        INSTALLSITESCRIPT=$(INSTALL_DIR)/bin \
		INSTALLSITEMAN1DIR=$(INSTALL_DIR) \
		INSTALLSITEMAN3DIR=$(INSTALL_DIR) && \
	make && \
	make install

$(pmp) : $(BUILD_DIR)/src/PMP-$(PMP_VER)
	cd $(BUILD_DIR)/src/PMP-$(PMP_VER) && \
	perl ./Makefile.PL SITEPREFIX=$(INSTALL_DIR) \
	        INSTALLDIRS=site \
	        INSTALLSITELIB=$(INSTALL_DIR)/perl \
	        INSTALLSITEBIN=$(INSTALL_DIR)/bin \
	        INSTALLSITEARCH=$(INSTALL_DIR)/perl \
	        INSTALLSITESCRIPT=$(INSTALL_DIR)/bin \
		INSTALLSITEMAN1DIR=$(INSTALL_DIR) \
		INSTALLSITEMAN3DIR=$(INSTALL_DIR) && \
	make && \
	make install

$(python) : $(BUILD_DIR)/src/Python-$(PYTHON_VER)
	cd $(BUILD_DIR)/src/Python-$(PYTHON_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install
	touch $(python)

$(pyminc) : $(BUILD_DIR)/src/pyminc-$(PYMINC_VER)
	cd $(BUILD_DIR)/src/pyminc-$(PYMINC_VER) && \
	$(INSTALL_DIR)/bin/python setup.py install \
	--prefix=$(INSTALL_DIR) --install-lib=$(INSTALL_DIR)/python 

$(numpy) : $(BUILD_DIR)/src/numpy-$(NUMPY_VER)
	cd $(BUILD_DIR)/src/numpy-$(NUMPY_VER) && \
	$(INSTALL_DIR)/bin/python setup.py build --fcompiler=gnu95 && \
	$(INSTALL_DIR)/bin/python setup.py install \
	--prefix=$(INSTALL_DIR) --install-lib=$(INSTALL_DIR)/python 

$(scipy) : $(BUILD_DIR)/src/scipy-$(SCIPY_VER)
	cd $(BUILD_DIR)/src/scipy-$(SCIPY_VER) && \
	export PYTHONPATH=$(INSTALL_DIR)/python && \
	$(INSTALL_DIR)/bin/python setup.py install \
	--prefix=$(INSTALL_DIR) --install-lib=$(INSTALL_DIR)/python && \
	unset PYTHONPATH

$(R) : $(BUILD_DIR)/src/R-$(R_VER)
	cd $(BUILD_DIR)/src/R-$(R_VER) && \
	./configure --prefix=$(INSTALL_DIR) --libdir=$(INSTALL_DIR)/lib/ && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install

$(xfmavg) : $(BUILD_DIR)/src/xfmavg
	cp $(BUILD_DIR)/src/xfmavg $(INSTALL_DIR)/bin/xfmavg && \
	chmod a+x $(INSTALL_DIR)/bin/xfmavg

# $(RMINC) : $(BUILD_DIR)/src/RMINC-$(RMINC_VER).tar.gz
# 	cd $(BUILD_DIR)/src/ && \
# 	export LD_LIBRARY_PATH=$(INSTALL_DIR)/lib && \
# 	$(INSTALL_DIR)/bin/R CMD INSTALL RMINC-$(RMINC_VER).tar.gz \
# 	--configure-args="--with-build-path=$(INSTALL_DIR)" && \
# 	unset LD_LIBRARY_PATH

$(RMINC) : 
	cd $(BUILD_DIR)/src/ && \
	if [ ! -d rminc ]; then bzr branch lp:rminc/trunk rminc; else echo rminc directory exists already; fi && \
	cd rminc; ./autogen.sh; cd .. && \
	export LD_LIBRARY_PATH=$(INSTALL_DIR)/lib && \
	$(INSTALL_DIR)/bin/R CMD INSTALL rminc \
	--configure-args="--with-build-path=$(INSTALL_DIR)" && \
	unset LD_LIBRARY_PATH


$(MBM) : $(BUILD_DIR)/src/MBM-$(MBM_VER)
	cd $(BUILD_DIR)/src/MBM-$(MBM_VER) && \
	./autogen.sh && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install && \
	cd perllib && \
	perl ./Makefile.PL SITEPREFIX=$(INSTALL_DIR) \
	        INSTALLDIRS=site \
	        INSTALLSITELIB=$(INSTALL_DIR)/perl \
	        INSTALLSITEBIN=$(INSTALL_DIR)/bin \
	        INSTALLSITEARCH=$(INSTALL_DIR)/perl \
	        INSTALLSITESCRIPT=$(INSTALL_DIR)/bin \
		INSTALLSITEMAN1DIR=$(INSTALL_DIR) \
		INSTALLSITEMAN3DIR=$(INSTALL_DIR) && \
	make && \
	make install

$(tagtoxfm_bspline) : $(BUILD_DIR)/src/tagtoxfm_bspline_$(TAGTOXFM_BSPLINE_VER)
	cd $(BUILD_DIR)/src/tagtoxfm_bspline_$(TAGTOXFM_BSPLINE_VER) && \
	./autogen.sh && \
	./configure --prefix=$(INSTALL_DIR) --with-build-path=$(INSTALL_DIR) --with-minc2 && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install

$(coin3d) : $(BUILD_DIR)/src/Coin-$(COIN_3D_VER)
	cd $(BUILD_DIR)/src/Coin-$(COIN_3D_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install

$(quarter) : $(BUILD_DIR)/src/Quarter-$(QUARTER_VER)
	cd $(BUILD_DIR)/src/Quarter-$(QUARTER_VER) && \
	./configure --prefix=$(INSTALL_DIR) --with-coin=$(INSTALL_DIR) --with-qt-designer-plugin-path=$(INSTALL_DIR)/lib/designer && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install

$(brain_view2) : $(BUILD_DIR)/src/brain-view2-$(BRAIN_VIEW2_VER)
	cd $(BUILD_DIR)/src/brain-view2-$(BRAIN_VIEW2_VER) && \
	qmake-qt4 brain-view2.pro MINCDIR=$(INSTALL_DIR) QUARTERDIR=$(INSTALL_DIR) LIBS=-L$(INSTALL_DIR)/lib INCLUDEPATH=$(INSTALL_DIR)/include && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	cp brain-view2 $(INSTALL_DIR)/bin/brain-view2
#
# end of added for MICe
#





# build the MODELS
# ====================================================================================================================
# existence of the package build directory is the dependency ...
# ... if it's not there, then go off and WGET and unzip/untar
$(mni-models_average305-lin) : $(BUILD_DIR)/src/mni-models_average305-lin-$(MNI_MODELS_AVERAGE305_LIN_VER)
	$(warning In recipe for target $(mni-models_average305-lin) ...) 
	cd $(BUILD_DIR)/src/mni-models_average305-lin-$(MNI_MODELS_AVERAGE305_LIN_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 
	touch $@

$(mni-models_colin27-lin) :$(BUILD_DIR)/src/mni-models_colin27-lin-$(MNI_MODELS_COLIN27_LIN_VER)
	$(warning In recipe for target $(mni-models_colin27-lin) ...) 
	cd $(BUILD_DIR)/src/mni-models_colin27-lin-$(MNI_MODELS_COLIN27_LIN_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 
	touch $@

$(mni-models_icbm152-lin) :$(BUILD_DIR)/src/mni-models_icbm152-lin-$(MNI_MODELS_ICBM_LIN_VER)
	$(warning In recipe for target $(mni-models_icbm152-lin) ...) 
	cd $(BUILD_DIR)/src/mni-models_icbm152-lin-$(MNI_MODELS_ICBM_LIN_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 
	touch $@

$(mni-models_icbm152-nl-6gen) :$(BUILD_DIR)/src/mni-models_icbm152-nl-$(MNI_MODELS_ICBM_NL_6GEN_VER)
	$(warning In recipe for target $(mni-models_icbm152-nl-6gen) ...) 
	cd $(BUILD_DIR)/src/mni-models_icbm152-nl-$(MNI_MODELS_ICBM_NL_6GEN_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 
	touch $@

$(mni-models_icbm152-nl-40gen) :$(BUILD_DIR)/src/mni-models_icbm152-nl-2009-$(MNI_MODELS_ICBM_NL_40GEN_VER)
	$(warning In recipe for target $(mni-models_icbm152-nl-40gen) ...) 
	cd $(BUILD_DIR)/src/mni-models_icbm152-nl-2009-$(MNI_MODELS_ICBM_NL_40GEN_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 
	touch $@

$(mni_autoreg_model) :$(BUILD_DIR)/src/mni_autoreg_model-$(MNI_AUTOREG_MODEL_VER)
	cd $(BUILD_DIR)/src/mni_autoreg_model-$(MNI_AUTOREG_MODEL_VER) && \
	./configure --prefix=$(INSTALL_DIR) && \
	make clean   && \
	make $(PARALLEL_BUILD)  && \
	make install 
	touch $@


$(itk) : $(BUILD_DIR)/src/InsightToolkit-$(ITK_VER) $(cmake)
	cd  $(BUILD_DIR)/src && \
	mkdir -p build_itk && \
	cd build_itk && \
	$(CMAKE) \
			-D BUILD_EXAMPLES:BOOL=OFF \
			-D BUILD_SHARED_LIBS:BOOL=ON \
			-D BUILD_TESTING:BOOL=OFF \
			-D CMAKE_BUILD_TYPE:STRING=Release \
			-D CMAKE_INSTALL_PREFIX:PATH=$(INSTALL_DIR) \
			-D ITK_USE_REVIEW:BOOL=ON \
				$(BUILD_DIR)/src/InsightToolkit-3.20.0  && \
	make $(PARALLEL_BUILD) && \
	make install && \
	touch $(INSTALL_DIR)/lib/InsightToolkit/UseITK.cmake

$(fltk) : $(BUILD_DIR)/src/fltk-$(FLTK_VER) $(cmake)
	cd $(BUILD_DIR)/src/fltk-$(FLTK_VER) && \
	mkdir -p build_fltk && \
	cd build_fltk && \
	$(CMAKE) \
	-D BUILD_EXAMPLES:BOOL=OFF \
	-D BUILD_SHARED_LIBS:BOOL=ON \
	-D BUILD_TESTING:BOOL=OFF \
	-D CMAKE_BUILD_TYPE:STRING=Release \
	-D CMAKE_INSTALL_PREFIX:PATH=$(INSTALL_DIR) \
	-D CMAKE_USE_PTHREADS:BOOL=1 \
	-D OPTION_USE_SYSTEM_LIBJPEG:BOOL=OFF \
	-D OPTION_USE_SYSTEM_LIBPNG:BOOL=OFF \
	-D OPTION_USE_SYSTEM_ZLIB:BOOL=OFF \
	-D USE_OPENGL:BOOL=ON \
	$(BUILD_DIR)/src/fltk-1.3.x-r7725 && \
	make $(PARALLEL_BUILD) && \
	make install && \
	touch $(fltk)
	

$(vtk) : $(BUILD_DIR)/src/VTK
	cd $(BUILD_DIR)/src/VTK && \
	mkdir -p build_vtk && \
	cd build_vtk && \
	$(CMAKE) \
	-D BUILD_EXAMPLES:BOOL=OFF \
	-D BUILD_SHARED_LIBS:BOOL=ON \
	-D BUILD_TESTING:BOOL=OFF \
	-D CMAKE_BUILD_TYPE:STRING=Release \
	-D CMAKE_INSTALL_PREFIX:PATH=$(INSTALL_DIR) \
	$(BUILD_DIR)/src/VTK && \
	make $(PARALLEL_BUILD) && make install && \
	touch $(vtk)

$(ezminc) : $(BUILD_DIR)/src/vfonov-EZminc-$(EZMINC_VER) $(minc) $(itk) $(cmake) $(fftw) $(gsl)
	cd $(BUILD_DIR)/src && \
	rm -rf   build_ezminc && \
	mkdir -p build_ezminc && \
	cd build_ezminc && \
	$(CMAKE)  \
      -D BUILD_EXAMPLES:BOOL=ON \
      -D BUILD_TESTS:BOOL=ON \
      -D CMAKE_BUILD_TYPE:STRING=Release \
      -D CMAKE_INSTALL_PREFIX:PATH=$(INSTALL_DIR) \
      -D ITK_DIR:PATH=$(INSTALL_DIR)/lib/InsightToolkit \
      -D MINC_ROOT:PATH=$(INSTALL_DIR) \
      -D USE_MINC2:BOOL=ON \
      -D FFTW3_ROOT:PATH=$(INSTALL_DIR) \
      -D HAVE_GSL:BOOL=ON \
      -D HAVE_FFTW3:BOOL=ON \
      -D GSL_ROOT:PATH=$(INSTALL_DIR) \
      -D BUILD_DISTORTION_CORRECTION:BOOL=ON \
      -D BUILD_MINCNLM:BOOL=ON \
      -D BUILD_TOOLS:BOOL=ON \
      $(BUILD_DIR)/src/vfonov-EZminc-$(EZMINC_VER) && \
	make $(PARALLEL_BUILD) && \
	make install && \
	touch $(ezminc)

#
# The ones added for the MICe quarantine
#

$(mincANTS) : $(BUILD_DIR)/src/mincANTS_$(MINCANTS_VER) $(minc) $(itk) $(cmake) $(ezminc)
	cd $(BUILD_DIR)/src/ && \
	cp $(BUILD_DIR)/src/patch_WarpVTKPolyDataMultiTransform_issue.diff $(BUILD_DIR)/src/mincANTS_$(MINCANTS_VER_SHORT)/Examples && \
	cd $(BUILD_DIR)/src/mincANTS_$(MINCANTS_VER_SHORT)/Examples && \
	patch < patch_WarpVTKPolyDataMultiTransform_issue.diff && \
	$(CMAKE)  \
      -D BUILD_TESTING:BOOL=ON \
      -D CMAKE_BUILD_TYPE:STRING=Release \
      -D CMAKE_INSTALL_PREFIX:PATH=$(INSTALL_DIR) \
      -D EZMINC_ROOT:PATH=$(INSTALL_DIR) \
      -D ITK_DIR:PATH=$(BUILD_DIR)/src/build_itk \
      -D USE_MINC2:BOOL=ON \
      -D USE_EZMINC:BOOL=ON\
      -D USE_ITK:BOOL=ON \
      $(BUILD_DIR)/src/mincANTS_$(MINCANTS_VER_SHORT)/Examples && \
	make $(PARALLEL_BUILD) && \
	make install && \
	touch $(mincANTS)
	
#
# end of added for MICe
#

# ensure that the output directories (build and install) exist
${output_dirs} : create_output_dirs 
  
create_output_dirs : 
	mkdir -p $(BUILD_DIR)/src
	mkdir -p $(INSTALL_DIR)/bin
	mkdir -p $(INSTALL_DIR)/lib
	mkdir -p $(INSTALL_DIR)/include
	mkdir -p $(INSTALL_DIR)/share/mni-models
	mkdir -p $(INSTALL_DIR)/share/mni_autoreg
	mkdir -p $(INSTALL_DIR)/share/man/man1
	mkdir -p $(INSTALL_DIR)/share/man/man3

# build the visual packages 
visual :  $(output_dirs) register Display


# permit 'make list'
# ... lists all of the package names buildable by this Makefile
list : 
	@echo $(subst $(BUILD_DIR)/src/,,$(source_dirs)) fltk-$(FLTK_VER) vtk-$(VTK_VER)


# append the install dir to the PATH and PERL5LIB env variables
# ... does anyone actually call this target?
environment : $(INSTALL_DIR)/environment.sh $(INSTALL_DIR)/environment.csh

$(INSTALL_DIR)/environment.sh : 
	echo export PATH=$(INSTALL_DIR)/bin:/usr/sbin:/usr/bsd:/sbin:/usr/bin:/usr/bin/X11:/usr/freeware/bin:/usr/etc:/usr/local/bin:/usr/pbs/bin:/bin \\nexport PERL5LIB=$(INSTALL_DIR)/perl \\nexport PYTHONPATH=$(INSTALL_DIR)/python/ \\nexport LD_LIBRARY_PATH=$(INSTALL_DIR)/lib:$(INSTALL_DIR)/lib/InsightToolkit/ \\n. /sge/default/common/settings.sh >$(INSTALL_DIR)/environment.sh

$(INSTALL_DIR)/environment.csh : 
	echo setenv PATH $(INSTALL_DIR)/bin:/usr/sbin:/usr/bsd:/sbin:/usr/bin:/usr/bin/X11:/usr/freeware/bin:/usr/etc:/usr/local/bin:/usr/pbs/bin:/bin \\nsetenv PERL5LIB $(INSTALL_DIR)/perl \\nsetenv PYTHONPATH $(INSTALL_DIR)/python/ \\nsetenv LD_LIBRARY_PATH $(INSTALL_DIR)/lib:$(INSTALL_DIR)/lib/InsightToolkit/ \\n. /sge/default/common/settings.csh >$(INSTALL_DIR)/environment.csh


# *****************************************************************************
# Custom functions
# *****************************************************************************

#define print_header
#	echo ***************************************************************
#	echo *
#	echo *    Building ... $1
#	echo *
#	echo *
#	echo *
#	echo ***************************************************************
#endef
