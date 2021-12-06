#!/usr/bin/bash

# CURL VARIABLES
CURL='/usr/bin/curl'
URL='http://169.254.169.254/latest/meta-data/public-ipv4'
OPTIONS='-s'

#HOSTED ZONE
hostedZones=''
declare -a HZids
declare -a HZnames
hosted=''

#JSON OPTIONS
BASE_DIRECTORY_FOR_JSON='/etc/SubdomainAutomation/sites-enabled/*'

#FUNCTIONS
parseZones() {
	while read -r Data; do
	local x=0
        IFS="|"
        local id=""
        local name=""
        for infoX in $Data
        do 
	    if [ $x == 0 ]; then 
		id="${infoX##*/}"
	    fi
	    if [ $x == 1 ]; then
		name=$infoX
	    fi
	    if [ $x == 2 ]; then
    		if [ $infoX == "false\"" ]; then
		    HZids[y++]="$id";
		    HZnames[z++]="${name%.*}";
		fi
	    fi
	    (( x=x+1 ))
	done
    done < <(echo $hostedZones | jq '.HostedZones[] | "\(.Id)|\(.Name)|\(.Config.PrivateZone)"')
}


get_doms() {
	for f in $BASE_DIRECTORY_FOR_JSON
    do
        jq '.Changes[0].ResourceRecordSet.ResourceRecords[0].Value = $a' --arg a $1  $f > /etc/SubdomainAutomation/temp/temp.json
		value=$(jq '.Changes[0].ResourceRecordSet.Name' $f)
		for((x=0;x<${#HZnames[@]};x++)); do
		
			if [[ "$value" == *"${HZnames[$x]}"* ]]; then
				hosted="${HZids[$x]}"
				aws route53 change-resource-record-sets --hosted-zone-id $hosted --change-batch file:///etc/SubdomainAutomation/temp/temp.json
			fi
		done
    done
}

if ! command -v aws &> /dev/null
then
    echo "Script requires the AWS CLI tools"
else
    if ! command -v jq &> /dev/null
    then
	echo 'Script requires jq for json parsing'
        echo "'sudo apt-get install jq' to install"
        exit
    else
        NEW_IP="$($CURL $OPTIONS $URL)"
		hostedZones=$(aws route53 list-hosted-zones)
		echo 'here'
		parseZones
        get_doms $NEW_IP
    fi
fi
