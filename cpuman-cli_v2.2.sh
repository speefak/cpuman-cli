#!/bin/bash
# name          : cpuman-cliCPUCoreTmpAvg
# desciption    : manage cpu cores and powerstatus of cpu
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 2.2
# notice 	:
# infosource	: https://askubuntu.com/questions/1185826/how-do-i-disable-a-specific-cpu-core-at-boot
#
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 RequiredPackets="bash sed awk "
 MaxCPUs=$(($(cat /sys/devices/system/cpu/present | cut -d "-" -f2)+1)) #ls /sys/devices/system/cpu/ |grep -c ^cpu[[:digit:]]
 Hyperthreading=$(cat /sys/devices/system/cpu/smt/control)
 CPUModelName=$(cat /proc/cpuinfo | grep "model name" | uniq | awk -F ": " '{printf $2}' | awk -F "@" '{printf $1}')

 MailAddress=root
 Timestamp=$(date "+%F %H:%M:%S")
 CPUCoreTemps=$(sensors | grep Core | cut -d  "+" -f2 | cut -d "." -f1)
 CPUCoreCountPhysical=$(echo "$CPUCoreTemps" | wc -l)
 CPUCoreCountLogical=$(grep ^processor /proc/cpuinfo | wc -l)
 CPUCoreTempHigh=$(sensors | grep "Package id 0:" | awk -F "[+.]" '{printf $4}')
 CPUCoreTempCrit=$(sensors | grep "Package id 0:" | awk -F "[+.]" '{printf $6}')
 CPUCoreTmpAvg=$(($(($(echo "$CPUCoreTemps" | tr  "\n" "+" | sed 's/+$//'))) / $CPUCoreCountPhysical ))

 Version=$(cat $(readlink -f $(which $0)) | grep "# version" | head -n1 | awk -F ":" '{print $2}' | sed 's/ //g')
 ScriptFile=$(readlink -f $(which $0))
 ScriptName=$(basename $ScriptFile)

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
		DisableAll;-da
		EnableCore;-ec
		EnableCPU;-ep
		EnableHT;-eh
		EnableAll;-ea
		TempCheck;-tc
		HelpDialog;-h
		Monochrome;-m
		ScriptInformation;-i
		CheckForRequiredPackages;-cfrp
	"
	# set entered vars from optionvarlist
	OptionAllocator=" "										# for option seperator "=" use cut -d "="
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
 	for InputOption in $(echo " $@" | sed 's/ -/\n-/g') ; do
		for VarNameVarValue in $OptionVarList ; do
			VarName=$(echo "$VarNameVarValue" | cut -d ";" -f1)
			VarValue=$(echo "$VarNameVarValue" | cut -d ";" -f2)
#			if [[ -n $(echo " $InputOption" | grep " $VarValue" 2>/dev/null) ]]; then
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
	# parse required colours for echo/printf usage: printf "%s\n" "Text in ${Red}red${Reset}, white and ${Blue}blue${Reset}."
	Black='\033[0;30m'	&&	DGray='\033[1;30m'
	LRed='\033[0;31m'	&&	Red='\033[1;31m'
	LGreen='\033[0;32m'	&&	Green='\033[1;32m'
	LYellow='\033[0;33m'	&&	Yellow='\033[1;33m'
	LBlue='\033[0;34m'	&&	Blue='\033[1;34m'
	LPurple='\033[0;35m'	&&	Purple='\033[1;35m'
	LCyan='\033[0;36m'	&&	Cyan='\033[1;36m'
	LLGrey='\033[0;37m'	&&	White='\033[1;37m'
	Reset='\033[0m'

	BG='\033[47m'
	FG='\033[0;30m'

	# parse required colours for sed usage: sed 's/status=sent/'${Green}'status=sent'${Reset}'/g' |\
	if [[ $1 == sed ]]; then
		for ColorCode in $(cat $0 | sed -n '/^load_color_codes/,/FG/p' | tr "&" "\n" | grep "='"); do
			eval $(sed 's|\\|\\\\|g' <<< $ColorCode)						# sed parser '\033[1;31m' => '\\033[1;31m'
		done
	fi
}
#------------------------------------------------------------------------------------------------------------
usage() {
	printf "\n"
	printf " Usage: $(basename $0) <options> "
	printf "\n"
	printf " -ss <0.1-999>		=> show system specifications ( <seconds> for loop output )\n"
	printf " -[e|d]c <1,2-3,4>	=> (e)nable (d)isable core \n"
	printf " -[e|d]p <1,4-5,8>	=> (e)nable (d)isable cpu \n"
	printf " -[e|d]h 		=> (e)nable (d)isable hyperthreading \n"
	printf " -[e|d]a 		=> (e)nable (d)isable all CPUs and hyperthreading\n"
	printf " -tc <temp threshold>	=> cpu (t)emperature (c)heck ( send mail if threashold temp reached ) \n"
	printf " -h			=> help dialog \n"
	printf " -m			=> monochrome output \n"
	printf " -i			=> show script information \n"
	printf " -cfrp			=> check for required packets \n"
	printf  "\n${LRed} $1 ${Reset}\n"
	printf "\n"
	exit
}
#------------------------------------------------------------------------------------------------------------
check_input_options () {

	# create available options list
	InputOptionList=$(cat $ScriptName | sed -n '/usage()/,/exit/p' | grep " -[[:alpha:]]" | awk '{print $3}' | grep "^\-")

	# check for valid input options
	for Option in $@ ; do	
		if [[ -z $(grep -w -- "$Option" <<< "$InputOptionList") ]]; then
			InvalidOptionList=$(echo $InvalidOptionList $Option)
		fi
	done

	# print invalid options and exit script_information
	if [[ -n $InvalidOptionList ]]; then
		usage "invalid option: $InvalidOptionList"
	fi
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

	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets=$(echo $MissingPackets $Packet)
		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf  "missing packets: \e[0;31m $MissingPackets\e[0m\n"$(tput sgr0)
		read -e -p "install required packets ? (Y/N) "		 	-i "Y" 		InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf  "programm error: $LRed missing packets : $MissingPackets $Reset\n\n"$(tput sgr0)
			exit 1
		fi

	else
		printf "$LGreen all required packets detected$Reset\n"
	fi
}
#------------------------------------------------------------------------------------------------------------
get_system_specs () {

	# get core status
	echo " MaxCPUs=$(($(cat /sys/devices/system/cpu/present | cut -d "-" -f2)+1)) "
	echo " Hyperthreading=$(cat /sys/devices/system/cpu/smt/control) "

	# get cpu status
	CoreNumber="-1"
	for i in /sys/devices/system/cpu/cpu[0-99]*; do
		# calculate CPU/core count / check for hyperthreadding support
		CPUNumber=$(echo $i | awk -F "/cpu/cpu" '{printf $2}' | tr -d "/")
		CPUFreq="$(($(cat $i/cpufreq/cpuinfo_cur_freq)/1000)) MHz"
		GovernorStatus=$(cat $i/cpufreq/scaling_governor)

		if [[ $Hyperthreading == "notsupported" ]]; then
			CoreNumber=$CPUNumber
		else
			CoreNumber=$(($CoreNumber+1))
			if [[ $CoreNumber == $(($MaxCPUs/2)) ]]; then
				CoreNumber=0
			fi
		fi

		# print configuration | write function output to var
		printf " CPU=$CPUNumber Core=$CoreNumber"
		if [[ $CPUNumber == 0 ]]; then
			printf " OnlineStatus=1"
		else
			printf " OnlineStatus=$(cat $i/online)"
		fi
		printf " $GovernorStatus $CPUFreq"
		printf "\n"
		
	done
}
#------------------------------------------------------------------------------------------------------------
print_system_specs () {

	SystemSpecList=$(get_system_specs)

	# print and parse output
	printf "$(echo "$SystemSpecList\n\n" |\

	# print CPU and Core Count
	sed 's/MaxCPUs='[0-9]'/Detected Processors\'$LYellow' '$MaxCPUs' '\\$Reset'/g' |\

	# print hyperthreading status
	sed 's/Hyperthreading=notsupported/Hyperthreading\'$LRed' not supported '\\$Reset'/g' |\
	sed 's/Hyperthreading=on/Hyperthreading\'$LGreen' on '\\$Reset'/g' |\
	sed 's/Hyperthreading=off/Hyperthreading\'$LRed' off '\\$Reset'/g' |\

	# print cpu status
	sed 's/OnlineStatus=0/\'$LRed'offline'\\$Reset'/g' |\
	sed 's/OnlineStatus=1/\'$LGreen' online'\\$Reset'/g' |\

	# delete Governor VAR
	sed 's/GovernorStatus=//g' |\

	# clear processing characters
	sed 's/=/ /g' )"
	
	#printf "$(cpufreq-info| grep Taktfrequenz)"
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
}
#------------------------------------------------------------------------------------------------------------
processing_cpu_options () {					# usage: processing_cpu_options (set vars before function execution)

 edit_configuration_var () {					# usage: edit_configuration_var <e|d> <1|2-3|2-3,4|...>
	# processing ProcessingCPUList
	for CPUNumber in $2 ;do

		# auto enable hyperthreading for virtual CPUs
		if  [[ $1 == e ]] && [[ $CPUNumber -ge "$(($MaxCPUs/2))" ]] && [[ $( grep "Hyperthreading=" <<< "$SystemSpecList" | grep  "off") ]] ;then
			EnableHT=true && processing_hyperthreading_options
		fi

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

}
#------------------------------------------------------------------------------------------------------------
processing_hyperthreading_options () {

	# check for hyperthreading support
	if [[ -n $(grep "notsupported" /sys/devices/system/cpu/smt/control)  ]]; then
		usage " hyperthreading not supported by $CPUModelName"
	fi

	# processing input var
	printf " hyperthreading "
	if   [[ -n $DisableHT ]]; then HTStatus=off && printf "disabled \n"
	elif [[ -n $EnableHT  ]]; then HTStatus=on  && printf "enabled \n"
	fi

	# edit systemSpecList
	SystemSpecList=$(sed 's/Hyperthreading=.*/Hyperthreading='$HTStatus'/' <<< $SystemSpecList)

	# clear options
	DisableHT=
	EnableHT=
}
#------------------------------------------------------------------------------------------------------------
write_configuration () {

	# write hyperthread config
	Hyperthreading=$(awk -F "Hyperthreading=" '{printf $2}' <<< $SystemSpecList )
	echo $Hyperthreading > /sys/devices/system/cpu/smt/control 2> /dev/null

	# write individual CPU config
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for i in $( grep "^ CPU" <<< $SystemSpecList) ; do

		ProcessingCPUNumber=$(awk -F "CPU=" '{printf $2}' <<< $i | cut -d " " -f1)
		OnlineStatus=$(awk -F "OnlineStatus=" '{printf $2}' <<< $i | cut -d " " -f1)

		# skip CPU0
		if [[ $ProcessingCPUNumber == 0 ]]; then continue ;fi

		# write CPU status
		echo $OnlineStatus > /sys/devices/system/cpu/cpu$ProcessingCPUNumber/online 2> /dev/null
	done
	IFS=$SAVEIFS

	SystemSpecList=$(get_system_specs)
	printf "\n"
	print_system_specs
}
#------------------------------------------------------------------------------------------------------------
temp_check () {

	# check for threshold input / if temp is not specified use CPU HighTemp as default var
	if [[ -z $(echo $TempCheck | sed 's/\-tc//g') ]] ; then
		printf " no threshold temperature specified, using CPU high temperature value ( $CPUCoreTempHigh°C )\n"
		TempCheck=$CPUCoreTempHigh
	else
		OverrideCPUCoreTempHigh="(manually set)"
	fi

	# check threshold for email warning
	if [[ $CPUCoreTmpAvg -gt $TempCheck ]] ; then
		MailSubjectLine="WARNING! ($(hostname)): CPU core temperature high: $CPUCoreTmpAvg"°C" | $TempCheck"°C" (actual|threshold) "
		MailContent="\n	CPU core temperature threshold reached ($(hostname)) \n
				actual:       $CPUCoreTmpAvg"°C"
				threshold:    $TempCheck"°C" $OverrideCPUCoreTempHigh
				cpu high:     $CPUCoreTempHigh"°C"
				cpu critical: $CPUCoreTempCrit"°C"
			"
		printf " $MailSubjectLine\n"
		printf " Notification send via Mail ( $MailAddress )\n"

		# send mail via $MailAddress
		
		# printf \n CPU core temperature threshold reached (speenux) \n actual: 43°C threshold: 20°C (manually set) cpu high: 80°C cpu critical: 100°C  | sed 's/^[ \t]*/  /' | mail -a Content-Type: text/plain -s WARNING! (speenux): CPU core temperature high: 43°C | 20°C (actual|threshold)  root
		
		printf "$MailContent" | sed 's/^[ \t]*/  /' | mail -a "Content-Type: text/plain" -s "$MailSubjectLine" $MailAddress
	else
		printf " Current CPU core temperature: ($CPUCoreTmpAvg"°C") | threshold ($TempCheck"°C") unreached. \n"
	fi
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
	Reset='\033[0m'
	if [[ -z $Monochrome ]]; then
		load_color_codes
	fi

#------------------------------------------------------------------------------------------------------------

	# check help dialog
	if [[ -n $HelpDialog ]] ; then usage "help dialog" ; fi

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

	# chekc cpu temperatures and amil if threashold is reached
	if [[ -n $TempCheck ]]; then temp_check && exit ; fi
	
#------------------------------------------------------------------------------------------------------------

	# print_system_specs as loop output
	if [[ -z $(echo $ShowSystemSpecs | tr -d [[:digit:]] | tr -d ".") ]]; then
		LoopDelay=$ShowSystemSpecs
		clear
		tput civis
		while [[ -z $Quit ]] ; do
			tput cup 0,0
			print_system_specs
			printf "\n"
			printf " press any key to quit \n"
			read -n 1 -t $LoopDelay Quit
		done
		tput cnorm
	fi

#------------------------------------------------------------------------------------------------------------

	# default output | gathering system specs, get core and cpu configurations, print specs 
	if [[ -n $ShowSystemSpecs ]] || [[ -n $1 ]]; then print_system_specs && exit ; fi

#------------------------------------------------------------------------------------------------------------

	# enable / disable all
	if   [[ -n $EnableAll ]]; then
		if [[ ! $Hyperthreading  == notsupported ]] ;then EnableHT=true && processing_hyperthreading_options ; fi
		EnableCPU=$(seq 0 1 $(($MaxCPUs-1)))
	elif [[ -n $DisableAll ]]; then
		if [[ ! $Hyperthreading  == notsupported ]] ;then DisableHT=true && processing_hyperthreading_options ; fi
		DisableCPU=$(seq 0 1 $(($MaxCPUs-1)))
	fi

#------------------------------------------------------------------------------------------------------------

	# configure core and cpu
	if [[ -n $DisableHT || $EnableHT ]]; then processing_hyperthreading_options ; fi		#TODO check for HT print usage and exit ?????
	if [[ -n $DisableCore || $EnableCore ]]; then processing_core_options ; fi
	if [[ -n $DisableCPU || $EnableCPU ]]; then processing_cpu_options ; fi

#------------------------------------------------------------------------------------------------------------

	# write configuration
	write_configuration

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------
############################################################################################################
##############################################   changelog   ###############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

#TODO integrate cpu governour configuration options | cpufreq-info as vebose cpu info

#changelog 2.2 => 2.3 : add cpu load and cpu MHZ to info output

#changelog 2.1 => 2.2 : add cpu_temp_check function / add cpu info MHz output / add loop output function / 






# /usr/sbin/lmt-config-gui-pkexec     #=> laptopmode GUI
# set CPU governor
# for i in /sys/devices/system/cpu/cpufreq/policy*; do    echo ondemand > "$i"/scaling_governor; done


