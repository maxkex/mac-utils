#!/bin/bash

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Function to get the system volume name
get_system_volume() {
    system_volume=$(diskutil info / | grep "Device Node" | awk -F': ' '{print $2}' | xargs diskutil info | grep "Volume Name" | awk -F': ' '{print $2}' | tr -d ' ')
    echo "$system_volume"
}

# Get the system volume name
# system_volume=$(get_system_volume) # sometimes not retruning system volume. need to debug later
system_volume="Data" #usual case for freshly reinstalled system is "Macintosh HD - Data"
    if [ -d "/Volumes/Macintosh HD - Data"]; then
        diskutil rename "Macintosh HD - Data" "Data"
    fi
# Display header
echo -e "${CYAN}Bypass MDM script${NC}"
echo ""
echo -e "${GRN}system volume: $system_volume"
ls -al "/Volumes/"
echo ""
# Prompt user for choice
PS3='Select: '
options=("Bypass MDM in Recovery" "Disable Notification (SIP)" "Disable Notification (Recovery)" "Check MDM Enrollment" "Reboot & Exit")
select opt in "${options[@]}"; do
    case $opt in
        "Bypass MDM in Recovery")
            # Bypass MDM from Recovery
            echo -e "${YEL}Bypass MDM in Recovery"

            # Create Temporary User
            echo -e "${NC}Create a Temporary User"
            read -p "Enter Temporary Fullname (Default is 'FixUser'): " realName
            realName="${realName:=FixUser}"
            read -p "Enter Temporary Username (Default is 'FixUser'): " username
            username="${username:=FixUser}"
            read -p "Enter Temporary Password (Default is '12345'): " passw
            passw="${passw:=1234}"

            # Create User
            dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
            echo -e "${GREEN}Creating Temporary User"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"
            mkdir "/Volumes/Data/Users/$username"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
            dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$passw"
            dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership $username

            # Block MDM domains
            echo "0.0.0.0 deviceenrollment.apple.com" >>/Volumes/"$system_volume"/etc/hosts
            echo "0.0.0.0 mdmenrollment.apple.com" >>/Volumes/"$system_volume"/etc/hosts
            echo "0.0.0.0 iprofiles.apple.com" >>/Volumes/"$system_volume"/etc/hosts
            echo -e "${GRN}Successfully blocked MDM & Profile Domains"

            # Remove configuration profiles
            touch /Volumes/Data/private/var/db/.AppleSetupDone
            rm -rf /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
            rm -rf /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
            touch /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
            touch /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound

            echo -e "${GRN}MDM enrollment has been bypassed!${NC}"
            echo -e "${NC}Exit terminal and reboot your Mac.${NC}"
            break
            ;;
        "Disable Notification (SIP)")
            echo -e "${RED}Enter Password To Proceed${NC}"
            rm /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
            rm /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
            touch /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
            touch /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
            break
            ;;
        "Disable Notification (Recovery)")
            rm -rf /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
	        rm -rf /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
	        touch /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
	        touch /Volumes/"$system_volume"/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound

            break
            ;;
        "Check MDM Enrollment")
		    echo ""
		    echo -e "${GRN}Check MDM Enrollment. Error is success${NC}"
		    echo ""
		    echo -e "${RED}Enter Password To Proceed${NC}"
		    echo ""
		    profiles show -type enrollment
		    break
		    ;;
        "Reboot & Exit")
            # Reboot & Exit
            echo "Rebooting..."
            reboot
            break
            ;;
        *) echo "Invalid option $REPLY" ;;
    esac
done
