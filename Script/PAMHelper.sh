#!/bin/bash
# Helper script to configure PAM modules.

# Default settings for program.
DIRECTORY="/etc/pam.d/"
FILE="common-auth"
# Estas dos variables tienen que ser arrays de USB's
USBSERIALS=()
USBPRODUCTS=()
USERSELECTEDUSBDRIVESERIAL=""
USERSELECTEDUSBDRIVEPRODUCT=""
AUTHRULE=""
CONTROL=""
CONFIGFILELINENUMBER=""

# Prints the script settings, to check with user that data is correct
printScriptSettings () {
  echo   
  echo "----------------Script settings----------------"
  echo PAM Configuration directoy: "${DIRECTORY}"
  echo PAM Configuration file: "${FILE}"
  echo "         USB-related configuration:"
  echo USB serial number: $USERSELECTEDUSBDRIVESERIAL
  echo USB drive product: $USERSELECTEDUSBDRIVEPRODUCT
  echo "----------------Script settings----------------"
  echo
}

# Compose rule out of the information we have
makeAuthRule () {
  AUTHRULE="auth "${CONTROL}" pam_usbkey.so user=* tty=* key=${USERSELECTEDUSBDRIVESERIAL}"
}

# Prints important lines on config file
printConfigFile () {
# Print every line and it's line number not commented (#)
  grep -n "^[^#]" "${COMPLETEFILE}"
  read -p "What line do you want to add the PAM rule to?"
  echo
  if [ ! -n "${REPLY//[0-9]/}" ]; then
    CONFIGFILELINENUMBER="${REPLY}"
    else echo "Non-numerical value introduced. Exiting..."; exit 1
  fi
}

# Writes auth rule to config file
writeConfigToFile () {
  sed -i "${CONFIGFILELINENUMBER}i\ ${AUTHRULE}" "${COMPLETEFILE}" 
}

# Print auth rule
printAuthRule () {
  echo "${AUTHRULE}"
}
# Asks user which type of control he wants.
getControl () {
  echo "Now, you have to select the control of your config."
  echo "There are two main types you can use, required and sufficient"
  echo "0) required"
  echo "     failure of such a PAM will ultimately lead to the PAM-API"
  echo "     returning failure but only after the remaining stacked modules" 
  echo "     (for this service and type) have been invoked."
  echo "1) sufficient"
  echo "     If such module succeeds and no prior required module has failed"
  echo "     the PAM framework returns success to the application or the" 
  echo "     superior PAM stack immediatley without calling any further modules" 
  echo "     in the stack. A failure of a sufficient module is ignored and"
  echo "     processing of the PAM module stack continues unaffected."
  
  read -p "What control do you want?" -n 1 -r
  echo
  if [ ! -n "${REPLY//[0-9]/}" ]; then
    if [ "${REPLY}" == "0" ]; then
      CONTROL="required"
      elif [ "${REPLY}" == "1" ]; then
        CONTROL="sufficient"
    fi
    else echo "Control sentence not recognised, Exiting..."; exit 1
  fi
}

# Select a USB drive to use with this script
selectUSBDrive () {
  listUSBDevices
  read -p "Select the USB device you want to use: " -n 1 -r
  echo
  # If the value introduced is a number, assign the values
  # if not, exit with exit code 1
  # TODO: Check if value entered is in range
  if [[ ! -n "${REPLY//[0-9]/}" ]]; then
    USERSELECTEDUSBDRIVESERIAL="${USBSERIALS["${REPLY}"]}"
    USERSELECTEDUSBDRIVEPRODUCT="${USBPRODUCTS["${REPLY}"]}"
    else echo "Non-numeric value, Exiting..."; exit 1
  fi
    
}
# Lists USB devices
listUSBDevices () {
  for (( i=0; i<"${#USBSERIALS[@]}"; i++ )); do
    echo " "$i") Serial=${USBSERIALS["$i"]} Product=${USBPRODUCTS["$i"]}"
  done
}

# Stores USB devices present in the system
getUSBInfo () {
  for DEV in /sys/bus/usb/devices/* ; do
    if [ -e "${DEV}/bDeviceClass" ]; then
      CLASS=$(cat "${DEV}/bDeviceClass")
      if [ "${CLASS}" = "00" ] || [ "${CLASS}" = "08" ]; then
        usbproduct=$(cat "${DEV}/product" 2> /dev/null)
        usbserial=$(cat "${DEV}/serial" 2> /dev/null)
	if [ ! -z "${usbproduct}" ] && [ ! -z "${usbserial}" ]; then
	  # Add device specs to arrays.
	  USBPRODUCTS+=("$usbproduct")
	  USBSERIALS+=("$usbserial")
	fi
      fi
    fi
  done
}
# Function that prints usage of program/script
printHelp () {
  echo
  echo "This is a configuration helper script for PAM"
  echo "With this script you will be able to:"
  echo "  1. View available configuration files and their content"
  echo "  2. Configure the file you need with the pam_usbkey.so module"
  echo "     in order to authenticate with a USB stick."
  echo "  3. Remove the pam_usbkey.so configuration from the file specified"
  echo
}

# Function that prints disclaimer
printDisclaimer () {
  echo
  echo "--------------------Disclaimer--------------------"
  echo "The program will now operate with theese settings:"
  echo "If these settings are wrong, exit the program and"
  echo "Set the settings correctly. A bad configuration"
  echo "May lock you out from your computer"
  echo "--------------------Disclaimer--------------------"
  echo 
}

# Parse program arguments
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    printHelp
    exit 0
    shift
    ;;
    -d|--directory)
    DIRECTORY="$2"  
    shift # past argument
    shift # past value
    ;;
    -f|--file)
    FILE="$2"
    shift
    shift
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Start of program logic
printDisclaimer
printScriptSettings
# Ask user if he wants to continue
read -p "Do you want to continue? [Yy]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then # Main program
  COMPLETEFILE="${DIRECTORY}${FILE}"
  read -p "Enter your USB stick now. Press RETURN when it's done."
  getUSBInfo
  selectUSBDrive
  printScriptSettings
  getControl
  makeAuthRule
  printAuthRule
  printConfigFile
  printScriptSettings
  read -p "Do you want to continue? [Yy]" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then # Write line to file
    writeConfigToFile
  fi
fi
