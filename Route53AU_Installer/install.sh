#!/usr/bin/bash

############
	# Author: James F
	# Purpose: Configure Auto DNS resolution for "DHCP" leased public IPs on AWS
	# Action: Installs scripts to automatically configure these changes.
############

#Script Working Directory
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

#Color Codes
RED="\e[31m";
GREEN="\e[32m";
YELLOW="\e[33m";
CRESET="\e[0m";

if (( $EUID != 0 )); then
	echo "################"
    echo -e "${RED}This script requires super user permissions.  Please run as root.${CRESET}"
	echo "################"
    exit
fi

AWS_exists=0
AWS_config=0
JQ_exists=0

AWS_CHECK() {
	#lets check if the cli is installed first
	if ! command -v aws &> /dev/null
	then
		echo "AWS CLI is not installed"
	else
		(( AWS_exists=AWS_exists+1 ))
		#check if its configured
		if [ -f "/root/.aws/credentials" ]; then 
			if [ -f "/root/.aws/config" ]; then
				(( AWS_config=AWS_config+1 ))
			else
				echo "Could not find AWS CLI config file under root user".
			fi
		else
			echo "Could not find AWS CLI credentials file under root user".
		fi
	fi
}
JQ_CHECK() {
	if ! command -v jq &> /dev/null
    then
		echo "Could not find jq for json parsing."
	else
		JQ_exists=1
    fi
}


AWS_CHECK
JQ_CHECK

INSTALL_COMPLETE() {
	echo -e "################\n"
	echo -e "${GREEN} Installation Complete ${CRESET}"
	echo "################"
	echo
	echo -e "${YELLOW} Run 'sudo Route53' to set up managed records ${CRESET}"
}

START_INSTALL() {
	#Move service daemon to systemd directory
	$(cp "$SCRIPT_DIR/updateRoute53.service" /etc/systemd/system/updateRoute53.service)
	#Move the shell command for adding new records
	$(cp "$SCRIPT_DIR/Route53" /usr/local/bin/Route53)
	#extract the tar into position
	$(tar -xzvf "$SCRIPT_DIR/SubdomainAutomation.tar.gz" -C /)
	
	#Modify all permissions incase they didnt move over
	$(chmod 644 /etc/systemd/system/updateRoute53.service)
	$(chmod 755 -R /etc/SubdomainAutomation)
	$(chmod 777 /usr/local/bin/Route53)
	
	#Create service log area
	$(mkdir /var/log/custom_script_logs && chmod 754 /var/log/custom_script_logs)
	$(touch /var/log/custom_script_logs/Route53Update.log && chmod 644 /var/log/custom_script_logs/Route53Update.log)
	$(touch /var/log/custom_script_logs/Route53Update_error.log && chmod 644 /var/log/custom_script_logs/Route53Update_error.log)
	
	#Activate the service
	$(systemctl enable updateRoute53.service)
	
	INSTALL_COMPLETE
}




if [[ $AWS_exists == 0 ]]; then
	#Hey we need to install it
	echo -e "\n${RED} Please install the AWS CLI ${CRESET} \n https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cliv2-linux-install \n"
	exit
fi
if [[ $AWS_config == 0 ]]; then
	echo -e "\n${RED} Please run ${CRESET} sudo aws configure ${RED} and set your AWS CLI credentials. \n ${CRESET}"
	exit
fi	

if [[ $JQ_exists != 1 ]]; then 
	echo -e "${RED}Script requires jq for json parsing.${CRESET}"
	echo "Debian/Ubuntu : 'sudo apt-get install jq' to install"
	exit
fi
echo -e "\n All pre-requisites passed."
echo -e "${YELLOW} Install package? ${CRESET}" 
select yn in "Yes" "No"; do 
	case $yn in
		Yes ) START_INSTALL; break;;
		No ) exit;;
	esac
done

	