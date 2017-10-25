#!/bin/bash

# Ensure script is running as root
if (($EUID != 0)); then
    echo "Please run as root"
    exit
fi

# Set Default workspace name
WORKSPACE_NAME=ros_catkin_ws

# Get workspace name
echo Enter workspace name?
read WORKSPACE_NAME

# Building the workspace
# This function builds the workspace
build_workspace()
{
    echo Building your catkin workspace ....
    cd ~/$WORKSPACE_NAME
    echo Your current directory $PWD
    echo Your workspace $WORKSPACE_NAME
    sudo ./src/catkin/bin/catkin_make_isolated --install -DCMAKE_BUILD_TYPE=Release --install-space /opt/ros/kinetic -j2
    echo "source /opt/ros/kinetic/setup.bash" >> ~/.bashrc
}

# Print workspace name confirmation
echo Setting workspace name to $WORKSPACE_NAME

# Setup ROS Repositories
echo Setting up ROS Repositories ....
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
sudo apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-key 421C365BD9FF1F717815A3895523BAEEB01FA116

# Ensure Debian package index is up-to-date
echo Updating Debian package index ....
sudo apt-get update
sudo apt-get upgrade

# Install bootstrap dependencies
echo Installing bootstrap dependencies ....
sudo apt-get install -y python-rosdep python-rosinstall-generator python-wstool python-rosinstall build-essential cmake

# Initialize rosdep
echo Initializing Rosdep ....
sudo rosdep init
rosdep update

# ---- Installation ------
echo Starting ROS installation

# Create a catkin workspace
echo Creating your catkin workspace ....
mkdir -p ~/$WORKSPACE_NAME
cd ~/$WORKSPACE_NAME

# *** The robot variant is defined to be core, stable, ROS libraries for any robot hardware. It is the "general robotics" libraries of ROS. It may not contain any GUI dependencies ***
echo Generating install files ....
rosinstall_generator robot --rosdistro kinetic --deps --wet-only --tar > kinetic-robot-wet.rosinstall
wstool init src kinetic-robot-wet.rosinstall_generator

# Resolve dependencies
echo Resolving dependency issues ....
mkdir -p ~/$WORKSPACE_NAME/external_src
cd ~/$WORKSPACE_NAME/external_src
wget --no-check http://sourceforge.net/projects/assimp/files/assimp-3.1/assimp-3.1.1_no_test_models.zip/download -O assimp-3.1.1_no_test_models.zip
unzip assimp-3.1.1_no_test_models.zip
cd assimp-3.1.1
cmake .
make
sudo make install
rm -rf assimp-3.1.1_no_test_models.zip

cd ~/$WORKSPACE_NAME
echo Resolving more dependency issues ....
rosdep install -y --from-paths src --ignore-src --rosdistro kinetic -r --os=debian:jessie

# The code below trys to build the workspace
{
    build_workspace
} || {
    echo Failed!
    # If build fails try skipping collada_urdf
    echo skipping collada_urdf
    rosinstall_generator desktop --rosdistro kinetic --deps --wet-only --exclude collada_parser collada_urdf --tar > kinetic-desktop-wet.rosinstall
    {
        # Attemping to rebuild workspace
        echo Attemping to rebuild workspace
        build_workspace
    } || {
        echo Failed!
        # If build fails again
        # Solve assimp, collada_parser and collada_urdf dependency errors
        echo Solving assimp, collada_parser and collada_urdf errors ....
        cd ~/$WORKSPACE_NAME/src/
        
        # Remove collada_parser, it is just a pain
        echo Removing the collada_parser package ....
        rm -rf collada_parser
        
        # Replace all Eigen3 find_package calls with their appropriate calls
        echo Replacing all Eigen3 find_package calls with their appropriate calls ....
        grep -rli 'find_package(Eigen3 REQUIRED)' | xargs -i@ sed -i 's/find_package(Eigen3 REQUIRED)/find_package(PkgConfig)\npkg_search_module(Eigen3 REQUIRED eigen3)/g'
        
        # Finally attempt to build workspace again
        build_workspace
    }
}

echo Done.



