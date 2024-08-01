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
        echo "Warning: Empty environment name is reset to 'classpt' by default."
        env_name='classpt'
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

# Check if conda-forge is the top-priority channel.
channel_listing=$(echo "$(conda config --show channels)" | awk '/^  -/ {print $2}' | tr -d ' ')
top_priority_channel=$(echo "${channel_listing}" | head -1)
if [ "${top_priority_channel}" != "conda-forge" ]; then
    echo "Warning: conda-forge is not the top-priority channel."
    echo "We recommend setting conda-forge as the top-priority channel."
    if [[ -z "ans_pri_forge" ]]; then
        read -p "==> Set conda-forge as the top-priority channel? (yes/[no]) " ans_pri_forge
        ans_pri_forge=$(filter_ans "$ans_pri_forge")
    fi
    if [[ "$ans_pri_forge" = 'y' ]]; then
        conda config --add channels conda-forge
        # conda config --set channel_priority strict
        echo "Set conda-forge as the top-priority channel."
    fi
fi


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
