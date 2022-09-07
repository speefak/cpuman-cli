#!/bin/bash
# name          : cpuman-cli
# desciption    : manage cpu cores and powerstatus of cpu
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 0.5
# notice 	: 
# infosource	: https://askubuntu.com/questions/1185826/how-do-i-disable-a-specific-cpu-core-at-boot
#
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 RequiredPackets="bash sed awk"




 MaxCPUs=$(($(cat /sys/devices/system/cpu/present | cut -d "-" -f2)+1)) #ls /sys/devices/system/cpu/ |grep -c ^cpu[[:digit:]]
 SystemStatusHyperthread=$(cat /sys/devices/system/cpu/smt/control)
 Version=$(cat $0 | grep "# version" | head -n1 | awk -F ":" '{print $2}' | sed 's/ //g')
 ScriptName=$(basename $0)

#------------------------------------------------------------------------------------------------------------
############################################################################################################
########################################   set vars from options  ##########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	OptionVarList="

		ShowSystemSpecs;-ss
		DisableCore;-dc
		DisableCPU;-dp
		DisableHT;-dh
		EnableCore;-ec
		EnableCPU;-ep
		EnableHT;-eh


		CoreConfig;-c
		CPUConfig;-p
		HTconfig;-t

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
	printf " -ss			=> show system specifications \n"
	printf " -[e|d]c <1,2-3,4>	=> (e)nable (d)isable core \n"
	printf " -[e|d]p <1,4-5,8>	=> (e)nable (d)isable cpu \n"		
	printf " -[e|d]h 		=> (e)nable (d)isable hyperthreading \n"
#	printf " -c <1-X>	=> active cores \n"
#	printf " -p <1-$MaxCPUs>	=> active cpus \n"
#	printf " -t <1|0>	=> enable|disable HTconfig \n"
	printf " -h			=> help dialog \n"
	printf " -m			=> monochrome output \n"
	printf " -si			=> show script information \n"
	printf " -cfrp			=> check for required packets \n"
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
get_system_specs () {

	# get core status
	echo " MaxCPUs=$(($(cat /sys/devices/system/cpu/present | cut -d "-" -f2)+1)) "
	echo " HyperthreadStatus=$(cat /sys/devices/system/cpu/smt/control) "

	# get cpu status 
	for i in /sys/devices/system/cpu/cpu[0-99]*; do

		CPUNumber=$(echo $i | awk -F "/cpu/cpu" '{printf $2}' | tr -d "/")
		CoreNumber=$(cat /proc/cpuinfo | grep  -A11  "processor.*$CPUNumber" | tail -n1 | awk -F ": " '{printf $2}')
		CoreNumber=${CoreNumber:-X}

		printf " CPU=$CPUNumber Core=$CoreNumber"
		if [[ $CPUNumber == 0 ]]; then
			printf " OnlineStatus=1"
		else
			printf " OnlineStatus=$(cat $i/online)"
		fi
		printf " GovernorStatus=$(cat $i/cpufreq/scaling_governor)"
		printf "\n"
	done 
}
#------------------------------------------------------------------------------------------------------------
print_system_specs () {

	# print and parse output
	printf "$(echo "$SystemSpecList\n\n" |\
	sed 's/OnlineStatus=0/\\033[0;31moffline\\033[0m/g' |\
	sed 's/OnlineStatus=1/\\033[0;32m online\\033[0m/g' |\
	sed 's/GovernorStatus=//g' )"
}
#------------------------------------------------------------------------------------------------------------
processing_core_options () {					# usage: processing_core_options (set vars before function execution)

 edit_configuration_var () {					# usage: edit_configuration_var <e|d> <1|2-3|2-3,4|...>
	# processing ProcessingCoreList
	for CoreNumber in $2 ;do

		# processing input var OnlineStatus
		printf " Core $CoreNumber "
		if   [[ $1 == d ]]; then CoreStatus=0 && printf "disabled \n"
		elif [[ $1 == e ]]; then CoreStatus=1 && printf "enabled \n"
		fi

		# edit systemSpecList
		SystemSpecList=$(sed '/Core='$CoreNumber'/s/OnlineStatus=[0-9]/OnlineStatus='$CoreStatus'/' <<< $SystemSpecList )
	done
 }

	# check for mode ( enable ) / calculate processing core numbers
	for i in $EnableCore ; do
		ProcessingCoreList=$(	sed 's/,/ /g' <<< "$i" | tr " " "\n" | grep -v "-" 						
					seq $(sed 's/,/ /g' <<< "$i" | tr " " "\n" | grep "-" | tr "-" " ") 2>/dev/null )
		edit_configuration_var "e" "$ProcessingCoreList"
	done

	# check for mode ( disable ) / calculate processing core numbers
	for i in $DisableCore ; do
		ProcessingCoreList=$(	sed 's/,/ /g' <<< "$i" | tr " " "\n" | grep -v "-" 						
					seq $(sed 's/,/ /g' <<< "$i" | tr " " "\n" | grep "-" | tr "-" " ") 2>/dev/null )
		edit_configuration_var "d" "$ProcessingCoreList"
	done

	# processing input var GovernorStatus
	# TODO
}
#------------------------------------------------------------------------------------------------------------
processing_cpu_options () {					# usage: processing_cpu_options (set vars before function execution)

 edit_configuration_var () {					# usage: edit_configuration_var <e|d> <1|2-3|2-3,4|...>
	# processing ProcessingCPUList
	for CPUNumber in $2 ;do

		# processing input var OnlineStatus
		printf " cpu $CPUNumber "
		if   [[ $1 == d ]]; then CPUStatus=0 && printf "disabled \n"
		elif [[ $1 == e ]]; then CPUStatus=1 && printf "enabled \n"
		fi

		# edit systemSpecList
		SystemSpecList=$(sed '/CPU='$CPUNumber'/s/OnlineStatus=[0-9]/OnlineStatus='$CPUStatus'/' <<< $SystemSpecList )
	done
 }

	# check for mode ( enable ) / calculate processing CPU numbers
	for i in $EnableCPU ; do
		ProcessingCPUList=$(	sed 's/,/ /g' <<< "$i" | tr " " "\n" | grep -v "-" 						
					seq $(sed 's/,/ /g' <<< "$i" | tr " " "\n" | grep "-" | tr "-" " ") 2>/dev/null )
		edit_configuration_var "e" "$ProcessingCPUList"
	done

	# check for mode ( disable ) / calculate processing CPU numbers
	for i in $DisableCPU ; do
		ProcessingCPUList=$(	sed 's/,/ /g' <<< "$i" | tr " " "\n" | grep -v "-" 						
					seq $(sed 's/,/ /g' <<< "$i" | tr " " "\n" | grep "-" | tr "-" " ") 2>/dev/null )
		edit_configuration_var "d" "$ProcessingCPUList"
	done

	# processing input var GovernorStatus
	# TODO
}
#------------------------------------------------------------------------------------------------------------
processing_hyperthreading_options () {

	# check for hyperthreading support
	if [[ -n $(grep "notsupported" /sys/devices/system/cpu/smt/control)  ]]; then
		usage " hyperthreading not supported"
	fi

	# processing input var
	printf " hyperthreading "
	if   [[ -n $DisableHT ]]; then HTStatus=off && printf "disabled \n"
	elif [[ -n $EnableHT  ]]; then HTStatus=on  && printf "enabled \n"
	fi

	# edit systemSpecList
	SystemSpecList=$(sed 's/HyperthreadStatus=.*/HyperthreadStatus='$HTStatus'/' <<< $SystemSpecList)
	DisableCPU=$(seq $(($MaxCPUs/2)) 1 $(($MaxCPUs-1)))
	processing_cpu_options
	
	
}
#------------------------------------------------------------------------------------------------------------
####################################################################################################

core_manager () {

	# enable all available cores to get system infosmations
	for i in /sys/devices/system/cpu/cpu[0-99]*/online; do echo 1 >"$i" 2> /dev/null ; done

	CPUCoreList=$(grep -E 'processor|core id' /proc/cpuinfo | sed 's/processor/\nprocessor/g')
	CoreCount=$(($(grep "core id" /proc/cpuinfo | tail -n1 | awk -F ": " '{print $2}')+1))
	CPUCount=$(($(grep "processor" /proc/cpuinfo | tail -n1 | awk -F ": " '{print $2}')+1))

	# check for HTconfig
	CPUHyperThread=disabled
	if [[ ! $CoreCount == $CPUCount ]]; then
		CPUHyperThread=enabled
	fi

	# check for correct cpu core input # TODO check for letter input - deny letter input
	if [[ $CoreConfig -gt $CoreCount ]]; then
		usage " entered cores:   $CoreConfig \n  available cores: $CoreCount \n"	
	fi

	# print machine specs
	printf " detected CPU cores:  $CoreCount \n"
	printf " detected processors: $CPUCount \n"
	printf " CPU HTconfig:  $CPUHyperThread \n\n"
	
	# get core and processor informations
	for i in $(seq 0 1 $(($CoreConfig-1)) ); do

		EnabledProcessorsList=$(echo $EnabledProcessorsList $(echo "$CPUCoreList" | grep -B1 "core id.*$i" | awk -F "processor	:" '{printf $2}'))

		printf " enable CPU core:     $(($i+1)) \n"
		printf  "$CPUCoreList" | grep -B1 "core id.*$i" | grep processor |  sed 's/^/ enable /' | sed 's/	: /:    /'
		printf "\n\n"
	done

	# write processors config
	ProcessorConfigList=$(
	for DetectedProcessor in $(seq 0 1 $(($CPUCount-1))); do
		# skip processor 0, 1 processor has to be active in system
		if   [[ $DetectedProcessor == 0 ]]; then
			echo "processor $DetectedProcessor online"
		elif [[ -n $( grep -E $(sed 's/ /|/g' <<< $EnabledProcessorsList) 2>/dev/null <<< $DetectedProcessor) ]]; then
			echo "processor $DetectedProcessor online"	
		else 
			echo "processor $DetectedProcessor offline"
		fi
	done
	)
}
#------------------------------------------------------------------------------------------------------------
enable_processor_config () {
	
	# processing ProcessorConfigList
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for ProsessorConfigLine in $1; do

		ProcessorNumber=$( awk '{printf $2}' <<< $ProsessorConfigLine)

		# skip processor 0, 1 processor has to be active in system
		if [[ $ProcessorNumber == 0 ]]; then printf "processor $ProcessorNumber ${Green}online${Reset}\n" && continue ; fi

		# configure processors
		if [[ -n $( grep offline <<< "$ProsessorConfigLine") ]]; then
			printf "processor $ProcessorNumber ${Red}offline${Reset}\n"
			echo 0 > /sys/devices/system/cpu/cpu${ProcessorNumber}*/online
#			echo 			/sys/devices/system/cpu/cpu${ProcessorNumber}*/online 
#			echo $ProcessorNumber
		else 
			printf "processor $ProcessorNumber ${Green}online${Reset}\n"
			echo 1 > /sys/devices/system/cpu/cpu${ProcessorNumber}*/online 2>/dev/null 

		fi		
	done
	IFS=$SAVEIFS
}
#------------------------------------------------------------------------------------------------------------
cpu_manager () {				#TODO
	echo "manage single cpus"

}
#------------------------------------------------------------------------------------------------------------
power_manager () {				#TODO
	echo "manage cpu powerstatus ( cpu govaneu status )"

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

	# check input options #TODO

#------------------------------------------------------------------------------------------------------------

	# gathering system specs, get core and cpu configurations, print specs
	SystemSpecList=$(get_system_specs)
	if [[ -n $ShowSystemSpecs ]]; then print_system_specs ; fi	

#------------------------------------------------------------------------------------------------------------

	# configure core and cpu 
	if [[ -n $DisableCore || $EnableCore ]]; then processing_core_options ; fi
	if [[ -n $DisableCPU || $EnableCPU ]]; then processing_cpu_options ; fi
	if [[ -n $DisableHT || $EnableHT ]]; then processing_hyperthreading_options ; fi

#------------------------------------------------------------------------------------------------------------

echo
echo
echo "$SystemSpecList"
exit





###############################################################

	# set cores config
	if [[ -n $CoreConfig ]]; then core_manager && EnableConfigCoreCPU=true ; fi

#------------------------------------------------------------------------------------------------------------

	# set processor config #TODO
	if [[ -n $CPUConfig ]]; then cpu_manager && EnableConfigCoreCPU=true ; fi

#------------------------------------------------------------------------------------------------------------

	# set cpu config
	if [[ -n $GovernorConfig ]]; then power_manager && EnableConfigCoreCPU=true ; fi

#------------------------------------------------------------------------------------------------------------

	# set HTconfig
	if   [[ $HTconfig == 0  ]]; then
		if   [[ $SystemStatusHyperthread == on ]]; then
			echo "hyperthreading disabled"	
			echo off > /sys/devices/system/cpu/smt/control
		elif [[ $SystemStatusHyperthread == off ]]; then
			echo "hyperthreading allready disabled"
		else
			echo "hyperthreading not available"
		fi
	elif [[ $HTconfig == 1  ]]; then
		if   [[ $SystemStatusHyperthread == on ]]; then
			echo "hyperthreading allready enabled"
		elif [[ $SystemStatusHyperthread == off ]]; then
			echo "hyperthreading enabled"
			echo on > /sys/devices/system/cpu/smt/control
		else
			echo "hyperthreading not available"
		fi
	fi

#------------------------------------------------------------------------------------------------------------

	# enable core and cpu configuration
	if [[ -n "$EnableConfigCoreCPU"  ]]; then
		enable_processor_config "$ProcessorConfigList" 
	fi

#------------------------------------------------------------------------------------------------------------

exit 0

#grep -E 'processor|core id' /proc/cpuinfo
#for x in /sys/devices/system/cpu/cpu[1-9]*/online; do   echo 1 >"$x"; done
#for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "powersave" > $file; done







