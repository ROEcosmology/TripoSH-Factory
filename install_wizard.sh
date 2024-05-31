#!/bin/bash
#
# @file install_wizard.sh
# @author Mike S Wang
# @brief Installation wizard for TripoSH bispectrum modelling
#        and fitting packages.
#

echo "Installation wizard: TripoSH bispectrum modelling and fitting packages"


# ========================================================================
# Preamble
# ========================================================================

# @brief Filter prompt yes-or-no answer to 'y' or 'n'.
#
function filter_ans () {
    local ans="$1"
    echo $(echo "$ans" | tr '[:upper:]' '[:lower:]')
}


# ========================================================================
# Environment
# ========================================================================

# ------------------------------------------------------------------------
# OS
# ------------------------------------------------------------------------

OS=$(uname -s)

# Set environment variables.
if [[ ${OS} = 'Darwin' ]]; then
    export MACOSX_DEPLOYMENT_TARGET=11.0
fi


# ------------------------------------------------------------------------
# Conda
# ------------------------------------------------------------------------

read -p "==> Create a new Conda environment? (yes/[no]) " ans_newenv
ans_newenv=$(filter_ans "$ans_newenv")
if [[ "$ans_newenv" = 'y' ]]; then
    # Ask for the environment name.
    read -p "====> Enter the name of the new environment: " env_name
    if [[ -z "$env_name" ]]; then
        echo "Warning: Empty environment name is reset to 'triposh' by default."
        env_name='triposh'
    fi

    # Detect existing environment.
    flag_createnv=false
    if conda env list | grep -q "^${env_name}\s"; then
        echo "Warning: Conda environment '$env_name' already exists."
        read -p "====> Remove existing Conda environment? (yes/[no]) " ans_rmenv
        ans_rmenv=$(filter_ans "$ans_rmenv")
        if [[ "$ans_rmenv" = 'y' ]]; then
            # Remove existing environment.
            echo "Removing Conda environment: '$env_name'"
            conda env remove --name "$env_name" -y
            if [[ $? -eq 0 ]]; then
                echo "Removed Conda environment: '$env_name'"
            else
                echo "Error: Failed to remove Conda environment: '$env_name'"
                exit 1
            fi
            flag_createnv=true
        else
            read -p "====> Activate existing Conda environment? (yes/[no]) " ans_actenv
            # Designate existing environment to be activated.
            ans_actenv=$(filter_ans "$ans_actenv")
            if [[ "$ans_actenv" != 'y' ]]; then
                echo "Attention: Installation aborted."
                exit 0
            fi
        fi
    else
        flag_createnv=true
    fi

    # Create new Conda environment.
    if [[ "$flag_createnv" = true ]]; then
        echo "Creating new Conda environment: '$env_name'"
        conda create --name "$env_name" -y
        if [[ $? -eq 0 ]]; then
            echo "Error: Failed to create Conda environment: '$env_name'"
            exit 1
        else
            echo "Created Conda environment: '$env_name'"
        fi
    fi

    # Activate the new environment.
    echo "Activating Conda environment: '$env_name'"
    source $(conda info --base)/etc/profile.d/conda.sh
    conda activate "$env_name"
    if [[ ${CONDA_DEFAULT_ENV} != "$env_name" ]]; then
        echo "Error: Failed to activate Conda environment: '$env_name'."
        exit 1
    fi
fi

echo "Activated Conda environment: '${CONDA_DEFAULT_ENV}'"


# ========================================================================
# Dependencies
# ========================================================================

# ------------------------------------------------------------------------
# Build tools
# ------------------------------------------------------------------------

# Install compiler suite.
read -p "==> Install Conda compiler suite? (yes/[no]) " ans_compiler
ans_compiler=$(filter_ans "$ans_compiler")
if [[ "$ans_compiler" = 'y' ]]; then
    echo "Installing Conda compiler suite."
    conda install cxx-compiler c-compiler -y
    if [[ $? -eq 0 ]]; then
        echo "Installed Conda compiler suite."
    else
        echo "Warning: Failed to install Conda compiler suite."
    fi
fi

if [[ -z "$CC" ]]; then
    read -p "====> Enter the C compiler (as none is set): " CC
fi
if [[ -z "$CXX" ]]; then
    read -p "====> Enter the C++ compiler (as none is set): " CXX
fi

# Install OpenMP library.
read -p "==> Install OpenMP library? (yes/[no]) " ans_openmp
ans_openmp=$(filter_ans "$ans_openmp")
if [[ "$ans_openmp" = 'y' ]]; then
    echo "Installing OpenMP library."
    conda install libgomp -y
    if [[ $? -eq 0 ]]; then
        echo "Installed OpenMP library."
    else
        echo "Warning: Failed to install OpenMP library."
    fi
fi

# Install core packages.
read -p "==> Install core packages including Python and Pip? (yes/[no]) " ans_core
ans_core=$(filter_ans "$ans_core")
if [[ "$ans_core" = 'y' ]]; then
    echo "Installing core packages."
    conda install python pip -y
    if [[ $? -eq 0 ]]; then
        echo "Installed core packages."
    else
        echo "Warning: Failed to install core packages."
    fi
fi


# ------------------------------------------------------------------------
# CLASS-PT
# ------------------------------------------------------------------------

read -p "==> Install CLASS-PT? (yes/[no]) " ans_classpt
ans_classpt=$(filter_ans "$ans_classpt")
if [[ "$ans_classpt" = 'y' ]]; then
    # Install OpenBLAS library
    read -p "====> Install OpenBLAS library as a CLASS-PT dependency? (yes/[no]) " ans_openblas
    ans_openblas=$(filter_ans "$ans_openblas")
    if [[ "$ans_openblas" = 'y' ]]; then
        echo "Installing OpenBLAS library."
        conda install openblas -y
        if [[ $? -eq 0 ]]; then
            echo "Installed OpenBLAS library."
        else
            echo "Warning: Failed to install OpenBLAS library."
        fi
    fi

    CONDA_INCLUDE=${CONDA_PREFIX}/include
    CONDA_LIB=${CONDA_PREFIX}/lib

    # Install CLASS-PT
    echo "Installing CLASS-PT."

    if [[ -d "./CLASS-PT" ]]; then
        read -p "====> Remove existing CLASS-PT directory? (yes/[no]) " ans_rmclasspt
        ans_rmclasspt=$(filter_ans "$ans_rmclasspt")
        if [[ "$ans_rmclasspt" = 'y' ]]; then
            rm -rf ./CLASS-PT
        fi
    fi
    git clone https://github.com/Michalychforever/CLASS-PT.git
    cd ./CLASS-PT
    git restore .

    cp ../pyproject-classy.toml . && mv ./pyproject-classy.toml ./python/pyproject.toml

    if [[ "$OS" = 'Darwin' ]]; then
        LDFLAG_OMP='-lomp'
    else
        LDFLAG_OMP='-lgomp'
    fi

    sed -i "s|CCFLAG.*=.*-g -fPIC -ggdb3|CCFLAG=-g -fPIC -ggdb3 -I${CONDA_INCLUDE}|g" Makefile
    sed -i "s|LDFLAG.*=.*-g -fPIC|LDFLAG=-g -fPIC -L${CONDA_LIB} -lopenblas ${LDFLAG_OMP}|g" Makefile
    sed -i "s|OMPFLAG.*=.*-fopenmp|OMPFLAG=-Xpreprocessor -fopenmp|g" Makefile
    sed -i "s|OPENBLAS.* =.*|OPENBLAS=|g" Makefile

    sed -i "s|cp python/setup.py python/autosetup.py||g" Makefile
    sed -i "s|grep -v \"lgomp\" python/setup.py > python/autosetup.py||g" Makefile
    sed -i "s|autosetup.py install|-m pip install -vvv -e .|g" Makefile
    sed -i "s|rm python/autosetup.py||g" Makefile

    sed -i "s|/Users/gcabass/anaconda3/envs/openblas_test/include|${CONDA_INCLUDE}|g" python/setup.py
    sed -i "s|/Users/gcabass/anaconda3/envs/openblas_test/lib/libopenblas.dylib|-L${CONDA_LIB}' '-lopenblas|g" python/setup.py
    sed -i "s|'-lgomp'|${LDFLAG_OMP}|g" python/setup.py

    make clean
    make
    if [[ $? -eq 0 ]]; then
        echo "Installed CLASS-PT."
    else
        echo "Error: Failed to install CLASS-PT."
        exit 1
    fi

    cd -
fi


# ------------------------------------------------------------------------
# GSL & FFTW
# ------------------------------------------------------------------------

read -p "==> Install GSL and FFTW libraries? (yes/[no]) " ans_gslfftw
ans_gslfftw=$(filter_ans "$ans_gslfftw")
if [[ "$ans_gslfftw" = 'y' ]]; then
    echo "Installing GSL and FFTW libraries."
    conda install gsl fftw -y
    if [[ $? -eq 0 ]]; then
        echo "Installed GSL and FFTW libraries."
    else
        echo "Warning: Failed to install GSL and FFTW libraries."
    fi
fi


# ------------------------------------------------------------------------
# libcuba
# ------------------------------------------------------------------------

read -p "==> Install Cuba library? (yes/[no]) " ans_libcuba
ans_libcuba=$(filter_ans "$ans_libcuba")
if [[ "$ans_libcuba" = 'y' ]]; then
    echo "Installing Cuba library."
    conda install libcuba -y
    if [[ $? -eq 0 ]]; then
        echo "Installed Cuba library."
    else
        echo "Warning: Failed to install Cuba library."
    fi
fi


# ------------------------------------------------------------------------
# iminuit & pocoMC
# ------------------------------------------------------------------------

# Install iminuit.
read -p "==> Install iminuit? (yes/[no]) " ans_iminuit
ans_iminuit=$(filter_ans "$ans_iminuit")
if [[ "$ans_iminuit" = 'y' ]]; then
    echo "Installing iminuit."
    conda install iminuit -y
    if [[ $? -eq 0 ]]; then
        echo "Installed iminuit."
    else
        echo "Warning: Failed to install iminuit."
    fi
fi

# Install pocoMC.
read -p "==> Install pocoMC? (yes/[no]) " ans_pmc
ans_pmc=$(filter_ans "$ans_pmc")
if [[ "$ans_pmc" = 'y' ]]; then
    echo "Installing pocoMC."
    python -m pip install -vvv pocomc
    if [[ $? -eq 0 ]]; then
        echo "Installed pocoMC."
    else
        echo "Warning: Failed to install pocoMC."
    fi
fi


# ------------------------------------------------------------------------
# Matryoshka
# ------------------------------------------------------------------------

read -p "==> Install Matryoshka? (yes/[no]) " ans_matry
ans_matry=$(filter_ans "$ans_matry")
if [[ "$ans_matry" = 'y' ]]; then
    # Install Matplotlib.
    read -p "====> Install Matplotlib as a Matryoshka dependency? (yes/[no]) " ans_mpl
    ans_mpl=$(filter_ans "$ans_mpl")
    if [[ "$ans_mpl" = 'y' ]]; then
        echo "Installing Matplotlib."
        conda install matplotlib -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Matplotlib."
        else
            echo "Warning: Failed to install Matplotlib."
        fi
    fi

    # Install Numba.
    read -p "====> Install Numba as a Matryoshka dependency? (yes/[no]) " ans_numba
    ans_numba=$(filter_ans "$ans_numba")
    if [[ "$ans_numba" = 'y' ]]; then
        echo "Installing Numba."
        conda install numba -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Numba."
        else
            echo "Warning: Failed to install Numba."
        fi
    fi

    # Install Astropy.
    read -p "====> Install Astropy as a Matryoshka dependency? (yes/[no]) " ans_astropy
    ans_astropy=$(filter_ans "$ans_astropy")
    if [[ "$ans_astropy" = 'y' ]]; then
        echo "Installing Astropy."
        conda install astropy -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Astropy."
        else
            echo "Warning: Failed to install Astropy."
        fi
    fi

    # Install Tensorflow.
    read -p "====> Install Tensorflow as a Matryoshka dependency? (yes/[no]) " ans_tf
    ans_tf=$(filter_ans "$ans_tf")
    if [[ "$ans_tf" = 'y' ]]; then
        echo "Installing Tensorflow."
        conda install tensorflow -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Tensorflow."
        else
            echo "Warning: Failed to install Tensorflow."
        fi
    fi

    # Install Matryoshka.
    echo "Installing Matryoshka."

    if [[ -d "./Matryoshka" ]]; then
        read -p "====> Remove existing Matryoshka directory? (yes/[no]) " ans_rmmatry
        ans_rmmatry=$(filter_ans "$ans_rmmatry")
        if [[ "$ans_rmmatry" = 'y' ]]; then
            rm -rf ./Matryoshka
        fi
    fi
    git clone https://github.com/JDonaldM/Matryoshka
    cd ./Matryoshka
    python -m pip install -vvv -e .

    if [[ $? -eq 0 ]]; then
        echo "Installed Matryoshka."
    else
        echo "Warning: Failed to install Matryoshka."
    fi

    cd -
fi


# ------------------------------------------------------------------------
# BICKER
# ------------------------------------------------------------------------

read -p "==> Install BICKER? (yes/[no]) " ans_bicker
ans_bicker=$(filter_ans "$ans_bicker")
if [[ "$ans_bicker" = 'y' ]]; then
    # Install Tensorflow.
    read -p "====> Install Tensorflow as a BICKER dependency? (yes/[no]) " ans_tf
    ans_tf=$(filter_ans "$ans_tf")
    if [[ "$ans_tf" = 'y' ]]; then
        echo "Installing Tensorflow."
        conda install tensorflow -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Tensorflow."
        else
            echo "Warning: Failed to install Tensorflow."
        fi
    fi

    # Install SciPy.
    read -p "====> Install SciPy as a BICKER dependency? (yes/[no]) " ans_scipy
    ans_scipy=$(filter_ans "$ans_scipy")
    if [[ "$ans_scipy" = 'y' ]]; then
        echo "Installing SciPy."
        conda install scipy -y
        if [[ $? -eq 0 ]]; then
            echo "Installed SciPy."
        else
            echo "Warning: Failed to install SciPy."
        fi
    fi

    # Install BICKER.
    echo "Installing BICKER."

    if [[ -d "./BICKER" ]]; then
        read -p "====> Remove existing BICKER directory? (yes/[no]) " ans_rmbicker
        ans_rmbicker=$(filter_ans "$ans_rmbicker")
        if [[ "$ans_rmbicker" = 'y' ]]; then
            rm -rf ./BICKER
        fi
    fi
    curl -L "https://github.com/ROEcosmology/TripoSH-Fitting/releases/download/dummy-bicker/BICKER-main.zip" -o ./BICKER.zip
    unzip BICKER.zip && rm BICKER.zip && mv ./BICKER-main ./BICKER
    cd ./BICKER

    python -m pip install -vvv -e .
    if [[ $? -eq 0 ]]; then
        echo "Installed BICKER."
    else
        echo "Warning: Failed to install BICKER."
    fi

    cd -
fi


# ========================================================================
# Components
# ========================================================================

# ------------------------------------------------------------------------
# Bispectrum Model
# ------------------------------------------------------------------------

echo "Installing bispectrum model package."

if [[ -d "./TripoSH-Model" ]]; then
    read -p "==> Remove existing bispectrum model directory? (yes/[no]) " ans_rmmod
    ans_rmmod=$(filter_ans "$ans_rmmod")
    if [[ "$ans_rmmod" = 'y' ]]; then
        rm -rf ./TripoSH-Model
    fi
fi
git clone https://github.com/ROEcosmology/TripoSH-Model
cd ./TripoSH-Model
git restore .

python -m pip install -vvv -e .
if [[ $? -eq 0 ]]; then
    echo "Installed bispectrum model package."
else
    echo "Error: Failed to install bispectrum model package."
    exit 1
fi

cd -


# ------------------------------------------------------------------------
# Bispectrum Fitting
# ------------------------------------------------------------------------

echo "Installing bispectrum fitting package."

if [[ -d "./TripoSH-Fitting" ]]; then
    read -p "==> Remove existing bispectrum fitting directory? (yes/[no]) " ans_rmfit
    ans_rmfit=$(filter_ans "$ans_rmfit")
    if [[ "$ans_rmfit" = 'y' ]]; then
        rm -rf ./TripoSH-Fitting
    fi
fi
git clone https://github.com/ROEcosmology/TripoSH-Fitting
cd ./TripoSH-Fitting
git restore .

if [[ $? -eq 0 ]]; then
    echo "Installed bispectrum fitting package."
else
    echo "Error: Failed to install bispectrum fitting package."
    exit 1
fi

cd -
