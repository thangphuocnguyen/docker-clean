#!/bin/sh
# Maintained by Sean Kilgarriff and Killian Brackey
#
# The MIT License (MIT)
# Copyright © 2016 ZZROT LLC <zzrotdesign@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

#ENVIRONMENT VARIABLES

# @info:	Docker-clean current version
declare VERSION="1.0.0"

# @info:	Required Docker version for Volume functionality
declare REQUIRED_VERSION="1.9.0"

# @info:	Boolean for storing Docker version info
declare HAS_VERSION=false


#FUNCTIONS

# @info:    Parses and validates the CLI arguments
# @args:	Global Arguments $@
parseCli(){

	if [ "$#" -eq 0 ]; then
		dockerClean
	elif [[ $# -eq 1 ]]; then
		case $1 in
			-v | --version) version ;;
			-f | --force) stopContainers dockerClean ;;
			-i | --images) imagesDefault ;;
			-r | --reset) resetDefault ;;
			-a | --all) allDefault ;;
			-h | --help | *) usage ;;
		esac
	else
		usage
	fi
}




# @info:	Prints out Docker-clean current version
function version {
	echo $VERSION
}

# @info:	Prints out usage
function usage {
	echo "Options:"
	echo "-v or --version to print the current version"
	echo "-f or --force to stop and delete running containers."
	echo "-i or --images to delete all images, not just untagged."
	echo "-a or --all to stop and delete running containers and images."
	echo "-h or --help for this menu."
	echo "\n"
}

# @info:	Prints out 3-point version (000.000.000) without decimals for comparison
# @args:	Docker Version of the client
function printVersion {
     echo "$@" | awk -F. '{ printf("%03d%03d%03d\n", $1,$2,$3); }';
 }

# @info:	Checks Docker Version and then configures the HAS_VERSION var.
 function checkVersion  {
     local Docker_Version="$(docker --version | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')"
     if [ $(printVersion "$Docker_Version") -gt $(printVersion "$REQUIRED_VERSION") ]; then
         HAS_VERSION=true
     else
         echo "Your Version of Docker is below 1.9.0 which is required for full functionality."
         echo "Please upgrade your Docker daemon. Until then, the Volume processing will not work."
     fi
 }

# @info:	Checks to see if Docker is installed and connected
 function checkDocker {
     #Run Docker ps to make sure that docker is installed
     #As well as that the Daemon is connected.
     docker ps &>/dev/null
     DOCKER_CHECK=$?

     #If Docker Check returns 1 (Error), send a message and exit.
     if [ "$DOCKER_CHECK" -eq 1 ]; then
         echo "Docker is either not installed, or the Docker Daemon is not currently connected."
         echo "Please check your installation and try again."
         exit 1;
     fi
 }

# @info:	Stops all running docker containers
function stopContainers {
    activeContainers="$(docker ps -a -q)"
    if [ ! "$activeContainers" ]; then
        echo No Running Containers To Stop!
    else
        docker rm -f $activeContainers
    fi
}

# @info:	Removes all stopped docker containers.
function cleanContainers {
    stoppedContainers="$(docker ps -f STATUS=exited -q)"
    if [ ! "$stoppedContainers" ]; then
        echo No Containers To Clean!
    else
        docker rm $stoppedContainers
    fi
}

# @info:	Removes all untagged docker images.
#Credit goes to http://jimhoskins.com/2013/07/27/remove-untagged-docker-images.html
function cleanImages {
    untaggedImages="$(docker images | grep "^<none>" | awk '{print $3}')"
    if [ ! "$untaggedImages" ]; then
        echo No Untagged Images!
    else
        docker rmi $untaggedImages
    fi
}

# @info:	Removes all Dangling Docker Volumes.
function cleanVolumes {
    danglingVolumes="$(docker volume ls -qf dangling=true)"
    if [ ! "$danglingVolumes" ]; then
        echo No Dangling Volumes!
    else
        docker rmi $danglingVolumes
    fi
}

# @info:	Stops all containers, and deletes all images.
function deleteImages {
	stopContainers
	listedImages="$(docker images -q)"
	if [ ! "$listedImages" ]; then
		echo No Images to delete!
	else
		echo delete
		docker rmi $listedImages
	fi
}

# @info:	Runs the checks before the main code can be run.
function Check {
	checkDocker
	checkVersion
}

# @info:	Default run option, cleans stopped containers and images
function dockerClean {
	cleanContainers
	cleanImages
	if [ $HAS_VERSION == true ]; then
	    cleanVolumes
	else
	    exit 0;
	fi
}

# @info:	Restarts and reRuns docker-machine env active machine
function restartMachine {
	active="$(docker-machine active)"
	docker-machine restart $active
	eval $(docker-machine env $active)
	echo Running docker-machine env $active...
	echo "New IP Address for" $active":" $(docker-machine ip)
}

#END FUNCTIONS


# @info:	Main function
Check
parseCli "$@"
