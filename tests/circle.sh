#!/bin/bash

###############################################################################
#  Copyright 2013 Kitware Inc.
#
#  Licensed under the Apache License, Version 2.0 ( the "License" );
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
###############################################################################

# Main test driver used inside CircleCI.  Depends on several environment
# variables set by individual test runners.  These are run in parallel
# on different containers inside CircleCI.  This is basically intended
# duplicate the "build matrix" idea on Travis.


# helper function to export a value with a given default
function ci_set {
	local var="$1"
	local default="$2"
	local value="$(echo $var)"
	eval "export $var=\${$value='$default'}"
}

function set_env {
	source "$1"

	### common variables (allows override by existing values) ###
	ci_set CI_BUILD_NAME 'default'
	ci_set CI_LOCAL_PREFIX "$HOME/local"
	ci_set CIRCLE_BRANCH 'unknown'
	ci_set CIRCLE_SHA1 'unknown'
	ci_set CI_SHORT_HASH "${CIRCLE_SHA1:0:8}"

	# CMAKE #
	ci_set CI_CMAKE_VERSION '3.1'
	ci_set CI_CMAKE_PREFIX "$CI_LOCAL_PREFIX/cmake-${CI_CMAKE_VERSION}"
	ci_set CI_CMAKE_DOWNLOAD 'http://cmake.org/files/v3.1/cmake-3.1.0-Linux-x86_64.tar.gz'

	# MONGO #
	ci_set CI_MONGO_VERSION '3.0.7'
	ci_set CI_MONGO_PREFIX "$CI_LOCAL_PREFIX/mongo-${CI_MONGO_VERSION}"
	ci_set CI_MONGO_DOWNLOAD "https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${CI_MONGO_VERSION}.tgz"

	# PYTHON #
	ci_set CI_PYTHON_VERSION '2.7.10'
	ci_set CI_PYTHON_COVERAGE 'YES'
	ci_set IGNORE_PLUGINS ''
	ci_set CI_PYTHON_VIRTUALENV "$CI_LOCAL_PREFIX/venv/$CI_PYTHON_VERSION"

	# NODE #
	ci_set CI_NODE_VERSION '0.10'

	# CTEST #
	ci_set CI_CTEST_SCRIPT "$PWD/cmake/circleci_continuous.cmake"
	ci_set JASMINE_TIMEOUT "15000"
	ci_set CI_SOURCE_DIR "$PWD"
	ci_set CI_BUILD_DIR "$HOME/build/$CI_BUILD_NAME"
	ci_set CI_TEST_FAILED "$CI_BUILD_DIR/test_failed"
	ci_set CIRCLE_ARTIFACTS "$CI_BUILD_DIR"

	### end of variable definitions ###

	# set path
	export PATH="$CI_CMAKE_PREFIX/bin:$CI_MONGO_PREFIX/bin:$PATH"
	mkdir -p "$CI_BUILD_DIR" || true
	deactivate || true  # deactivate the default venv
	source "$CI_PYTHON_VIRTUALENV/bin/activate" || true
}

# generate the installation prerequisites
function install_prereqs {
	mkdir -p "$CI_LOCAL_PREFIX" || true

	# install updated cmake if it doesn't exist
	if [[ ! -x "$CI_CMAKE_PREFIX/bin/cmake" || -n "$CI_REBUILD_CACHE" ]] ; then
		rm -fr "$CI_CMAKE_PREFIX"
		mkdir -p "$CI_CMAKE_PREFIX"
		curl -L "$CI_CMAKE_DOWNLOAD" | gunzip -c | tar -x -C "$CI_CMAKE_PREFIX" --strip-components 1
	fi
	cmake --version

	# install updated mongo
	if [ ! -x "$CI_MONGO_PREFIX/bin/mongod" ] ; then
		rm -fr "$CI_MONGO_PREFIX"
		mkdir -p "$CI_MONGO_PREFIX"
		curl -L "$CI_MONGO_DOWNLOAD"  | gunzip -c | tar -x -C "$CI_MONGO_PREFIX" --strip-components 1
	fi
	mongod --version

	# set the node version
	nvm install "$CI_NODE_VERSION"
	node --version

	npm install -g npm
	npm --version

	npm install -g grunt-cli
	grunt --version

	# install and set the python version
	deactivate || true  # deactivate the default venv
	pyenv install -s "$CI_PYTHON_VERSION"
	pyenv global "$CI_PYTHON_VERSION"
	pyenv rehash
	pip install -U virtualenv pip

	# set up the virtual environment
	if [[ ! -e "$CI_PYTHON_VIRTUALENV/bin/activate" || -n "$CI_REBUILD_CACHE" ]] ; then
		rm -fr "$CI_PYTHON_VIRTUALENV"
		mkdir -p "$(dirname "$CI_PYTHON_VIRTUALENV")" || true
		virtualenv "$CI_PYTHON_VIRTUALENV"
		source "$CI_PYTHON_VIRTUALENV/bin/activate"
	fi
	python --version

	if [ -n "$DEPLOY" ] ; then
		git fetch --unshallow
	fi
}

function install_node_deps {
	pushd "${CI_SOURCE_DIR}"
	npm install
	popd
}

function install_python_deps {
	pushd "${CI_SOURCE_DIR}"
	python scripts/InstallPythonRequirements.py --mode=dev --ignore-plugins="${IGNORE_PLUGINS}"
	popd
}

function start_mongo {
	rm -fr /tmp/db-$CI_MONGO_VERSION
	mkdir -p /tmp/db-$CI_MONGO_VERSION || true
	mongod --dbpath=/tmp/db-$CI_MONGO_VERSION &> $CIRCLE_ARTIFACTS/mongo.log &
}

# output a bunch of information for debugging
# extra information goes to stderr to be caught in an artifact file
function print_debug {
	echo '##################### programs ####################'
	set -x
	which python
	python --version
	which node
	node --version
	which npm
	npm --version
	set +x

	echo '##################### environment ####################' 1>&2
	env 1>&2

	echo '##################### exports ####################' 1>&2
	export -p 1>&2

	echo '##################### system ####################'
	set -x
	free -g
	vmstat -s
	iostat
	set +x
}

# Run ctest script
function run_test {
	set -e
	set -x
	set_env "$1"
	ctest "$CI_CTEST_ARGS" -DPYTHON_VERSION="$CI_PYTHON_VERSION" -DPYTHON_COVERAGE="$CI_PYTHON_COVERAGE" -S "$CI_CTEST_SCRIPT" || true
	set +x
	if [ -f "$CI_TEST_FAILED" ] ; then
		echo "Test failure detected"
		exit 1
	fi
}

function girder_depends {
	set -e
	set_env "$1"
	install_prereqs
	start_mongo
	install_node_deps
	install_python_deps
	print_debug 2> "${CIRCLE_ARTIFACTS}/environment.log" | tee -a "${CIRCLE_ARTIFACTS}/environment.log"
}

function girder_test {
	while (( "$#" )) ; do
		bash -c "run_test '$1'"
		shift
	done
}

# unset the virtualenv the cicleci sets by default
deactivate &> /dev/null || true
