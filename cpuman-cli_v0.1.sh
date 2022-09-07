#!/bin/bash
# name          : cpuman-cli
# desciption    : manage cpu cores and powerstatus of cpu
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 0.1
# notice 	: 
# infosource	: https://askubuntu.com/questions/1185826/how-do-i-disable-a-specific-cpu-core-at-boot
#
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 RequiredPackets="bash sed awk"
 Version=$(cat $0 | grep "# version" | head -n1 | awk -F ":" '{print $2}' | sed 's/ //g')
 ScriptName=$(basename $0)

#------------------------------------------------------------------------------------------------------------
############################################################################################################
########################################   set vars from options  ##########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	OptionVarList="

		ProcessingCPUCores;-c
		ProcessingCPUStatus;-p
		HelpDialog;-h
		Monochrome;-m
		ScriptInformation;-si
		CheckForRequiredPackages;-cfrp

	"
	# set entered vars from optionvarlist
	OptionAllocator=" "										# for option seperator "=" use cut -d "="
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
 	for InputOption in $(echo " $@" | sed -e 's/-[a-z]/\n\0/g' ) ; do  				# | sed 's/ -/\n-/g'
		for VarNameVarValue in $OptionVarList ; do
			VarName=$(echo "$VarNameVarValue" | cut -d ";" -f1)
			VarValue=$(echo "$VarNameVarValue" | cut -d ";" -f2)
			if [[ $InputOption == "$VarValue" ]]; then
				eval $(echo "$VarName"='$InputOption')					# if [[ -n Option1 ]]; then echo "Option1 set";fi
				#eval $(echo "$VarName"="true")
			elif [[ $(echo $InputOption | cut -d "$OptionAllocator" -f1) == "$VarValue" ]]; then	
				eval $(echo "$VarName"='$(echo $InputOption | cut -d "$OptionAllocator" -f 2-10)')
			fi
		done
	done
	IFS=$SAVEIFS
#------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
load_color_codes () {
	Black='\033[0;30m'	&&	DGray='\033[1;30m'
	LRed='\033[0;31m'	&&	Red='\033[1;31m'
	LGreen='\033[0;32m'	&&	Green='\033[1;32m'
	LYellow='\033[0;33m'	&&	Yellow='\033[1;33m'
	LBlue='\033[0;34m'	&&	Blue='\033[1;34m'
	LPurple='\033[0;35m'	&&	Purple='\033[1;35m'
	LCyan='\033[0;36m'	&&	Cyan='\033[1;36m'
	LLGrey='\033[0;37m'	&&	White='\033[1;37m'
	Reset='\033[0m'
	# Use them to print in your required colours:
	# printf "%s\n" "Text in ${Red}red${Reset}, white and ${Blue}blue${Reset}."

	BG='\033[47m'
	FG='\033[0;30m'

	# reload colored global vars 
	for i in $(cat $0 | sed '/load_color_codes/q'  | grep '${Reset}'); do
		eval "$i"
	done
}
#------------------------------------------------------------------------------------------------------------
usage() {
	printf "\n"
	printf " Usage: $(basename $0) <options> "
	printf "\n"
	printf " -c <1-X>	=> used cpu cores \n"
	printf " -p		=> cpu powerstatus \n"
	printf " -h		=> help dialog \n"
	printf " -m		=> monochrome output \n"
	printf " -si		=> show script information \n"
	printf " -cfrp		=> check for required packets \n"
	printf  "\n${LRed} $1 ${Reset}\n"
	printf "\n"
	exit
}
#------------------------------------------------------------------------------------------------------------
script_information () {
	printf "\n"
	printf " Scriptname: $ScriptName\n"
	printf " Version:    $Version \n"
	printf " Location:   $(pwd)/$ScriptName\n"
	printf " Filesize:   $(ls -lh $0 | cut -d " " -f5)\n"
	printf "\n"
	exit 0
}
#------------------------------------------------------------------------------------------------------------
check_for_required_packages () {

	InstalledPacketList=$(dpkg -l | grep ii)

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w $Packet <<< $InstalledPacketList) ]]; then
			MissingPackets="$MissingPackets $Packet"
   		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf  "missing packets: ${LRed}  $MissingPackets ${Reset} \n"
		read -e -p "install required packets ? (Y/N) "	-i "Y" 	InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf  "programm error: ${LRed} missing packets : $MissingPackets ${Reset} \n"
			exit 1
		fi

	else
		printf "${LGreen} all required packets detected ${Reset}\n"
	fi
}

#------------------------------------------------------------------------------------------------------------
core_manager () {

	CPUCoreList=$(grep -E 'processor|core id' /proc/cpuinfo | sed 's/processor/\nprocessor/g')
	CPUCoreCount=$(($(grep "core id" /proc/cpuinfo | tail -n1 | awk -F ": " '{print $2}')+1))
	ProcessorCount=$(($(grep "processor" /proc/cpuinfo | tail -n1 | awk -F ": " '{print $2}')+1))

	# check for hyperthreading
	CPUHyperThread=disabled
	if [[ ! $CPUCoreCount == $ProcessorCount ]]; then
		CPUHyperThread=enabled
	fi

	# print machine specs
	printf " detected CPU cores:       $CPUCoreCount \n"
	printf " detected processors:      $ProcessorCount \n"
	printf " CPU hyperthreading:       $CPUHyperThread \n"
	
	# check for correct cpu core input
	if [[ $ProcessingCPUCores -gt $CPUCoreCount ]]; then
		usage " entered cores:   $ProcessingCPUCores \n  available cores: $CPUCoreCount \n"	
	fi
#
#echo "$CPUCoreList" | grep -B1 "core id.*$1"

echo 
#echo "A$CPUCoreCount"
#echo "B$ProcessingCPUCores"
#echo "$CPUCoreList"

	# processing cpu cores
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for i in $(seq 0 1 $(($ProcessingCPUCores-1)) ); do
		printf " disable core $(($i+1)) "
		printf " processor $CPUCoreList" | grep -B1 "core id.*$i" | awk -F ": " '{printf $2}'
		printf "\n\n"



	done
	IFS=$SAVEIFS




#grep -a1 "core id.*3" $CPUCoreList | grep processor



exit



echo core



grep -E 'processor|core id' /proc/cpuinfo


for x in /sys/devices/system/cpu/cpu[1-9]*/online; do   echo 1 >"$x"; done


for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "powersave" > $file; done











}
#------------------------------------------------------------------------------------------------------------
power_manager () {
echo power

}





#------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	# check for cronjob execution and cronjob options
	CronExecution=
	if [ -z $(grep "/" <<< "$(tty)") ]; then
		CronExecution=true
		Monochrome=true		
	fi

#------------------------------------------------------------------------------------------------------------

	# check for monochrome output
	if [[ -z $Monochrome ]]; then
		load_color_codes
	fi

#------------------------------------------------------------------------------------------------------------

	# check help dialog
	if [[ -n $HelpDialog ]] || [[ -z $1 ]]; then usage "help dialog" ; fi

#------------------------------------------------------------------------------------------------------------

	# check for script information
	if [[ -n $ScriptInformation ]]; then script_information ; fi

#------------------------------------------------------------------------------------------------------------

	# check for root permission
	if [ "$(whoami)" = "root" ]; then echo "";else echo "Are You Root ?";exit 1;fi

#------------------------------------------------------------------------------------------------------------

	# check for required package
	if [[ -n $CheckForRequiredPackages ]]; then check_for_required_packages; fi

#------------------------------------------------------------------------------------------------------------

	# manage cpu cores
	if [[ -n $ProcessingCPUCores ]]; then core_manager; fi

#------------------------------------------------------------------------------------------------------------

	# manage cpu powerstatus
	if [[ -n $ProcessingCPUStatus ]]; then power_manager; fi

#------------------------------------------------------------------------------------------------------------



#------------------------------------------------------------------------------------------------------------

exit 0




#infosource 
#grep -E 'processor|core id' /proc/cpuinfo
#for x in /sys/devices/system/cpu/cpu[1-9]*/online; do   echo 1 >"$x"; done
#for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "powersave" > $file; done











