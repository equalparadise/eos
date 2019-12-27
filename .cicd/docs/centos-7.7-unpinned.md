---
content_title: Centos 7.7 (unpinned)
---

<!-- This document is aggregated by our internal documentation tool to generate EOSIO documentation. 
The code within the codeblocks below is used in our CI/CD! 
 - It will be converted line by line into statements inside of a temporary Dockerfile and used to build our docker tag for this OS. Therefore, COPY, RUN, and other Dockerfile-isms are not permitted!
 - Code changes will update hashes and regenerate new docker images, so use with caution and do not modify unless necessary. However blank lines and # comments will not change the hash and are safe to add and remove
 - Any export VARNAME, when it's alone on a line, will be converted to ENV VARNAME in the dockerfile -->

This section contains shell commands to manually download, build, install, test, and uninstall EOSIO and dependencies on Centos 7.7.

[[info | Building EOSIO is for Advanced Developers]]
| If you are new to EOSIO, it is recommended that you install the [EOSIO Prebuilt Binaries](../../../00_install-prebuilt-binaries.md) instead of building from source.

Select a task below, then copy/paste the shell commands to a Unix terminal to execute:

* [Download EOSIO Repository](#download-eosio-repository)
* [Install EOSIO Dependencies](#install-eosio-dependencies)
* [Build EOSIO](#build-eosio)
* [Install EOSIO](#install-eosio)
* [Test EOSIO](#test-eosio)
* [Uninstall EOSIO](#uninstall-eosio)

[[info | Building EOSIO on another OS?]]
| Visit the [Build EOSIO from Source](../../index.md) section.

## Set EOSIO Environment Variables
<!-- DAC ENV -->
```sh
export EOSIO_LOCATION=$HOME/eosio
export EOS_LOCATION=$EOSIO_LOCATION/eos
export EOSIO_INSTALL_LOCATION=$EOSIO_LOCATION/install
export PATH=$EOSIO_INSTALL_LOCATION/bin:$PATH
export EOSIO_BUILD_LOCATION=$EOS_LOCATION/build
```
<!-- DAC ENV END -->
## Download EOSIO Repository
These commands set the EOSIO directories, install git, and clone the EOSIO repository.
<!-- DAC CLONE -->
```sh
# create EOSIO directories
mkdir -p $EOSIO_INSTALL_LOCATION
# install git
yum update -y && yum install -y git
# clone EOSIO repository
git clone https://github.com/EOSIO/eos.git $EOS_LOCATION
cd $EOS_LOCATION && git submodule update --init --recursive
```
<!-- DAC CLONE END -->

## Install EOSIO Dependencies
These commands install the EOSIO software dependencies. Make sure to [Download the EOSIO Repository](#download-eosio-repository) first and set the EOSIO directories.
<!-- DAC DEPS -->
```sh
# install dependencies
yum update -y && \
    yum install -y epel-release && \
    yum --enablerepo=extras install -y centos-release-scl && \
    yum --enablerepo=extras install -y devtoolset-8 && \
    yum --enablerepo=extras install -y which git autoconf automake libtool make bzip2 doxygen \
    graphviz bzip2-devel openssl-devel gmp-devel ocaml libicu-devel \
    python python-devel rh-python36 file libusbx-devel \
    libcurl-devel patch vim-common jq llvm-toolset-7.0-llvm-devel llvm-toolset-7.0-llvm-static
# build cmake
cd $EOSIO_INSTALL_LOCATION && curl -LO https://github.com/Kitware/CMake/releases/download/v3.16.2/cmake-3.16.2.tar.gz && \
    source /opt/rh/devtoolset-8/enable && \
    tar -xzf cmake-3.16.2.tar.gz && \
    cd cmake-3.16.2 && \
    ./bootstrap --prefix=$EOSIO_INSTALL_LOCATION && \
    make -j$(nproc) && \
    make install && \
    rm -rf $EOSIO_INSTALL_LOCATION/cmake-3.16.2.tar.gz $EOSIO_INSTALL_LOCATION/cmake-3.16.2
# apply clang patch
cp -f $EOS_LOCATION/scripts/clang-devtoolset8-support.patch /tmp/clang-devtoolset8-support.patch
# build boost
cd $EOSIO_INSTALL_LOCATION && curl -LO https://dl.bintray.com/boostorg/release/1.71.0/source/boost_1_71_0.tar.bz2 && \
    source /opt/rh/devtoolset-8/enable && \
    tar -xjf boost_1_71_0.tar.bz2 && \
    cd boost_1_71_0 && \
    ./bootstrap.sh --prefix=$EOSIO_INSTALL_LOCATION && \
    ./b2 --with-iostreams --with-date_time --with-filesystem --with-system --with-program_options --with-chrono --with-test -q -j$(nproc) install && \
    rm -rf $EOSIO_INSTALL_LOCATION/boost_1_71_0.tar.bz2 $EOSIO_INSTALL_LOCATION/boost_1_71_0
# build mongodb
cd $EOSIO_INSTALL_LOCATION && curl -LO https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-3.6.3.tgz && \
    tar -xzf mongodb-linux-x86_64-amazon-3.6.3.tgz && rm -f mongodb-linux-x86_64-amazon-3.6.3.tgz && \
    mv $EOSIO_INSTALL_LOCATION/mongodb-linux-x86_64-amazon-3.6.3/bin/* $EOSIO_INSTALL_LOCATION/bin/ && \
    rm -rf $EOSIO_INSTALL_LOCATION/mongodb-linux-x86_64-amazon-3.6.3
# build mongodb c driver
cd $EOSIO_INSTALL_LOCATION && curl -LO https://github.com/mongodb/mongo-c-driver/releases/download/1.13.0/mongo-c-driver-1.13.0.tar.gz && \
    source /opt/rh/devtoolset-8/enable && \
    tar -xzf mongo-c-driver-1.13.0.tar.gz && cd mongo-c-driver-1.13.0 && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$EOSIO_INSTALL_LOCATION -DENABLE_BSON=ON -DENABLE_SSL=OPENSSL -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DENABLE_STATIC=ON -DENABLE_ICU=OFF -DENABLE_SNAPPY=OFF .. && \
    make -j$(nproc) && \
    make install && \
    rm -rf $EOSIO_INSTALL_LOCATION/mongo-c-driver-1.13.0.tar.gz $EOSIO_INSTALL_LOCATION/mongo-c-driver-1.13.0
# build mongodb cxx driver
cd $EOSIO_INSTALL_LOCATION && curl -L https://github.com/mongodb/mongo-cxx-driver/archive/r3.4.0.tar.gz -o mongo-cxx-driver-r3.4.0.tar.gz && \
    source /opt/rh/devtoolset-8/enable && \
    tar -xzf mongo-cxx-driver-r3.4.0.tar.gz && cd mongo-cxx-driver-r3.4.0 && \
    sed -i 's/\"maxAwaitTimeMS\", count/\"maxAwaitTimeMS\", static_cast<int64_t>(count)/' src/mongocxx/options/change_stream.cpp && \
    sed -i 's/add_subdirectory(test)//' src/mongocxx/CMakeLists.txt src/bsoncxx/CMakeLists.txt && \
    mkdir -p build && cd build && \
    cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$EOSIO_INSTALL_LOCATION .. && \
    make -j$(nproc) && \
    make install && \
    rm -rf $EOSIO_INSTALL_LOCATION/mongo-cxx-driver-r3.4.0.tar.gz $EOSIO_INSTALL_LOCATION/mongo-cxx-driver-r3.4.0
```
<!-- DAC DEPS END -->

## Build EOSIO
These commands build the EOSIO software on the specified OS. Make sure to [Install EOSIO Dependencies](#install-eosio-dependencies) first.
<!-- DAC BUILD -->
```sh
mkdir -p $EOSIO_BUILD_LOCATION
cd $EOSIO_BUILD_LOCATION && source /opt/rh/devtoolset-8/enable && cmake -DCMAKE_BUILD_TYPE='Release' -DLLVM_DIR='/opt/rh/llvm-toolset-7.0/root/usr/lib64/cmake/llvm' -DCMAKE_INSTALL_PREFIX=$EOSIO_INSTALL_LOCATION -DBUILD_MONGO_DB_PLUGIN=true ..
cd $EOSIO_BUILD_LOCATION && make -j$(nproc)
```
<!-- DAC BUILD END -->

## Install EOSIO
This command installs the EOSIO software on the specified OS. Make sure to [Build EOSIO](#build-eosio) first.
<!-- DAC INSTALL -->
```sh
cd $EOSIO_BUILD_LOCATION && make install
```
<!-- DAC INSTALL END -->

## Test EOSIO
These commands validate the EOSIO software installation on the specified OS. This task is optional but recommended. Make sure to [Install EOSIO](#install-eosio) first.
<!-- DAC IGNORE -->
```sh
$EOSIO_INSTALL_LOCATION/bin/mongod --fork --logpath $(pwd)/mongod.log --dbpath $(pwd)/mongodata
cd $EOSIO_BUILD_LOCATION && source /opt/rh/rh-python36/enable && make test
```
<!-- DAC IGNORE END -->

## Uninstall EOSIO
These commands uninstall the EOSIO software from the specified OS.
<!-- DAC UNINSTALL -->
```sh
xargs rm < $EOSIO_BUILD_LOCATION/install_manifest.txt
rm -rf $EOSIO_BUILD_LOCATION
```
<!-- DAC UNINSTALL END -->