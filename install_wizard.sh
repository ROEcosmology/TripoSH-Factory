#!/usr/bin/env bash
#
# @file install_wizard.sh
# @author Mike S Wang
# @brief Installation wizard for TripoSH suite.
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
TENSORFLOW_VERSION='<2.16'
POCOMC_VERSION='<=0.2.2'

cecho ":: TripoSH suite installation wizard ::"


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
        cecho "\033[Warning: Empty environment name is reset to 'triposh' by default."
        env_name='triposh'
    fi

    # Detect existing environment.
    flag_createnv='false'
    if conda env list | grep -q "^${env_name}\s"; then
        cecho "\033[Warning: Conda environment '${env_name}' already exists."
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
                cecho "\033[Warning: Installation aborted."
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
    cecho "\033[Warning: conda-forge is not the top-priority channel."
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
    ans_maths='y'
    ans_standard='y'
    ans_accel='y'
    ans_statest='y'

    ans_classpt='y'
    ans_rmclasspt='y'

    ans_matry='y'
    ans_rmmatry='y'

    ans_bicker='y'
    ans_rmbicker='y'

    ans_iminuit='y'
    ans_pmc='y'

    ans_rmmod='y'
    ans_rmfit='y'
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
        cecho "\033[Warning: Failed to install Conda compiler suite."
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
        cecho "\033[Warning: Failed to install OpenMP library."
    fi
fi

# Install mathematical libraries.
if [[ -z "${ans_maths}" ]]; then
    read -p "$(cecho '==> Install mathematical libraries including OpenBLAS, GSL, FFTW and Cuba? (y/[n]) ')" ans_maths
    ans_maths="$(filter_response ${ans_maths})"
fi
if [[ "${ans_maths}" == 'y' ]]; then
    cecho "Installing mathematical libraries."
    conda install openblas gsl fftw libcuba -y
    if [[ $? -eq 0 ]]; then
        cecho "Installed mathematical libraries."
    else
        cecho "\033[Warning: Failed to install mathematical libraries."
    fi
fi

# Install standard packages.
if [[ -z "${ans_standard}" ]]; then
    read -p "$(cecho '==> Install standard packages including Python ('${PYTHON_VERSION:-unconstrained}'), NumPy ('${NUMPY_VERSION:-unconstrained}'), SciPy, Astropy and Matplotlib? (y/[n]) ')" ans_standard
    ans_standard="$(filter_response ${ans_standard})"
fi
if [[ "${ans_standard}" == 'y' ]]; then
    cecho "Installing standard packages."
    conda install "python${PYTHON_VERSION}" "numpy${NUMPY_VERSION}" scipy astropy matplotlib -y
    if [[ $? -eq 0 ]]; then
        cecho "Installed standard packages."
    else
        cecho "\033[Warning: Failed to install standard packages."
    fi
fi

# Install accelerator packages.
if [[ -z "${ans_accel}" ]]; then
    read -p "$(cecho '==> Install accelerator packages including TensorFlow ('${TENSORFLOW_VERSION:-unconstrained}') and Numba? (y/[n]) ')" ans_accel
    ans_accel="$(filter_response ${ans_accel})"
fi
if [[ "${ans_accel}" == 'y' ]]; then
    cecho "Installing accelerator packages."
    conda install "tensorflow${TENSORFLOW_VERSION}" numba -y
    if [[ $? -eq 0 ]]; then
        cecho "Installed accelerator packages."
    else
        cecho "\033[Warning: Failed to install accelerator packages."
    fi
fi

# Install statistical estimation packages.
if [[ -z "${ans_statest}" ]]; then
    read -p "$(cecho '==> Install statistical estimation packages including iminuit and pocoMC('${POCOMC_VERSION:-unconstrained}') (y/[n]) ')" ans_statest
    ans_statest="$(filter_response ${ans_statest})"
fi
if [[ "${ans_statest}" == 'y' ]]; then
    cecho "Installing statistical estimation packages."
    conda install iminuit -y && python -m pip install "pocomc${POCOMC_VERSION}"
    if [[ $? -eq 0 ]]; then
        cecho "Installed statistical estimation packages."
    else
        cecho "\033[Warning: Failed to install statistical estimation packages."
    fi
fi


# ------------------------------------------------------------------------
# Components
# ------------------------------------------------------------------------

# Install CLASS-PT.
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
        cecho "pyproject.toml" >> .gitignore
        cecho "*.so" >> .gitignore
        cecho "*.egg-info" >> .gitignore
    else
        cecho "\033[Error: Failed to install CLASS-PT."
        exit 1
    fi

    cd -
fi

# Install Matryoshka.
if [[ -z "${ans_matry}" ]]; then
    read -p "$(cecho '==> Install Matryoshka? (y/[n]) ')" ans_matry
    ans_matry="$(filter_response ${ans_matry})"
fi
if [[ "${ans_matry}" == 'y' ]]; then
    cecho "Installing Matryoshka."

    flag_gitclone='false'
    subdir='./Matryoshka'
    if [[ -d "${subdir}" ]]; then
        if [[ -z "${ans_rmmatry}" ]]; then
            read -p "$(cecho '====> Remove existing Matryoshka directory? (y/[n]) ')" ans_rmmatry
            ans_rmmatry="$(filter_response ${ans_rmmatry})"
        fi
        if [[ "${ans_rmmatry}" == 'y' ]]; then
            rm -rf "${subdir}"
            flag_gitclone='true'
        fi
    else
        flag_gitclone='true'
    fi
    if [[ "${flag_gitclone}" == 'true' ]]; then
        git clone https://github.com/ROEcosmology/Matryoshka
    fi

    cd "${subdir}" && git restore .

    python -m pip install -vvv -e .
    if [[ $? -eq 0 ]]; then
        cecho "Installed Matryoshka."
    else
        cecho "\033[Warning: Failed to install Matryoshka."
    fi

    cd -
fi

# Install BICKER.
if [[ -z "${ans_bicker}" ]]; then
    read -p "$(cecho '==> Install BICKER? (y/[n]) ')" ans_bicker
    ans_bicker="$(filter_response ${ans_bicker})"
fi
if [[ "${ans_bicker}" == 'y' ]]; then
    cecho "Installing BICKER."

    flag_gitclone='false'
    subdir='./BICKER'
    if [[ -d "${subdir}" ]]; then
        if [[ -z "${ans_rmbicker}" ]]; then
            read -p "$(cecho '====> Remove existing BICKER directory? (y/[n]) ')" ans_rmbicker
            ans_rmbicker="$(filter_response ${ans_rmbicker})"
        fi
        if [[ "${ans_rmbicker}" == 'y' ]]; then
            rm -rf "${subdir}"
            flag_gitclone='true'
        fi
    else
        flag_gitclone='true'
    fi
    if [[ "${flag_gitclone}" == 'true' ]]; then
        git clone https://github.com/ROEcosmology/BICKER.git
    fi

    cd "${subdir}" && git restore .

    python -m pip install -vvv -e .
    if [[ $? -eq 0 ]]; then
        cecho "Installed BICKER."
    else
        cecho "\033[Warning: Failed to install BICKER."
    fi

    cd -
fi

# Install TripoSH-Model.
cecho "Installing TripoSH-Model."
subdir='./TripoSH-Model'
if [[ -d "${subdir}" ]]; then
    if [[ -z "${ans_rmmod}" ]]; then
        read -p "$(cecho '==> Remove existing TripoSH-Model directory? (y/[n]) ')" ans_rmmod
        ans_rmmod="$(filter_response ${ans_rmmod})"
    fi
    if [[ "${ans_rmmod}" == 'y' ]]; then
        rm -rf "${subdir}"
        flag_gitclone='true'
    fi
else
    flag_gitclone='true'
fi
if [[ "${flag_gitclone}" == 'true' ]]; then
    git clone https://github.com/ROEcosmology/TripoSH-Model
fi

cd "${subdir}" && git restore .

python -m pip install -vvv -e .
if [[ $? -eq 0 ]]; then
    cecho "Installed TripoSH-Model."
else
    cecho "\033[Error: Failed to install TripoSH-Model."
    exit 1
fi

cd -

# Install TripoSH-Fitting.
cecho "Installing TripoSH-Fitting."
subdir='./TripoSH-Fitting'
if [[ -d "${subdir}" ]]; then
    if [[ -z "${ans_rmfit}" ]]; then
        read -p "$(cecho '==> Remove existing TripoSH-Fitting directory? (y/[n]) ')" ans_rmfit
        ans_rmfit="$(filter_response ${ans_rmfit})"
    fi
    if [[ "${ans_rmfit}" == 'y' ]]; then
        rm -rf "${subdir}"
        flag_gitclone='true'
    fi
else
    flag_gitclone='true'
fi
if [[ "${flag_gitclone}" == 'true' ]]; then
    git clone https://github.com/ROEcosmology/TripoSH-Fitting
fi

cd "${subdir}" && git restore .

# python -m pip install -vvv -e .
if [[ $? -eq 0 ]]; then
    cecho "Installed TripoSH-Fitting."
else
    cecho "\033[Error: Failed to install TripoSH-Fitting."
    exit 1
fi

cd -
