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
    if [[ $(uname -m) = 'arm64' ]]; then
        export MACOSX_DEPLOYMENT_TARGET=11.0
    elif [[ $(uname -m) = 'x86_64' ]]; then
        export MACOSX_DEPLOYMENT_TARGET=10.9
    fi
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
        if [[ $? -ne 0 ]]; then
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
# Auto-Installation
# ========================================================================

echo "The installation wizard offers a guided installation process as well as an auto-installation process."
echo "The latter is recommended only for a clean directory and Conda environment."

read -p "==> Auto-install all packages and dependencies? (yes/[no]) " ans_auto
ans_auto=$(filter_ans "$ans_auto")
if [[ "$ans_auto" = 'y' ]]; then
    echo "Auto-installing all packages and dependencies."
    echo "The installation process may take a while."
    echo "Press Ctrl+C to abort the installation."
    sleep 1

    # Set all flags to 'yes'.
    ans_compiler='y'
    ans_openmp='y'
    ans_core='y'

    ans_classpt='y'
    ans_rmclasspt='y'
    ans_openblas='y'

    ans_gslfftw='y'
    ans_libcuba='y'

    ans_iminuit='y'
    ans_pmc='y'

    ans_matry='y'
    ans_rmmatry='y'
    ans_tf='y'
    ans_numba='y'
    ans_astropy='y'
    ans_mpl='y'

    ans_bicker='y'
    ans_rmbicker='y'
    ans_scipy='y'

    ans_rmmod='y'
    ans_rmfit='y'
fi


# ========================================================================
# Dependencies
# ========================================================================

# ------------------------------------------------------------------------
# Build tools
# ------------------------------------------------------------------------

# Install compiler suite.
if [[ -z "ans_compiler" ]]; then
    read -p "==> Install Conda compiler suite? (yes/[no]) " ans_compiler
    ans_compiler=$(filter_ans "$ans_compiler")
fi
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
if [[ -z "$ans_openmp" ]]; then
    read -p "==> Install OpenMP library? (yes/[no]) " ans_openmp
    ans_openmp=$(filter_ans "$ans_openmp")
fi
if [[ "$ans_openmp" = 'y' ]]; then
    echo "Installing OpenMP library."
    if [[ "$OS" = 'Darwin' ]]; then
        conda install llvm-openmp -y
    else
        conda install libgomp -y
    fi
    if [[ $? -eq 0 ]]; then
        echo "Installed OpenMP library."
    else
        echo "Warning: Failed to install OpenMP library."
    fi
fi

# Install core packages.
if [[ -z "$ans_core" ]]; then
    read -p "==> Install core packages including Python and Pip? (yes/[no]) " ans_core
    ans_core=$(filter_ans "$ans_core")
fi
if [[ "$ans_core" = 'y' ]]; then
    echo "Installing core packages."
    conda install "python<3.11" pip -y
    if [[ $? -eq 0 ]]; then
        echo "Installed core packages."
    else
        echo "Warning: Failed to install core packages."
    fi
fi


# ------------------------------------------------------------------------
# CLASS-PT
# ------------------------------------------------------------------------

if [[ -z "$ans_classpt" ]]; then
    read -p "==> Install CLASS-PT? (yes/[no]) " ans_classpt
    ans_classpt=$(filter_ans "$ans_classpt")
fi
if [[ "$ans_classpt" = 'y' ]]; then
    # Install OpenBLAS library
    if [[ -z "$ans_openblas" ]]; then
        read -p "====> Install OpenBLAS library as a CLASS-PT dependency? (yes/[no]) " ans_openblas
        ans_openblas=$(filter_ans "$ans_openblas")
    fi
    if [[ "$ans_openblas" = 'y' ]]; then
        echo "Installing OpenBLAS library."
        conda install openblas -y
        if [[ $? -eq 0 ]]; then
            echo "Installed OpenBLAS library."
        else
            echo "Warning: Failed to install OpenBLAS library."
        fi
    fi

    # Install CLASS-PT
    echo "Installing CLASS-PT."

    if [[ -d "./CLASS-PT" ]]; then
        if [[ -z "$ans_rmclasspt" ]]; then
            read -p "====> Remove existing CLASS-PT directory? (yes/[no]) " ans_rmclasspt
            ans_rmclasspt=$(filter_ans "$ans_rmclasspt")
        fi
        if [[ "$ans_rmclasspt" = 'y' ]]; then
            rm -rf ./CLASS-PT
            git clone https://github.com/Michalychforever/CLASS-PT.git
        fi
    else
        git clone https://github.com/Michalychforever/CLASS-PT.git
    fi
    cd ./CLASS-PT && git restore .

    cp ../conf/pyproject-classy.toml . && mv ./pyproject-classy.toml ./python/pyproject.toml
    cp ../conf/setup-classy.py . && mv ./setup-classy.py ./python/setup.py
    cp ../conf/Makefile-classpt . && mv ./Makefile-classpt ./Makefile

    make clean
    make -j
    if [[ $? -eq 0 ]]; then
        echo "Installed CLASS-PT."
        echo "*.egg-info" >> .gitignore
        echo "libclass.a" >> .gitignore
        echo "classy.*.so" >> .gitignore
        echo "class" >> .gitignore
        git restore python/classy.c
        git restore Makefile python/setup.py
        rm python/pyproject.toml
    else
        echo "Error: Failed to install CLASS-PT."
        exit 1
    fi

    cd -
fi


# ------------------------------------------------------------------------
# GSL & FFTW
# ------------------------------------------------------------------------

if [[ -z "$ans_gslfftw" ]]; then
    read -p "==> Install GSL and FFTW libraries? (yes/[no]) " ans_gslfftw
    ans_gslfftw=$(filter_ans "$ans_gslfftw")
fi
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

if [[ -z "$ans_libcuba" ]]; then
    read -p "==> Install Cuba library? (yes/[no]) " ans_libcuba
    ans_libcuba=$(filter_ans "$ans_libcuba")
fi
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
if [[ -z "$ans_iminuit" ]]; then
    read -p "==> Install iminuit? (yes/[no]) " ans_iminuit
    ans_iminuit=$(filter_ans "$ans_iminuit")
fi
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
if [[ -z "$ans_pmc" ]]; then
    read -p "==> Install pocoMC? (yes/[no]) " ans_pmc
    ans_pmc=$(filter_ans "$ans_pmc")
fi
if [[ "$ans_pmc" = 'y' ]]; then
    echo "Installing pocoMC."
    python -m pip install -vvv 'pocomc<=0.2.2'
    if [[ $? -eq 0 ]]; then
        echo "Installed pocoMC."
    else
        echo "Warning: Failed to install pocoMC."
    fi
fi


# ------------------------------------------------------------------------
# Matryoshka
# ------------------------------------------------------------------------

if [[ -z "$ans_matry" ]]; then
    read -p "==> Install Matryoshka? (yes/[no]) " ans_matry
    ans_matry=$(filter_ans "$ans_matry")
fi
if [[ "$ans_matry" = 'y' ]]; then
    # Install Tensorflow.
    if [[ -z "$ans_tf" ]]; then
        read -p "====> Install Tensorflow as a Matryoshka dependency? (yes/[no]) " ans_tf
        ans_tf=$(filter_ans "$ans_tf")
    fi
    if [[ "$ans_tf" = 'y' ]]; then
        echo "Installing Tensorflow."
        conda install "tensorflow<2.16" -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Tensorflow."
        else
            echo "Warning: Failed to install Tensorflow."
        fi
    fi

    # Install Numba.
    if [[ -z "$ans_numba" ]]; then
        read -p "====> Install Numba as a Matryoshka dependency? (yes/[no]) " ans_numba
        ans_numba=$(filter_ans "$ans_numba")
    fi
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
    if [[ -z "$ans_astropy" ]]; then
        read -p "====> Install Astropy as a Matryoshka dependency? (yes/[no]) " ans_astropy
        ans_astropy=$(filter_ans "$ans_astropy")
    fi
    if [[ "$ans_astropy" = 'y' ]]; then
        echo "Installing Astropy."
        conda install astropy -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Astropy."
        else
            echo "Warning: Failed to install Astropy."
        fi
    fi

    # Install Matplotlib.
    if [[ -z "$ans_mpl" ]]; then
        read -p "====> Install Matplotlib as a Matryoshka dependency? (yes/[no]) " ans_mpl
        ans_mpl=$(filter_ans "$ans_mpl")
    fi
    if [[ "$ans_mpl" = 'y' ]]; then
        echo "Installing Matplotlib."
        conda install matplotlib -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Matplotlib."
        else
            echo "Warning: Failed to install Matplotlib."
        fi
    fi

    # Install Matryoshka.
    echo "Installing Matryoshka."

    if [[ -d "./Matryoshka" ]]; then
        if [[ -z "$ans_rmmatry" ]]; then
            read -p "====> Remove existing Matryoshka directory? (yes/[no]) " ans_rmmatry
            ans_rmmatry=$(filter_ans "$ans_rmmatry")
        fi
        if [[ "$ans_rmmatry" = 'y' ]]; then
            rm -rf ./Matryoshka
            git clone https://github.com/ROEcosmology/Matryoshka
        fi
    else
        git clone https://github.com/ROEcosmology/Matryoshka
    fi
    cd ./Matryoshka && git restore .

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

if [[ -z "$ans_bicker" ]]; then
    read -p "==> Install BICKER? (yes/[no]) " ans_bicker
    ans_bicker=$(filter_ans "$ans_bicker")
fi
if [[ "$ans_bicker" = 'y' ]]; then
    # Install Tensorflow.
    if [[ -z "$ans_tf" ]]; then
        read -p "====> Install Tensorflow as a BICKER dependency? (yes/[no]) " ans_tf
        ans_tf=$(filter_ans "$ans_tf")
    fi
    if [[ "$ans_tf" = 'y' ]]; then
        echo "Installing Tensorflow."
        conda install "tensorflow<2.16" -y
        if [[ $? -eq 0 ]]; then
            echo "Installed Tensorflow."
        else
            echo "Warning: Failed to install Tensorflow."
        fi
    fi

    # Install SciPy.
    if [[ -z "$ans_scipy" ]]; then
        read -p "====> Install SciPy as a BICKER dependency? (yes/[no]) " ans_scipy
        ans_scipy=$(filter_ans "$ans_scipy")
    fi
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
        if [[ -z "$ans_rmbicker" ]]; then
            read -p "====> Remove existing BICKER directory? (yes/[no]) " ans_rmbicker
            ans_rmbicker=$(filter_ans "$ans_rmbicker")
        fi
        if [[ "$ans_rmbicker" = 'y' ]]; then
            rm -rf ./BICKER
            # curl -L "https://github.com/ROEcosmology/TripoSH-Fitting/releases/download/dummy-bicker/BICKER-main.zip" -o ./BICKER.zip
            # unzip BICKER.zip && rm BICKER.zip && mv ./BICKER-main ./BICKER
            git clone https://github.com/ROEcosmology/BICKER.git
        fi
    else
        # curl -L "https://github.com/ROEcosmology/TripoSH-Fitting/releases/download/dummy-bicker/BICKER-main.zip" -o ./BICKER.zip
        # unzip BICKER.zip && rm BICKER.zip && mv ./BICKER-main ./BICKER
        git clone https://github.com/ROEcosmology/BICKER.git
    fi
    cd ./BICKER && git restore .

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
    if [[ -z "$ans_rmmod" ]]; then
        read -p "==> Remove existing bispectrum model directory? (yes/[no]) " ans_rmmod
        ans_rmmod=$(filter_ans "$ans_rmmod")
    fi
    if [[ "$ans_rmmod" = 'y' ]]; then
        rm -rf ./TripoSH-Model
        git clone https://github.com/ROEcosmology/TripoSH-Model
    fi
else
    git clone https://github.com/ROEcosmology/TripoSH-Model
fi
cd ./TripoSH-Model && git restore .

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
    if [[ -z "$ans_rmfit" ]]; then
        read -p "==> Remove existing bispectrum fitting directory? (yes/[no]) " ans_rmfit
        ans_rmfit=$(filter_ans "$ans_rmfit")
    fi
    if [[ "$ans_rmfit" = 'y' ]]; then
        rm -rf ./TripoSH-Fitting
        git clone https://github.com/ROEcosmology/TripoSH-Fitting
    fi
else
    git clone https://github.com/ROEcosmology/TripoSH-Fitting
fi
cd ./TripoSH-Fitting && git restore .

if [[ $? -eq 0 ]]; then
    echo "Installed bispectrum fitting package."
else
    echo "Error: Failed to install bispectrum fitting package."
    exit 1
fi

cd -
