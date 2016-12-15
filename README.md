# Import Packages into JSS
Imports all packages in the Distribution Point that are not already in the JSS into the JSS

## NAME
importPackages.sh -- Imports all packages in the DP that are not already in the JSS into the JSS

## SYNOPSIS
There are three parameters used in this script: parameters 4, 5, and 6. Parameters 4 and 5 are used for the API Username and Password that will be used to grab the list of packages from the JSS. This API user needs CREATE, UPDATE and READ privileges for Packages and Categories in the JSS. 

Parameter 6 is used for the JSS URL. This must be written out with the FQDN as well as the port number. For instance, it should be written out like this:

zen01.jamf.com:8443    for most on premise installs, or
zen01.jamfcloud.com    if you are a cloud hosted customer, or have changed your port number to 443.
   
Parameters 7, 8, 9 and 10 are used to mount the Distribution Point. 7 and 8 are the username and password for a local user that needs READ privileges to the folder. 9 is the hostname of the server hosting the Distribution Point, and 10 is the name of the Shared Folder. 

Parameter 1, 2, and 3 will not be used in this script, but since they are passed by The Caspeer Suite, we will start using parameters at parameter 4. If no parameter is specified for either parameter 4 or 5, the hardcoded value in the script will be used.  If values are hardcoded in the script for the parameters, then they will override any parameters that are passed by The Casper Suite.

## DESCRIPTION
This script will take a list of all the packages within your distribution point and compare the filenames to the packages within the JSS. If there are any extra packages, it will add them into the JSS in a category called "New."

**_THIS SCRIPT MUST BE RUN AS ROOT_**
