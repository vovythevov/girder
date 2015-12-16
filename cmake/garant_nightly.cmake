#
# This is a dashboard script that tests Girder against the latest packages
# on PyPI to detect failures resulting in the always changing dependency
# landscape.
#
set(CTEST_SOURCE_DIRECTORY "$ENV{HOME}/Dashboards/girder")
set(CTEST_BINARY_DIRECTORY "$ENV{HOME}/Builds/girder-$ENV{PYENV_VERSION}")

ctest_empty_binary_directory( ${CTEST_BINARY_DIRECTORY} )

set(CTEST_SITE "garant")
set(CTEST_BUILD_NAME "Linux-master-nightly-python-$ENV{PYENV_VERSION}")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_UPDATE_COMMAND "git")
set(venv "${CTEST_BINARY_DIRECTORY}/test-venv")
set(venv_python "${venv}/bin/python")
set(venv_pip "${venv}/bin/pip")
set($ENV{PATH} "${venv}/bin:$ENV{PATH}")

file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")

# rebuild EVERYTHING from scratch
execute_process(COMMAND git clean -fdx WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}")

ctest_start("Nightly")
ctest_update(SOURCE ${CTEST_SOURCE_DIRECTORY})
ctest_submit(PARTS Start Update)

execute_process(COMMAND npm install WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY})

# always use the latest pip and virtualenv
execute_process(COMMAND "${venv_pip}" install -U pip virtualenv)

# create the new virtual environment
execute_process(COMMAND virtualenv "${venv}")

# install core dependencies
execute_process(COMMAND "${venv_pip}" install -e .[plugins] WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}")

# install development deps keeping the core deps installed already
execute_process(COMMAND "${venv_pip}" install -r requirements-dev.txt WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}")

# build and test
ctest_configure(
  OPTIONS
  "-DPYTHON_COVERAGE_EXECUTABLE=${venv}/bin/coverage;-DFLAKE8_EXECUTABLE=${venv}/bin/flake8;-DPYTHON_VERSION=$ENV{PYENV_VERSION};-DPYTHON_EXECUTABLE=${venv_python}"
)
ctest_submit(PARTS Configure)
ctest_build()
ctest_submit(PARTS Build)
ctest_test(PARALLEL_LEVEL 4)
ctest_submit(PARTS Test)
ctest_coverage()
ctest_submit(PARTS Coverage)

ctest_submit(PARTS Notes ExtraFiles Upload Submit)
