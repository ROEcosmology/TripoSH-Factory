#!/bin/bash
#
# @file install_classpt.sh
# @author Mike S Wang
# @brief Installation wizard for CLASS-PT.
#

echo "Installation wizard: CLASS-PT"


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


# ========================================================================
# Components
# ========================================================================

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
