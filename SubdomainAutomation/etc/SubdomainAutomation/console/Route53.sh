#!/usr/bin/bash



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
if ! command -v aws &> /dev/null
then
    echo "Script requires the AWS CLI tools"
fi


declare -a HZids
declare -a HZnames
declare -a currentRecords
declare -a Vhosts
y=1
z=1
SnC=''
NfN=''

hostedZones=$(aws route53 list-hosted-zones)
selectedHostedZone=''
selectedHostedZoneN=''

printTable()
{
    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                # Add Header Or Body

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}

removeEmptyLines()
{
    local -r content="${1}"

    echo -e "${content}" | sed '/^\s*$/d'
}

repeatString()
{
    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

isEmptyString()
{
    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

trimString()
{
    local -r string="${1}"

    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}



first_menu() {

    while read -r Data; do
	local x=0
        IFS="|"
        local id=""
        local name=""
        for infoX in $Data
        do 
	    if [ $x == 0 ]; then 
		id="${infoX##*/}"
#		echo $id
	    fi
	    if [ $x == 1 ]; then
		name=$infoX
	    fi
	    if [ $x == 2 ]; then
    		if [ $infoX == "false\"" ]; then
		    HZids[y++]="$id";
		    HZnames[z++]="$name";
		fi
	    fi
	    (( x=x+1 ))
	done
    done < <(echo $hostedZones | jq '.HostedZones[] | "\(.Id)|\(.Name)|\(.Config.PrivateZone)"')
}



show_first_menu() {
    echo -e "\n"
    echo -e "################\n"
    for((i=1;i<=${#HZids[@]};i++))
	do
	    echo -e "$i.)" "${HZnames[$i]} \n"
	done
    echo -e "$(expr ${#HZids[@]} + 1).) Cancel \n"
    echo "################"
    echo
    echo -e "${YELLOW}Which Hosted Zone will be used? ( 1 - $(expr ${#HZids[@]} + 1) ) ${CRESET}"
}
first_menu
selectZone="$(show_first_menu)"
echo "$selectZone"


first_menu_select() {
    local t=0
    while [[ $((input)) != $input ]] || [[ $((input)) > $(expr ${#HZids[@]} + 1) ]];do
#	echo "$input"
	if [ $t == 0 ]; then 
	    read input
	else
	    echo "$selectedZone"
	    read input

	fi	
	(( t=t+1 ))
    done

    
    if [[ $((input)) == $(expr ${#HZids[@]} + 1) ]]; then
		echo "Operation Canceled"
		echo
		exit
    else
		selectedHostedZone=${HZids[input]}
		selectedHostedZoneN=${HZnames[input]}
    fi
}

first_menu_select 

get_current_records() {
    #Incase we allow to do later
    currentRecords=()
    count=$(aws route53 list-resource-record-sets --hosted-zone-id $selectedHostedZone | jq '.ResourceRecordSets | length')
    data=$(aws route53 list-resource-record-sets --hosted-zone-id $selectedHostedZone)
	heading='Name,Type,Value\n'
	records=$(echo $data | jq --raw-output '.ResourceRecordSets[] | "\(.Name),\(.Type),\(.ResourceRecords[0].Value)"')
	results=${heading}${records}
    printTable ',' $results
    
}

start_new_creation() {
	#determine what we are using for apache apache2ctl or httpd
	echo -e "\n\n"
	local endStatement="${selectedHostedZoneN%%.*}.json"
	declare -a ExistingUpdates
	local cmd_results
	local cmd_results2
	local i=1
	if command -v httpd &>/dev/null
	then
		cmd_results=$(httpd -t -D DUMP_VHOSTS | grep 'namevhost' | grep "$selectedHostedZoneN")
		if [ -z "$cmd_results" ]; then 
			echo -e "\n${RED}No named VHOST's found, create a VHOST for the site with the hosted zone in the ServerName <subdomain>.hostedzone then run this command again. ${CRESET} \n"
			exit
		fi
		while read -r Help; do
			#echo $Help
			Vhosts[i++]="$Help"
		done <<< $cmd_results

		i=0
		for d in /etc/SubdomainAutomation/sites-available/*
		do 
			if [[ "${d##*/}" == *"$endStatement"* ]]; then
				for((x=0;x<${#Vhosts[@]};x++)); do
					local ytrim="${Vhosts[$x]%.*}"
					ytrim=$(tr '.' '-' <<< $ytrim)
					ytrim="$ytrim.json"
					if [[ "$ytrim" == "${d##*/}" ]];then
						unset Vhosts[$x]
						Vhosts=( "${Vhosts[@]}" )
					fi
				done
				#ExistingUpdates[i++]="${d##*/}"
				if [[ ${#Vhosts[@]} == 0 ]]; then 
					echo -e "${YELLOW}No VHOST's found that can be assigned for the Route 53 Update process.  No VHOSTS available, or all already created.${CRESET}"
					exit
				else
					echo -e "################\n"
					for((i=0;i<${#Vhosts[@]};i++))
					do
						echo -e "$(expr $i + 1).)" "${Vhosts[$i]} \n"
					done
					echo -e "$(expr ${#Vhosts[@]} + 1).) Cancel \n"
					echo "################"
					echo
					echo -e "${YELLOW}Which VHOST will be used? ( 1 - $(expr ${#Vhosts[@]} + 1) ) ${CRESET}"
				fi
			fi
		done

	elif command -v apache2ctl &>/dev/null 
	then
		cmd_results=$( apache2ctl -t -D DUMP_VHOSTS | grep 'namevhost' | grep "$selectedHostedZoneN" | awk '{print $4}')
		if [ -z "$cmd_results" ]; then 
			echo -e "\n${RED}No named VHOST's found, create a VHOST for the site with the hosted zone in the ServerName <subdomain>.hostedzone then run this command again. ${CRESET} \n"
			exit
		fi
		while read -r Help; do
			#echo $Help
			Vhosts[i++]="$Help"
		done <<< $cmd_results
		
		i=0
		for d in /etc/SubdomainAutomation/sites-available/*
		do 
			if [[ "${d##*/}" == *"$endStatement"* ]]; then
				for((x=0;x<${#Vhosts[@]};x++)); do
					local ytrim="${Vhosts[$x]%.*}"
					ytrim=$(tr '.' '-' <<< $ytrim)
					ytrim="$ytrim.json"
					if [[ "$ytrim" == "${d##*/}" ]];then
						unset Vhosts[$x]
						Vhosts=( "${Vhosts[@]}" )
					fi
				done
				#ExistingUpdates[i++]="${d##*/}"
				if [[ ${#Vhosts[@]} == 0 ]]; then 
					echo -e "${YELLOW}No VHOST's found that can be assigned for the Route 53 Update process.  No VHOSTS available, or all already created.${CRESET}"
					exit
				fi
			fi
		done
		SnC="$(new_creation_menu)"
		echo "$SnC"
	else
		echo 'Apache must be installed, either the httpd or apache2ctl command must exist!'
		exit
	fi
	
	
	#get the apache records w/ the selected option's name
	
}
new_creation_menu() {
	echo -e "################\n"
	for((i=0;i<${#Vhosts[@]};i++))
	do
		echo -e "$(expr $i + 1).)" "${Vhosts[$i]} \n"
	done
	echo -e "$(expr ${#Vhosts[@]} + 1).) Cancel \n"
	echo "################"
	echo
	echo -e "${YELLOW}Which VHOST will be used? ( 1 - $(expr ${#Vhosts[@]} + 1) ) ${CRESET}"
}
activate_now() {
	echo -e "\n"
	echo $NfN
	nFolder="/etc/SubdomainAutomation/sites-available/${NfN}"
	sFolder="/etc/SubdomainAutomation/sites-enabled/${NfN}"
	echo -e "${YELLOW}Activate site auto dns update? \n ${RED} This will create the record if it does not exist on next reboot of the EC2 Instance. ${CRESET}" 
	select yn in "Yes" "No"; do 
		case $yn in
			Yes ) $(ln -s $nFolder $sFolder ); echo -e "${GREEN} Activated ${CRESET}"; break;;
			No ) exit;;
		esac
	done
}
picking_my_vhost() {
	local t=0
	input=''
    while [[ $((input)) != $input ]] || [[ $((input)) > $(expr ${#Vhosts[@]} + 1) ]];do
#	echo "$input"
	if [ $t == 0 ]; then 
	    read input
	else
	    echo "$SnC"
	    read input

	fi	
	(( t=t+1 ))
    done
	if [[ $((input)) == $(expr ${#Vhosts[@]} + 1) ]]; then 
		echo "Operation Canceled"
		echo
		exit
	else
		fix_number=$(expr $input - 1)
		value="${Vhosts[$fix_number]%[*}"
		local ytrim="${Vhosts[$fix_number]%.*}"
		ytrim=$(tr '.' '-' <<< $ytrim)
		ytrim="$ytrim.json"
		filename="$ytrim"
		NfN="$filename"
		$(cp /etc/SubdomainAutomation/sites-available/test.json /etc/SubdomainAutomation/sites-available/$filename)
		$(sed -i "s/record to reflect/$value record to reflect/g" /etc/SubdomainAutomation/$filename)
		$(sed -i "s/test.domain/$value/g" /etc/SubdomainAutomation/sites-available/$filename)
		activate_now
	fi
}


second_menu() {
    echo -e "\n"
    echo -e "################\n"
    echo "1.) View Current Records"
    echo "2.) Create new update record (Apache)"
    echo "3.) Cancel"
    echo
    echo -e "################\n"
    echo
    echo -e "${YELLOW} What would you like to do? ${CRESET}"
}
second_menu_select() {
    local t=0
    input=''
    while [[ $((input)) != $input ]] || [[ $((input)) > 3 ]];do
	if [ $t == 0 ]; then
	    read input
	else
	    second_menu
	    read input
	fi
	((t=t+1))
    done
	
    if [[ $((input)) == 3 ]]; then
		echo "Operation Canceled"
		echo
		exit
    else
		if [[ $((input)) == 1 ]]; then
			get_current_records
		fi
		if [[ $((input)) == 2 ]]; then 
			start_new_creation
		fi
    fi    
}

second_menu
second_menu_select
picking_my_vhost




