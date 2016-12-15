#!/bin/bash
####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	importPackages.sh -- Imports all packages in the DP that are not already in the JSS into the JSS
#
# SYNOPSIS
#   There are three parameters used in this script: parameters 4, 5, and 6.  
#   Parameters 4 and 5 are used for the API Username and Password that will be used to grab the list
#   of packages from the JSS. This API user needs CREATE, UPDATE and READ privileges for Packages and 
#   Categories in the JSS. 
#
#	Parameter 6 is used for the JSS URL. This must be written out with the FQDN as well as the port
#   number. For instance, it should be written out like this:
#
#   zen01.jamf.com:8443    for most on premise installs, or
#   zen01.jamfcloud.com    if you are a cloud hosted customer, or have changed your port number to 443.
#   
#   Parameters 7, 8, 9 and 10 are used to mount the Distribution Point. 7 and 8 are the username 
#   and password for a local user that needs READ privileges to the folder. 9 is the hostname of the 
#   server hosting the Distribution Point, and 10 is the name of the Shared Folder. 
#
#	Parameter 1, 2, and 3 will not be used in this script, but since they are passed by
#	The Caspeer Suite, we will start using parameters at parameter 4.
#	If no parameter is specified for either parameter 4 or 5, the hardcoded value in the script
#	will be used.  If values are hardcoded in the script for the parameters, then they will override
#	any parameters that are passed by The Casper Suite.
#
# DESCRIPTION
#	This script will take a list of all the packages within your distribution point and compare
#   the filenames to the packages within the JSS. If there are any extra packages, it will add
#   them into the JSS in a category called "New."
#
#   THIS SCRIPT MUST BE RUN AS ROOT
#
####################################################################################################
#
# HISTORY
#
#	Version: 1.0
#
#	- Created by Chris Schasse on November 10th, 2016
#
####################################################################################################
#
# DEFINE VARIABLES & READ IN PARAMETERS
#
####################################################################################################


# HARDCODED VALUES ARE SET HERE
apiusername='packageImport'
apipassword='jamf1234'
jssurl='zen01.jamfcloud.com'
# The jssurl variable must be the FQDN with the port number. For instance:
# zen01.jamf.com:8443 (or zen01.jamfcloud.com if port number is 443)

# This is the username, password, and hostname of the distribution point that we are mounting. You
# can also use an IP address for the hostname.
dpusername='read'
dppassword='jamf1234'
dphostname='172.16.77.133'
dpsharename='DistributionPoint'


# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 4 AND, IF SO, ASSIGN TO "apiusername"
if [ "$4" != "" ] && [ "$apiusername" == "" ]; then
    apiusername=$4
fi

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 5 AND, IF SO, ASSIGN TO "apipassword"
if [ "$5" != "" ] && [ "$apipassword" == "" ]; then
    apipassword=$5
fi

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 6 AND, IF SO, ASSIGN TO "jssurl"
if [ "$6" != "" ] && [ "$jssurl" == "" ]; then
    jssurl=$6
fi

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 7 AND, IF SO, ASSIGN TO "dpusername"
if [ "$7" != "" ] && [ "$dpusername" == "" ]; then
    dpusername=$7
fi

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 8 AND, IF SO, ASSIGN TO "dppassword"
if [ "$8" != "" ] && [ "$dppassword" == "" ]; then
    dppassword=$8
fi

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 9 AND, IF SO, ASSIGN TO "dphostname"
if [ "$9" != "" ] && [ "$dphostname" == "" ]; then
    dphostname=$9
fi

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 10 AND, IF SO, ASSIGN TO "dpsharename"
if [ "$10" != "" ] && [ "$dpsharename" == "" ]; then
    dpsharename=$10
fi

####################################################################################################
# 
# SCRIPT CONTENTS - DO NOT MODIFY BELOW THIS LINE
#
####################################################################################################

# Check to see if running as root
if [ "$EUID" -ne 0 ]
  then 
	echo "" 
	echo "There was an error."
	echo ""
    echo "        This script must be run as root. Try the sudo command."  
    echo ""
    exit
fi

# Check to see if we can connect to the JSS
curl https://zen01.jamfcloud.com/JSSCheckConnection | grep curl
if [ $? != 0 ]
then 
	clear
	echo "" 
	echo "There was an error."
	echo ""
    echo "        Cannot connect to the JSS. Check the JSS URL and your internet connection."  
    echo ""
	exit
fi

# Create the "New" Category if it does not already exist
curl -u $apiusername:$apipassword https://${jssurl}/JSSResource/categories -X GET | tidy -xml | grep '<name>' | sed -n 's|<name>\(.*\)</name>|\1|p' | grep -x "New"
if [ $? != 0 ]
then
	curl -H "Content-Type: application/xml" -u $apiusername:$apipassword https://${jssurl}/JSSResource/categories/id/0 -d "<category><name>New</name></category>" -X POST
fi
 
# Mount the Distribution Point
sudo mkdir /Volumes/rDisk
sudo mount -t afp afp://${dpusername}:${dppassword}@${dphostname}/${dpsharename} /Volumes/rDisk

# Get the list of packages from the DP and put them into a text file located /tmp/dbpackages.txt
ls /Volumes/rDisk/Packages > /tmp/dbpackages.txt

# Unmount the Distribution Point
umount /Volumes/rDisk/

# Get the list of packages from the JSS and put them into a text file located /tmp/jsspackages.txt
# Start by getting the IDs of all the packages within the JSS and putting them into the "id" array 
# utilizing the API
var=$(curl -u $apiusername:$apipassword https://${jssurl}/JSSResource/packages -X GET | tidy -xml | grep '<id>' | sed -n 's|<id>\(.*\)</id>|\1|p')
id=($var)
idn=${#id[@]}

# Then create a while loop that makes a call to the API for each value in the "id" array, and adds the 
# value to /tmp/jsspackages.txt
n=0
while [ $n -lt $idn ]
do
	curl -u $apiusername:$apipassword https://${jssurl}/JSSResource/packages/id/${id[$n]} -X GET | tidy -xml | grep 'filename' | sed -n 's|<filename>\(.*\)</filename>|\1|p' >> /tmp/jsspackages.txt
	n=$((n+1))
done

# Then compare the two text files for differences, and put those differences into the addpackages array	
var3=$(grep -Fxv -f /tmp/jsspackages.txt /tmp/dbpackages.txt)
addpackages=($var3)
ln=${#addpackages[@]}

# A while loop that goes through each value of the addpackages array and uses the API to create those packages.
# It also creates a unique name that strips off the filename extension, and puts it in the "New" Category
n=0
while [ $n -lt $ln ]
do
	curl -H "Content-Type: application/xml" -u $apiusername:$apipassword https://${jssurl}/JSSResource/packages/id/0 -d "<package><name>${addpackages[$n]%.*}</name><category>New</category><filename>${addpackages[$n]}</filename></package>" -X POST
	n=$((n+1))
done

# Remove the two text files we created
rm /tmp/jsspackages.txt
rm /tmp/dbpackages.txt
exit 0