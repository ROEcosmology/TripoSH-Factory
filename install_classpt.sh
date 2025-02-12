#!/usr/bin/env bash
#
# @file install_classpt.sh
# @author Mike S Wang
# @brief Installation wizard for CLASS-PT.
#

# ========================================================================
# Preamble
# ========================================================================

# @brief Filter prompt response to 'y' (yes) or 'n' (no).
#
function filter_response () {
    [[ "$1" =~ ^([yY][eE][sS]|[yY])$ ]] && echo "y" || echo "n"
}

# @brief Colourised `echo`.
#
function cecho () {
    echo -e "\033[1;34m$1\033[0m"
}

PYTHON_VERSION='<3.11'
NUMPY_VERSION='<2'

cecho ":: CLASS-PT installation wizard ::"


# ========================================================================
# Environment
# ========================================================================

# ------------------------------------------------------------------------
# Platform
# ------------------------------------------------------------------------

OS="$(uname -s)"
MACH="$(uname -m)"

# Set environment variables.
if [[ "$OS" == 'Darwin' ]]; then
    if [[ "$MACH" == 'arm64' ]]; then
        export MACOSX_DEPLOYMENT_TARGET=11.0
    elif [[ "$MACH" == 'x86_64' ]]; then
        export MACOSX_DEPLOYMENT_TARGET=10.9
    fi
fi


# ------------------------------------------------------------------------
# Conda
# ------------------------------------------------------------------------

ans_newenv='n'
read -p "$(cecho '==> Create a new Conda environment? (y/[n]) ')" ans_newenv
ans_newenv="$(filter_response ${ans_newenv})"
if [[ "${ans_newenv}" == 'y' ]]; then
    # Ask for the environment name.
    read -p "$(cecho '====> Enter the name of the new environment: ')" env_name
    if [[ -z "${env_name}" ]]; then
        cecho "\033[1;33mWarning: Empty environment name is reset to 'classpt' by default."
        env_name='classpt'
    fi

    # Detect existing environment.
    flag_createnv='false'
    if conda env list | grep -q "^${env_name}\s"; then
        cecho "\033[1;33mWarning: Conda environment '${env_name}' already exists."
        read -p "$(cecho '====> Remove existing Conda environment? (y/[n]) ')" ans_rmenv
        ans_rmenv="$(filter_response ${ans_rmenv})"
        if [[ "${ans_rmenv}" == 'y' ]]; then
            # Remove existing environment.
            cecho "Removing Conda environment: '${env_name}'"
            conda env remove --name "${env_name}" -y
            if [[ $? -eq 0 ]]; then
                cecho "Removed Conda environment: '${env_name}'"
            else
                cecho "\033[Error: Failed to remove Conda environment: '${env_name}'"
                exit 1
            fi
            flag_createnv=true
        else
            read -p "$(cecho '====> Activate existing Conda environment? (y/[n]) ')" ans_actenv
            # Designate existing environment to be activated.
            ans_actenv="$(filter_response ${ans_actenv})"
            if [[ "${ans_actenv}" != 'y' ]]; then
                cecho "\033[1;33mWarning: Installation aborted."
                exit 0
            fi
        fi
    else
        flag_createnv='true'
    fi

    # Create new Conda environment.
    if [[ "${flag_createnv}" == 'true' ]]; then
        cecho "Creating new Conda environment: '${env_name}'"
        conda create --name "${env_name}" "python${PYTHON_VERSION}" "numpy${NUMPY_VERSION}" -y
        if [[ $? -eq 0 ]]; then
            cecho "Created Conda environment: '${env_name}'"
        else
            cecho "\033[Error: Failed to create Conda environment '${env_name}'"
            exit 1
        fi
    fi

    # Activate the new environment.
    cecho "Activating Conda environment: '${env_name}'"
    source "$(conda info --base)"/etc/profile.d/conda.sh
    conda activate "${env_name}"
    if [[ "${CONDA_DEFAULT_ENV}" != "${env_name}" ]]; then
        cecho "\033[Error: Failed to activate Conda environment '${env_name}'"
        exit 1
    fi
else
    cecho "Active Conda environment: '${CONDA_DEFAULT_ENV}'"
    read -p "$(cecho '==> Change to another Conda environment? (y/[n]) ')" ans_chenv
    ans_chenv="$(filter_response ${ans_chenv})"
    if [[ "${ans_chenv}" == 'y' ]]; then
        read -p "$(cecho '====> Enter the name of the Conda environment: ')" env_name
        source "$(conda info --base)"/etc/profile.d/conda.sh
        conda activate "${env_name}"
    fi
fi
export CONDA_ACTIVE_ENV="${CONDA_DEFAULT_ENV}"
cecho "Active Conda environment: '${CONDA_ACTIVE_ENV}'"

# Check if conda-forge is the top-priority channel.
top_priority_channel="$(conda config --show channels | awk '/^  -/ {print $2}' | tr -d ' ' | head -1)"
if [ "${top_priority_channel}" != 'conda-forge' ]; then
    cecho "\033[1;33mWarning: conda-forge is not the top-priority channel."
    read -p "$(cecho '==> Set conda-forge as the top-priority channel? (y/[n]) ')" ans_prioforge
    ans_prioforge="$(filter_response ${ans_prioforge})"
    if [[ "${ans_prioforge}" == 'y' ]]; then
        conda config --add channels conda-forge
        # conda config --set channel_priority strict
        cecho "Set conda-forge as the top-priority channel."
    fi
fi


# ========================================================================
# Installation
# ========================================================================

# ------------------------------------------------------------------------
# Auto-installation
# ------------------------------------------------------------------------

cecho "The installation wizard offers a guided installation process as well as an automatic one."
cecho "The latter is recommended only for a clean directory and Conda environment."

read -p "$(cecho '==> Auto-install all packages and dependencies? (y/[n]) ')" ans_autoins
ans_autoins="$(filter_response ${ans_autoins})"
if [[ "${ans_autoins}" == 'y' ]]; then
    cecho "Auto-installing all packages and dependencies."
    cecho "The installation process may take a while."
    cecho "Press Ctrl+C to abort."
    sleep 1

    # Set all flags to 'yes'.
    ans_compiler='y'
    ans_openmp='y'
    ans_openblas='y'
    ans_standard='y'

    ans_classpt='y'
    ans_rmclasspt='y'
fi


# ------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------

# Install compiler suite.
if [[ -z "${ans_compiler}" ]]; then
    read -p "$(cecho '==> Install Conda compiler suite? (y/[n]) ')" ans_compiler
    ans_compiler="$(filter_response ${ans_compiler})"
fi
if [[ "${ans_compiler}" == 'y' ]]; then
    cecho "Installing Conda compiler suite."

    # Clear Conda activated environment stack.
    for i in $(seq "${CONDA_SHLVL}"); do
        conda deactivate
    done
    conda activate "${CONDA_ACTIVE_ENV}"

    conda install cxx-compiler c-compiler -y
    if [[ $? -eq 0 ]]; then
        cecho "Installed Conda compiler suite."
    else
        cecho "\033[1;33mWarning: Failed to install Conda compiler suite."
    fi
fi

if [[ -z "$CC" ]]; then
    read -p "$(cecho '====> Enter the C compiler (as none is set): ')" CC
fi
if [[ -z "$CXX" ]]; then
    read -p "$(cecho '====> Enter the C++ compiler (as none is set): ')" CXX
fi

# Install OpenMP library.
if [[ -z "${ans_openmp}" ]]; then
    read -p "$(cecho '==> Install OpenMP library? (y/[n]) ')" ans_openmp
    ans_openmp="$(filter_response ${ans_openmp})"
fi
if [[ "${ans_openmp}" == 'y' ]]; then
    cecho "Installing OpenMP library."
    if [[ "$OS" = 'Darwin' ]]; then
        conda install llvm-openmp -y
    else
        conda install libgomp -y
    fi
    if [[ $? -eq 0 ]]; then
        cecho "Installed OpenMP library."
    else
        cecho "\033[1;33mWarning: Failed to install OpenMP library."
    fi
fi

# Install OpenBLAS library.
if [[ -z "${ans_openblas}" ]]; then
    read -p "$(cecho '====> Install OpenBLAS library as a CLASS-PT dependency? (y/[n]) ')" ans_openblas
    ans_openblas="$(filter_response ${ans_openblas})"
fi
if [[ "${ans_openblas}" == 'y' ]]; then
    cecho "Installing OpenBLAS library."
    conda install openblas -y
    if [[ $? -eq 0 ]]; then
        cecho "Installed OpenBLAS library."
    else
        cecho "\033[1;33mWarning: Failed to install OpenBLAS library."
    fi
fi

# Install standard packages.
if [[ -z "${ans_standard}" ]]; then
    read -p "$(cecho '==> Install standard packages including Python ('${PYTHON_VERSION:-unconstrained}') and NumPy ('${NUMPY_VERSION:-unconstrained}')? (y/[n]) ')" ans_standard
    ans_standard="$(filter_response ${ans_standard})"
fi
if [[ "${ans_standard}" == 'y' ]]; then
    cecho "Installing standard packages."
    conda install "python${PYTHON_VERSION}" "numpy${NUMPY_VERSION}" -y
    if [[ $? -eq 0 ]]; then
        cecho "Installed standard packages."
    else
        cecho "\033[1;33mWarning: Failed to install standard packages."
    fi
fi


# ------------------------------------------------------------------------
# Components
# ------------------------------------------------------------------------

if [[ -z "${ans_classpt}" ]]; then
    read -p "$(cecho '==> Install CLASS-PT? (y/[n]) ')" ans_classpt
    ans_classpt="$(filter_response ${ans_classpt})"
fi
if [[ "${ans_classpt}" == 'y' ]]; then
    cecho "Installing CLASS-PT."

    flag_gitclone='false'
    subdir='./CLASS-PT'
    if [[ -d "${subdir}" ]]; then
        if [[ -z "${ans_rmclasspt}" ]]; then
            read -p "$(cecho '====> Remove existing CLASS-PT directory? (y/[n]) ')" ans_rmclasspt
            ans_rmclasspt="$(filter_response ${ans_rmclasspt})"
        fi
        if [[ "${ans_rmclasspt}" == 'y' ]]; then
            rm -rf "${subdir}"
            flag_gitclone='true'
        fi
    else
        flag_gitclone='true'
    fi
    if [[ "${flag_gitclone}" == 'true' ]]; then
        git clone https://github.com/Michalychforever/CLASS-PT.git
    fi

    cd "${subdir}" && git restore .
    yes | cp ../conf/Makefile-classpt ./Makefile
    yes | cp ../conf/pyproject-classy.toml ./python/pyproject.toml
    yes | cp ../conf/setup-classy.py ./python/setup.py

    make clean
    make -j
    if [[ $? -eq 0 ]]; then
        cecho "Installed CLASS-PT."
        echo "pyproject.toml" >> .gitignore
        echo "*.so" >> .gitignore
        echo "*.egg-info" >> .gitignore
    else
        cecho "\033[Error: Failed to install CLASS-PT."
        exit 1
    fi

    cd -
fi
