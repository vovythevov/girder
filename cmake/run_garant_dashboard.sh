#!/bin/bash
. $HOME/.bash_profile
  
PYENV_VERSION=2.7.10 ctest -VV -S $HOME/Dashboards/girder-nightly.cmake
PYENV_VERSION=3.4.3 ctest -VV -S $HOME/Dashboards/girder-nightly.cmake
