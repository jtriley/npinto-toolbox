#!/bin/bash

red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m' # No Color

# ------------------------------------------------------------------------------
# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# ------------------------------------------------------------------------------
echo -e "[ ${RED} Initialization ${NC} ]"
if test -z ${TMP_DIR}; 
then TMP_DIR=$(mktemp -d); 
else mkdir -p ${TMP_DIR};
fi;
echo Using TMP_DIR=${TMP_DIR}

# ------------------------------------------------------------------------------
echo -e "[ ${RED} Install dependencies ${NC} ]"
apt-get install -y build-essential gfortran python-dev

# ------------------------------------------------------------------------------
NUMPY=numpy-1.3.0
echo -e "[ ${RED} Download ${NUMPY} ${NC} ]"
cd ${TMP_DIR}
test ! -f ${NUMPY}.tar.gz && \
    wget http://downloads.sourceforge.net/sourceforge/numpy/${NUMPY}.tar.gz
tar xzf ${NUMPY}.tar.gz

echo -e "[ ${RED} Configure ${NUMPY} ${NC} ]"
cd ${NUMPY}
cp -vf site.cfg.example site.cfg

cat << EOF >> site.cfg
[DEFAULT]
library_dirs = /usr/lib
include_dirs = /usr/include

[blas_opt]
libraries = ptf77blas, ptcblas, atlas

[lapack_opt]
libraries = lapack, ptf77blas, ptcblas, atlas

[amd]
amd_libs = amd

[umfpack]
umfpack_libs = umfpack, gfortran

[fftw]
libraries = fftw3
EOF

echo -e "[ ${RED} Inspect config for errors ]"
python setup.py config
echo "Sleeping 10 secs for inspection..."
sleep 10

echo -e "[ ${RED} Build ${NUMPY} ${NC} ]"
python setup.py build

echo -e "[ ${RED} Remove previous installation ${NC} ]"
export PREVIOUS_INSTALL=$(cd $HOME && \
    python -c "import numpy; print numpy.__path__[0]" 2> /dev/null)
if [ $PREVIOUS_INSTALL ]; 
then echo "Uninstalling $PREVIOUS_INSTALL"; 
rm -rf $PREVIOUS_INSTALL;
fi;

echo -e "[ ${RED} Install ${NUMPY} ${NC} ]"
python setup.py install

# XXX: need (many) more tests here
echo -e "[ ${RED} Test ${NUMPY} (lapack problem) ${NC} ]"
(cd $HOME && python -c "from numpy.linalg import lapack_lite") || exit 1

echo -e "[ ${RED} Test ${NUMPY} (version and blas support) ${NC} ]"
VERSION=$(cd $HOME && python -c "import numpy; print numpy.__version__")
DOTBLAS=$(cd $HOME && python -c "import numpy; print numpy.dot.__module__")

echo "VERSION=$VERSION"
echo "DOTBLAS=$DOTBLAS"

if [[ $VERSION != "1.3.0" || $DOTBLAS != "numpy.core._dotblas" ]] ; 
then echo "ERROR! see $TMP_DIR"; exit 1; 
fi;

echo -e "[ ${RED} Running numpy.test(verbose=10) for ${NUMPY} () ${NC} ]"
(cd $HOME && python -c "import numpy; numpy.test(verbose=10)") || exit 1

echo -e "${NUMPY} has been successfuly installed!"

echo -e "You may want to clean up ${TMP_DIR}/${NUMPY}"
#rm -rf ${TMP_DIR}/${NUMPY}

