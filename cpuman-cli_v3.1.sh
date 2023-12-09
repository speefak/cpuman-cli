#!/bin/bash
# name          : cpuman-cliCPUCoreTmpAvg
# desciption    : manage cpu cores and powerstatus of cpu
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 3.1
# notice 	:
# infosource	: https://askubuntu.com/questions/1185826/how-do-i-disable-a-specific-cpu-core-at-boot
#		  https://variwiki.com/index.php?title=CPU_freq_and_num_of_cores
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 Version=$(cat $(readlink -f $(which $0)) | grep "# version" | head -n1 | awk -F ":" '{print $2}' | sed 's/ //g')
 ScriptFile=$(readlink -f $(which $0))
 ScriptName=$(basename $ScriptFile)
 
 RequiredPackets="bash sed linux-cpupower bc" # libbpf-tools cpufrequtils

 MailAddress=root
 Timestamp=$(date "+%F %H:%M:%S")

 CPUModelName=$(cat /proc/cpuinfo | grep "model name" | uniq | awk -F ": " '{printf $2}' | awk -F "@" '{printf $1}')
 MaxCPUs=$(($(cat /sys/devices/system/cpu/present | cut -d "-" -f2)+1)) 
 GovernorAvailable=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
 CPUScalingDriver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)
 CPUCoreTempHigh=$(sensors | grep "Package id 0:" | awk -F "[+.]" '{printf $4}')
 CPUCoreTempCrit=$(sensors | grep "Package id 0:" | awk -F "[+.]" '{printf $6}')
 CPUScalingDriver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)
#CPUScalingDriver=$(cpufreq-info -d)

# updateable vars
 get_cpu_vars () {
	 Hyperthreading=$(cat /sys/devices/system/cpu/smt/control 2>/dev/null)
	 GovernorStatus=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
	 CPUCoreTemps=$(sensors | grep Core | cut -d  "+" -f2 | cut -d "." -f1)
	 CPUCoreCountPhysical=$(echo "$CPUCoreTemps" | wc -l)
	 CPUCoreCountLogical=$(grep ^processor /proc/cpuinfo | wc -l)
	 CPUCoreTmpMax=$(sensors | grep "Package id 0:" | awk -F "[+.]" '{printf $2}')
	 CPUCoreTmpAvg=$(($(($(echo "$CPUCoreTemps" | tr  "\n" "+" | sed 's/+$//'))) / $CPUCoreCountPhysical ))
	 CPUMaxFreq=$(lscpu | grep "CPU max MHz" | awk '{printf $4}' | cut -d "," -f1)
	 CPUMinFreq=$(lscpu | grep "CPU min MHz" | awk '{printf $4}' | cut -d "," -f1)
	}

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
		GovernorStatusEdit;-gs
		TempCheck;-tc
		HelpDialog;-h
		Monochrome;-m
		ScriptInformation;-i
		CheckForRequiredPackages;-cfrp
		CPUInfo;-cpi
		CPUfreq;-cpf
	"
	# set entered vars from optionvarlist
	OptionAllocator=" "											# for option seperator "=" use cut -d "="
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
 	for InputOption in $(echo " $@" | sed 's/ -/\n-/g') ; do
		for VarNameVarValue in $OptionVarList ; do
			VarName=$(echo "$VarNameVarValue" | cut -d ";" -f1)
			VarValue=$(echo "$VarNameVarValue" | cut -d ";" -f2)
#			if [[ -n $(echo " $InputOption" | grep " $VarValue" 2>/dev/null) ]]; then
			if [[ $InputOption == "$VarValue" ]]; then
				eval $(echo "$VarName"='$InputOption')						# if [[ -n Option1 ]]; then echo "Option1 set";fi
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
	printf " -ss <0.1-999>		=> show cpu specifications ( <seconds> for loop output )\n"
	printf " -[e|d]c <1,2-3,4>	=> (e)nable (d)isable core \n"
	printf " -[e|d]p <1,4-5,8>	=> (e)nable (d)isable processor \n"
	printf " -[e|d]h 		=> (e)nable (d)isable hyperthreading \n"
	printf " -[e|d]a 		=> (e)nable (d)isable all CPUs and hyperthreading\n"
	printf " -tc <temp threshold>	=> cpu (t)emperature (c)heck ( send mail if threashold temp reached ) \n"
	printf " -h			=> help dialog \n"
	printf " -m			=> monochrome output \n"
	printf " -i			=> show script information \n"
	printf " -cfrp			=> check for required packets \n"
	printf " -cpi			=> use cpuinfo output for freqenucy calculating"
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
#--------------------------------------------------------------------------------------------------------------
print_parser () {

	if   [[ $(grep SeperatorLine <<< $@) ]]; then
		printf "+----------------------------------------------------------+\n"
	elif [[ $PrintParser == "info_line"  ]]; then
		printf "| %-97s | \n" "$1"
	elif [[ $PrintParser == "print_CPU_specs" ]]; then
		printf "| %-15s %-2s %-35s %-1s | \n" "$1" "$2" "$3" "$4"
	elif [[ $PrintParser == "print_CPU_data" ]]; then
		printf "| %-8s %-6s %-8s %-14s %10s %-5s | \n" "$1" "$2" "$3" "$4" "$5" "$6"
	elif [[ $PrintParser == "print_CPU_data_info_line" ]]; then
		printf "| %-8s %-6s %-8s %-14s %10s %-5s | \n" "$1" "$2" "$3" "$4" "$5" "$6"
	fi
}
#------------------------------------------------------------------------------------------------------------
print_colored_output () {

	# print and parse output
	printf "$(echo "$1\n\n" |\

	# print hyperthreading statusprint_CPU_data
	sed 's/Hyperthreading  => notsupported/Hyperthreading  =>\'$LRed' not supported '\\$Reset'/g' |\
	sed 's/Hyperthreading  => on/Hyperthreading  =>\'$LGreen' on'\\$Reset'/g' |\
	sed 's/Hyperthreading  => off/Hyperthreading  =>\'$LRed' off'\\$Reset'/g' |\

	# parse online/offline string
	sed 's/online/\'$LGreen'online'\\$Reset'/g' |\
	sed 's/offline/\'$LRed'offline'\\$Reset'/g' |\

	# parse enabled/disabled string
	sed 's/enabled/\'$LGreen'enabled'\\$Reset'/g' |\
	sed 's/disabled/\'$LRed'disabled'\\$Reset'/g' |\

	# print another var
	sed 's/pattern/new/g' )"

}
#------------------------------------------------------------------------------------------------------------
print_CPU_specs () {

	# update cpu vars
	get_cpu_vars

	PrintParser="print_CPU_specs"
	print_parser SeperatorLine
	print_parser "CPU Model" "=>" "$CPUModelName"
	print_parser "CPU cores" "=>" "$CPUCoreCountPhysical"
	print_parser "CPU processors" "=>" "$CPUCoreCountLogical"
	print_parser "Hyperthreading" "=>" "$Hyperthreading"
	print_parser "Governor driver" "=>" "$CPUScalingDriver"
	print_parser "CPU freq max" "=>" "$CPUMaxFreq MHz"
	print_parser "CPU freq min" "=>" "$CPUMinFreq MHz"
	print_parser "CPU temp actual" "=>" "$CPUCoreTmpMax C | $CPUCoreTmpAvg C (core peak|avg)"
	print_parser "CPU temp high" "=>" "$CPUCoreTempHigh C"
	print_parser "CPU temp crit" "=>" "$CPUCoreTempCrit C"

	# set print parser
	PrintParser="print_CPU_data"
	print_parser SeperatorLine

	# get cpu status
	CoreNumber="-1"
	for i in /sys/devices/system/cpu/cpu[0-99]*; do
	
		# calculate CPU/core count
		CPUNumber=$(echo $i | awk -F "/cpu/cpu" '{printf $2}' | tr -d "/") 
		GovernorStatus=$(cat $i/cpufreq/scaling_governor 2>/dev/null)
		
		CPUFreqActual="$(echo $(cat $i/cpufreq/scaling_cur_freq 2>/dev/null)/1000 | bc 2>/dev/null ) "
		if [[ -z $CPUFreqActual ]] || [[ -n $CPUInfo ]]; then
				CPUFreqActual="$(echo $(cat $i/cpufreq/cpuinfo_cur_freq 2>/dev/null)/1000 | bc 2>/dev/null ) "
		fi
		#CPUFreqActual=$(cat /proc/cpuinfo | grep -A10 "processor.*$CPUNumber" | grep "cpu MHz" | grep -o -P '(?<=: ).*(?=....)')	# more accurate value

		# substitute offline cpu vars
		if [[ -z $( echo $CPUFreqActual | grep [[:digit:]] ) ]]; then
			GovernorStatus="--------"
			CPUFreqActual="---- "
		fi

		# get all CPU freqs for averrage freq calculation
		CPUFreqSum=$(echo $CPUFreqSum $CPUFreqActual)

		# check core and cpu count
		if [[ $Hyperthreading == "notsupported" ]]; then
			CoreNumber=$CPUNumber
		else
			CoreNumber=$(($CoreNumber+1))
			if [[ $CoreNumber == $(($MaxCPUs/2)) ]]; then
				CoreNumber=0
			fi
		fi

		# check CPU online status
		if [[ $CPUNumber == 0 ]]; then
			CPUStatus=" online"
		else
			CPUStatus=$(cat $i/online 2>/dev/null)
		fi
		CPUStatus=${CPUStatus/1/ online}
		CPUStatus=${CPUStatus/0/offline}

		# print cpu details
		print_parser  "$CPUStatus" "CPU $CPUNumber" "Core $CoreNumber" "$GovernorStatus" "$CPUFreqActual MHz"
	done

	# calc print average freqency
	CPUFreqAvg=$(($(echo "($CPUFreqSum)/$CPUCoreCountLogical" | tr " -" "+0"  ) ))
	print_parser SeperatorLine
	PrintParser=print_CPU_data_info_line
	print_parser " " " " " " " average" "$CPUFreqAvg  MHz"
	print_parser SeperatorLine
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

#TODO		# send mail via $MailAddress
		# printf \n CPU core temperature threshold reached (speenux) \n actual: 43°C threshold: 20°C (manually set) cpu high: 80°C cpu critical: 100°C  | sed 's/^[ \t]*/  /' | mail -a Content-Type: text/plain -s WARNING! (speenux): CPU core temperature high: 43°C | 20°C (actual|threshold)  root
		
		printf "$MailContent" | sed 's/^[ \t]*/  /' | mail -a "Content-Type: text/plain" -s "$MailSubjectLine" $MailAddress
	else
		printf " Current CPU core temperature: ($CPUCoreTmpAvg"°C") | threshold ($TempCheck"°C") unreached. \n"
	fi
}
#------------------------------------------------------------------------------------------------------------
input_parser_numeric () {											# usage: input_parser_numeric <1-3,5,7-15>
	IFS=',' read -ra ranges <<< "$1"
	for range in "${ranges[@]}"; do
		[[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]] && output+=" $(seq -s' ' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}")" || output+=" $range"
	done	
	printf "$output" | sed 's/ 0 //g'									# print outout and skip cpu 0
}
#------------------------------------------------------------------------------------------------------------
write_configuration () {

	MaxCPUNumber=$(($MaxCPUs-1))

	# enable / disable everthing exept cpu0
	if [[ -n $EnableAll ]]; then EnableHT=true && EnableCPU="0-$MaxCPUNumber" ;fi
	if [[ -n $DisableAll ]]; then DisableHT=true && DisableCPU="0-$MaxCPUNumber" ;fi

	# disable / enable hyperthreadding
	if [[ -n $DisableHT ]]; then echo off > /sys/devices/system/cpu/smt/control 2>/dev/null ;fi
	if [[ -n $EnableHT ]];  then echo on > /sys/devices/system/cpu/smt/control 2>/dev/null ;fi

	# disable core
	if [[ -n $DisableCore ]]; then 
		for i in $(input_parser_numeric "$DisableCore") ; do
			DisableCPU="$DisableCPU $(print_CPU_specs | grep "Core $i" | awk -F "CPU " '{print $2}' | cut -d " " -f1 )"
		done
		DisableCPU=$(echo $DisableCPU |sed 's/ /,/g' )
	fi

	# enable core
	if [[ -n $EnableCore ]]; then 
		for i in $(input_parser_numeric "$EnableCore") ; do
			EnableCPU="$EnableCPU $(print_CPU_specs | grep "Core $i" | awk -F "CPU " '{print $2}' | cut -d " " -f1)"
		done
		EnableCPU=$(echo $EnableCPU |sed 's/ /,/g' )
	fi

	# disable cpu
	if [[ -n $DisableCPU ]]; then 
		for i in $(input_parser_numeric "$DisableCPU") ; do
			if [[ $i -gt $MaxCPUNumber ]]; then continue ;fi
			echo 0 > /sys/devices/system/cpu/cpu$i/online 2> /dev/null
		done
	fi

	# enable cpu
	if [[ -n $EnableCPU ]]; then 
		for i in $(input_parser_numeric "$EnableCPU") ; do
			if [[ $i -gt $MaxCPUNumber ]]; then continue ;fi
			echo 1 > /sys/devices/system/cpu/cpu$i/online 2> /dev/null
		done
	fi

#TODO
#	if [[ -n $GovernorStatusEdit ]]; then echo ; fi

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

	# write cpu configuration when config changed and print specs
	if [[ -n $( echo $GovernorStatusAllEdit $DisableHT $EnableHT $DisableCore $EnableCore $DisableCPU $EnableCPU $EnableAll $DisableAll) ]]; then
		write_configuration
		print_colored_output "$(print_CPU_specs)"
	fi

#------------------------------------------------------------------------------------------------------------

	# print default output specs
	if [[ -z $1 ]]; then print_colored_output "$(print_CPU_specs)" ;fi

#------------------------------------------------------------------------------------------------------------

	# check cpu temperatures and mail if threashold is reached
	if [[ -n $TempCheck ]]; then temp_check && exit ; fi

#------------------------------------------------------------------------------------------------------------

	# print specs / single or loop output
	if [[ $ShowSystemSpecs == "-ss" ]]; then
		print_colored_output "$(print_CPU_specs)"
		exit
	elif [[ -n $ShowSystemSpecs ]] && [[ -z $(echo $ShowSystemSpecs | tr -d [[:digit:]] | tr -d ".") ]]; then
		LoopDelay=$ShowSystemSpecs
		clear
		tput civis
		while [[ -z $Quit ]] ; do
			tput cup 0,0
			print_colored_output "$(print_CPU_specs)"
			printf " press any key to quit \n"
			read -s -n 1 -t $LoopDelay Quit
		done
		tput cnorm
		exit
	fi

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------
############################################################################################################
##############################################   changelog   ###############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

#changelog 3.0 => 3.1 : cpu configuration revised
#changelog      > 3.0 : use fast loop from version 2.7 

#changelog 2.7 => 2.8 : new code to get cpu specs / each cpu now configureable / slow loops ( 0.4s)
#changelog 2.6 => 2.7 : export get cpu specs to function => fast cpumam-cli script / fast loops (0.2s)
#changelog 2.5 => 2.6 : code review
#changelog 2.4 => 2.5 : add printparser, code review
#changelog 2.3 => 2.4 : add cpu general specs output / code review
#changelog 2.2 => 2.3 : add cpu load and cpu MHZ to info output
#changelog 2.1 => 2.2 : add cpu_temp_check function / add cpu info MHz output / add loop output function / 


# https://documentation.suse.com/sles/15-SP4/html/SLES-all/cha-tuning-power.html#sec-tuning-power-tools-cpupower-idle-info
