#!/bin/bash

###PROGRAM DESCRIPTION###
# Aurer: A simple, KISS AUR helper written in Bash.
#Copyright: L. M. Abramovich (leonardoabramovich@hotmail.com)
#License: GPL2

#CLEAN ALL NEEDED VARIABLES
unset white red green cyan magenta nc prog_name version date author CONFIG_DIR CONFIG_FILE \
TEMP_DIR dep_ver_req down_dep_ver condition pkg ver pkg_name comp_op down_ver non_inst_deps \
not_found file DEPENDS MAKEDEPENDS not_sat_req ver_req ret DEPS_NEED_INSTALL DEPS_NEED_INSTALL_AUR \
MAKEDEPS_NEED_INSTALL MAKEDEPS_NEED_INSTALL_AUR non_inst_deps INSTALLED_DEPS INSTALLED_MAKEDEPS \
PKG_NAME answer editor cower_ok DEFAULT_AUR_URL DEFAULT_DOWNLOAD_CMD COMP_FILE_EXT uninst_make_deps

###COLORS###
blue="\033[1;34m"
green="\033[1;32m"
magenta="\033[1;35m"
nc="\033[0m"
red="\033[1;31m"
white="\033[1;37m"
yellow="\033[1;33m"

###PROGRAM DATA###
author="L. M. Abramovich"
date="Mar 5, 2018"
prog_name="aurer"
version="0.4.1"
CONFIG_DIR="$HOME/.config/aurer"
CONFIG_FILE=".aurerrc"
COMP_FILE_EXT="tar.gz"
DEFAULT_AUR_URL="https://aur.archlinux.org/cgit/aur.git/snapshot"
DEFAULT_DOWNLOAD_CMD="wget -q"
TEMP_DIR="/tmp/aurer"

###EXIT CODES###
EXIT_FAILURE=1
EXIT_SUCCESS=0

###FUNCTIONS####

function help ()
{
	echo "Aurer $version ($date), by $author"
	echo -e "A simple, KISS AUR helper written in Bash. \n"
	echo -e "Usage: aurer [options] [pkg_name]\nOptions:\n"
	echo -e "  -a, --aur-agent\n\tShow currently used AUR agent"
	echo -e "  -h, --help\n\tShow this help and exit"
	echo -e "  -R, --remove)\n\tRemove package"
	echo -e "  -S, --sync [pkg_name]\n\tInstall 'pkg_name' from the AUR"
	echo -e "  -Si, --info [pkg_name]\n\tShow info for 'pkg_name'"
	echo -e "  -Sn, --search-name [string]\n\tShow those packages in the AUR exactly matching 'string'"
	echo -e "  -Ss, --search [string]\n\tSearch a package in the AUR. 'string' is either the \
package name or a keyword describing the package. E.g. aurer -Ss terminal emulator"
	echo -e "  -Sw, --download-only [pkg_name]\n\tDownload 'pkg_name' but do not install it"
	echo -e "  -u, --updates\n\tCheck updates for installed AUR packages\n"
	echo -e "Configuration file: \$HOME/.config/aurer/.aurerrc"
}

###DEPS VERSION FUNCTIONS
function get_ver ()
{
	if [[ $1 == *"="* ]]; then echo $1 | cut -d"=" -f2
	elif [[ $1 == *">"* ]]; then echo $1 | cut -d">" -f2
	elif [[ $1 == *"<"* ]]; then echo $1 | cut -d"<" -f2
	else echo 0
	fi
}

function get_pkg_name ()
{
	if [[ $1 == *">"* ]]; then echo $1 | cut -d">" -f1
	elif [[ $1 == *"<"* ]]; then echo $1 | cut -d"<" -f1
	fi
}

function comp_vers ()
{
	#Return 0 if condition is not satisfied, 1 otherwise
	dep_ver_req=$1
	down_dep_ver=$2
	condition=$3
	
	ret="$(vercmp $down_dep_ver $dep_ver_req)"
	case $condition in
		">=") [[ $ret -ge 0 ]] && echo 1 || echo 0 ;;
		"<=") [[ $ret -le 0 ]] && echo 1 || echo 0 ;;
		"=") [[ $ret -eq 0 ]] && echo 1 || echo 0 ;;
		">") [[ $ret -gt 0 ]] && echo 1 || echo 0 ;;
		"<") [[ $ret -lt 0 ]] && echo 1 || echo 0 ;;
	esac
}

function handle_version ()
{
	# Returns: 
	# 0 - Dependency version cannot be satisfied
	# 1 - No version requirement
	# 2 - Dep satisfied and installed
	# 3 - Dep satisfied, but must be installed from Arch repos 
	# 4 - Dep satisfied, but must be installed from the AUR 
	pkg=$1
	ver=$(get_ver $pkg) 
	if [[ $ver != 0 ]]; then 
		pkg_name=$(get_pkg_name $pkg)
		comp_op=$(echo $pkg | sed -e "s/^$pkg_name//" -e "s/$ver$//")
		#Check installed packages
		down_ver="$(pacman -Q | grep "^${pkg_name} " | awk '{print $2}')"
		if [[ $down_ver != "" ]]; then 
			ret=$(comp_vers $ver $down_ver $comp_op)
			[[ $ret -eq 1 ]] && echo "2" && return
		fi
		#Check Arch repos
		down_ver="$(pacman -Ss ^${pkg_name}$ | sed -n 1p | awk '{print $2}')"
		if [[ $down_ver != "" ]]; then
			ret=$(comp_vers $ver $down_ver $comp_op)
			[[ $ret -eq 1 ]] && echo "3" && return
		fi
		#Check the AUR
		if [[ $cower_ok -eq 1 ]]; then
			down_ver="$(cower -s ^${pkg_name}$ | sed -n 1p | awk '{print $2}')"
		else
			down_ver="$(package-query -A ${pkg_name} | awk '{print $2}')"
		fi
		if [[ $down_ver != "" ]]; then
			ret=$(comp_vers $ver $down_ver $comp_op)
			[[ $ret -eq 1 ]] && echo "4" && return
		fi
		echo "0" #dep version cannot be satisfied
	else
		echo "1" #no dep requirement
	fi
}

function handle_deps ()
{
	file="$PWD/PKGBUILD"

	###GET DEPS####
	#Check PKGBUILD and save both "depends" and "makedepends" into two different arrays 
	while read line; do
		if [[ $line == "depends"* ]]; then
			if [[ $line == *")" ]]; then
				DEPENDS=( $(echo "$line" | cut -d"(" -f2 | cut -d")" -f1 | tr -d "\',") )
				break
			else 
				DEPENDS=( $(sed -e '/^depends=(/,/)$/!d' $file | cut -d"(" -f2 | cut -d")" -f1 | tr -d "\',") )
				break
			fi
		fi
	done < "$file"

	###GET MAKE DEPS####
	while read line; do
		if [[ $line == "makedepends"* ]]; then
			if [[ $line == *")" ]]; then
				MAKEDEPENDS=( $(echo "$line" | cut -d"(" -f2 | cut -d")" -f1 | tr -d "\',") )
				break
			else 
				MAKEDEPENDS=( $(sed -e '/^makedepends=(/,/)$/!d' $file | cut -d"(" -f2 | cut -d")" -f1 | tr -d "\',") )
				break
			fi
		fi
	done < "$file"

	###CHECK DEPS VERSION REQUIREMENTS###
	echo -e " ${blue}-> ${white}Dependencies version check: $nc"
	not_sat_ver=0; ver_req=0
	for (( i=0;i<${#DEPENDS[@]};i++ )); do
		ret=$(handle_version ${DEPENDS[$i]})
		[[ $ret -eq 0 ]] && echo -e "${DEPENDS[$i]}: ${red}Cannot satisfy dependency version$nc" && not_sat_ver=$((not_sat_ver+1)) && continue
		[[ $ret -eq 2 ]] && echo -e "${DEPENDS[$i]}: ${green}OK$nc" && DEPENDS[$i]=$(get_pkg_name ${DEPENDS[$i]}) && ver_req=$((ver_req+1)) && continue
		[[ $ret -eq 3 || $ret -eq 4 ]] && echo -e "${DEPENDS[$i]}: ${green}OK$nc" && DEPENDS[$i]=$(get_pkg_name ${DEPENDS[$i]}) && ver_req=$((ver_req+1)) && continue
	done

	for (( i=0;i<${#MAKEDEPENDS[@]};i++ )); do
		ret=$(handle_version ${MAKEDEPENDS[$i]})
		[[ $ret -eq 0 ]] && echo -e "${MAKEDEPENDS[$i]}: ${red}Cannot satisfy dependency version$nc" && not_sat_ver=$((not_sat_ver+1)) && continue
		[[ $ret -eq 2 ]] && echo -e "${MAKEDEPENDS[$i]}: ${green}OK$nc" && MAKEDEPENDS[$i]=$(get_pkg_name ${MAKEDEPENDS[$i]}) && ver_req=$((ver_req+1)) && continue
		[[ $ret -eq 3 || $ret -eq 4 ]] && echo -e "${MAKEDEPENDS[$i]}: ${green}OK$nc" && MAKEDEPENDS[$i]=$(get_pkg_name ${MAKEDEPENDS[$i]}) && ver_req=$((ver_req+1)) && continue
	done
	
	[[ $ver_req -eq 0 ]] && echo "No version requirements"
	[[ $not_sat_ver -gt 0 ]] && return 1
	
	###CHECK DEPS AVAILABILITY###
	# It's necesssary to distinguish between the following kinds of deps: 1) non-AUR deps, 
	#+ 2) AUR deps, 3) non-AUR make deps, and 4) AUR make deps. 
	#+ 1 and 3 are installed via pacman, while 2 and 4 via my custom function "install_aur_pkg"
	#+ 3 and 4, only necessary during package compilation, will be removed after package 
	#+ installation, whereas 1 and 2 won't.
	non_inst_deps=0; not_found=0 #flags
	echo -e " ${blue}-> ${white}Dependencies availability ckeck: $nc"
	for (( i=0;i<${#DEPENDS[@]};i++ )); do 
		echo -n "${DEPENDS[$i]} " 
		if [[ $(pacman -Qq | grep "^${DEPENDS[$i]}$") ]]; then
			echo -e "${white}(installed)$nc"
		elif [[ $(pacman -Ss ^${DEPENDS[$i]}$) ]]; then
			echo -e "${green}(found)$nc"
			DEPS_NEED_INSTALL[${#DEPS_NEED_INSTALL[@]}]=${DEPENDS[$i]}
			non_inst_deps=$((non_inst_deps+1))
		else
			[[ $cower_ok -eq 1 ]] && cmd="cower -s ^${DEPENDS[$i]}$" || cmd="package-query -A --nocolor ${DEPENDS[$i]}"
			eval $cmd &>/dev/null
			if [[ $? -eq 0 ]]; then
				echo -e "${magenta}(AUR)$nc"
				DEPS_NEED_INSTALL_AUR[${#DEPS_NEED_INSTALL_AUR[@]}]=${DEPENDS[$i]}
				AUR_DEPS[${#AUR_DEPS[@]}]=${DEPENDS[$i]}
				non_inst_deps=$((non_inst_deps+1))
			else
				echo -e "${red}(not found)$nc"
				not_found=$((not_found+1))
			fi
		fi
	done
	
	for (( i=0;i<${#MAKEDEPENDS[@]};i++ )); do 
		echo -n "${MAKEDEPENDS[$i]} "
		if [[ $(pacman -Qq | grep "^${MAKEDEPENDS[$i]}$") ]]; then
			echo -e "${white}(installed)$nc [makedepends]"
		elif [[ $(pacman -Ss ^${MAKEDEPENDS[$i]}$) ]]; then
			echo -e "${green}(found)$nc [makedepends]"
			MAKEDEPS_NEED_INSTALL[${#DEPS_NEED_INSTALL[@]}]=${MAKEDEPENDS[$i]}
			non_inst_deps=$((non_inst_deps+1))			
		else
			[[ $cower_ok -eq 1 ]] && cmd="cower -s ^${MAKEDEPENDS[$i]}$" || cmd="package-query -A --nocolor ${MAKEDEPENDS[$i]}"
			eval $cmd &>/dev/null
			if [[ $? -eq 0 ]]; then
				echo -e "${magenta}(AUR)$nc [makedepends]"
				MAKEDEPS_NEED_INSTALL_AUR[${#DEPS_NEED_INSTALL_AUR[@]}]=${MAKEDEPENDS[$i]}
				AUR_DEPS[${#AUR_DEPS[@]}]=${MAKEDEPENDS[$i]}
				non_inst_deps=$((non_inst_deps+1))
			else
				echo -e "${red}(not found)$nc [makedepends]"
				not_found=$((not_found+1))
			fi
		fi
	done

	[[ $not_found -gt 0 ]] && echo -e "\nCannot satisfy dependencies" && return 1
	
	###ASK THE USER WHETHER SHE WANTS TO INSTALL DEPS###
	if [[ $non_inst_deps -gt 0 ]]; then
		echo ""
		answer="none"
		while [[ $answer != "" && $answer != "Y" && $answer != "y" && $answer != "N" && $answer != "n" ]]; do
			read -p "$(echo -e "${blue}:: ${white}Install dependencies? [Y/n] $nc")" answer
		done
		case $answer in
			""|Y|y) ;;
			N|n) return 1;;
		esac
	fi
	
	###INSTALL DEPS###
	if [[ ${#DEPS_NEED_INSTALL[@]} -gt 0 ]]; then
		sudo pacman -S ${DEPS_NEED_INSTALL[@]}
		INSTALLED_DEPS=( $(echo ${DEPS_NEED_INSTALL[@]}) )	
	fi
	if [[ ${#DEPS_NEED_INSTALL_AUR[@]} -gt 0 ]]; then
		for (( i=0;i<${#DEPS_NEED_INSTALL_AUR[@]};i++ )); do			
			# Call a new instance of aurer to install AUR deps. This prevents aurer from
			#+ overwritting the data of the original AUR pkg with that of the AUR dep (which
			#+ happens whenever I call "install_aur_pkg" to install an AUR dep instead of
			#+ calling a new instance of aurer, with a different memory space).
			${DIR}/$0 -S ${DEPS_NEED_INSTALL_AUR[$i]}
			if [[ $? -eq 0 ]]; then
				INSTALLED_DEPS[${#INSTALLED_DEPS[@]}]=${DEPS_NEED_INSTALL_AUR[$i]}
			else
				echo -e "${red}Error:$nc Failed installing '${DEPS_NEED_INSTALL_AUR[$i]}'"
				exit $EXIT_FAILURE
			fi
		done
	fi
	if [[ ${#MAKEDEPS_NEED_INSTALL[@]} -gt 0 ]]; then
		for (( i=0;i<${#MAKEDEPS_NEED_INSTALL[@]};i++ )); do		
			if [[ ${INSTALLED_DEPS[@]} != *"${MAKEDEPS_NEED_INSTALL[$i]}"* ]]; then
				sudo pacman -S ${MAKEDEPS_NEED_INSTALL[$i]}
				# INSTALLED_MAKEDEPS will be removed after package installation
				INSTALLED_MAKEDEPS[${#INSTALLED_MAKEDEPS[@]}]=${MAKEDEPS_NEED_INSTALL[$i]}
			fi
		done
	fi
	if [[ ${#MAKEDEPS_NEED_INSTALL_AUR[@]} -gt 0 ]]; then
		for (( i=0;i<${#MAKEDEPS_NEED_INSTALL_AUR[@]};i++ )); do
			if [[ ${INSTALLED_DEPS[@]} != *"${MAKEDEPS_NEED_INSTALL_AUR[$i]}"* ]]; then
				${DIR}/$0 -S ${MAKEDEPS_NEED_INSTALL_AUR[$i]}
				if [[ $? -eq 0 ]]; then 
					INSTALLED_MAKEDEPS[${#INSTALLED_MAKEDEPS[@]}]=${MAKEDEPS_NEED_INSTALL_AUR[$i]}
				else
					echo -e "${red}Error:$nc Failed installing '${DEPS_NEED_INSTALL_AUR[$i]}'"
					exit $EXIT_FAILURE
				fi
			fi
		done
	fi
	return 0
}

function clean ()
{
	#Remove temp files
	PKG_NAME=$1
	rm -rf ${TEMP_DIR}/${PKG_NAME}
	rm ${TEMP_DIR}/${PKG_NAME}.tar.gz
}

function remove_deps ()
{
	if [[ ${#INSTALLED_DEPS[@]} -gt 0 ]]; then
		echo -e "${green}==> ${white}Removing dependencies... $nc"
		sudo pacman -Rns ${INSTALLED_DEPS[@]}
	fi
}

function remove_make_deps ()
{
	if [[ ${#INSTALLED_MAKEDEPS[@]} -gt 0 ]]; then
		uninst_make_deps=0
		echo -e "${green}==> ${white}Removing make dependencies... $nc"
		# Some pkgs, line urxvtconfig, contains the same dep in
		#+ both "depends" and "makedepends", in which case the make dep, insofar as it is also
		#+ a dependency of the program itself, should not be removed.
		for (( i=0;i<${#INSTALLED_MAKEDEPS[@]};i++ )); do
			if [[ ${INSTALLED_DEPS[@]} != *"${INSTALLED_MAKEDEPS[$i]}"* ]]; then
				sudo pacman -Rns ${INSTALLED_MAKEDEPS[$i]}
				uninst_make_deps=$((uninst_make_deps+1))
			fi
		done
		[[ $uninst_make_deps -eq 0 ]] && echo "There is nothing to do"
	fi
}

function remove_pkg ()
{
	PKG=$1
	ret="$(pacman -Qq | grep ^$PKG$)"
	if [[ $ret != "" ]]; then
		sudo pacman -Rns $PKG
	else
		echo -e "${red}Error:${nc} Target not found: $PKG"
		exit $EXIT_FAILURE
	fi
}

function install_aur_agent ()
{
	args=$1
	#ASK WHICH AUR AGENT TO INSTALL
	echo -e "\n${yellow}1 ${white}cower\n${yellow}2 ${white}package-query$nc\n${yellow}\
3 ${red}quit$nc\n"
	answer="none"
	while [[ $answer != "1" && $answer != "2" && $answer != "3" ]]; do
		read -p "$(echo -e "${blue}:: ${white}Choose an option:$nc ")" answer	
	done
	case $answer in
		1) AUR_AGENT="cower-git" ;;
		2) AUR_AGENT="package-query" ;;
		3) exit $EXIT_SUCCESS ;;
	esac
	
	#INSTALL DEPS
	! [[ $(pacman -Qq | grep ^curl$) ]] && sudo pacman -S curl
	! [[ $(pacman -Qq | grep ^yajl$) ]] && sudo pacman -S yajl
	! [[ $(pacman -Qq | grep ^git$) ]] && sudo pacman -S git
	
	#DOWNLOAD TARBALL
	cd $TEMP_DIR
	echo -ne "${green}==> ${white}Downloading tarball from AUR... $nc"

	eval $DEFAULT_DOWNLOAD_CMD ${DEFAULT_AUR_URL}/${AUR_AGENT}.$COMP_FILE_EXT
	if [[ $? -eq 0 ]]; then
		echo -e "${green}OK$nc"
	else
		echo -e "${red}Error$nc\nCould not retrieve file: ${AUR_AGENT}.$COMP_FILE_EXT"
		exit $EXIT_FAILURE
	fi
	#DECOMPRESS TARBALL
	echo -ne "${green}==> ${white}Decompressing tarball... $nc"
	tar -xvf ${AUR_AGENT}.$COMP_FILE_EXT &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${green}OK$nc"
	else
		echo -e "${red}Error$nc"
		exit $EXIT_FAILURE
	fi
	
	#BUILD AND INSTALL
	cd $AUR_AGENT
	echo -e "${green}==> ${white}Installing '${AUR_AGENT}'... $nc"	
	makepkg -si
	clean $AUR_AGENT	
	
	#RUN ORIGINAL COMMAND
	answer="none"
	while [[ $answer != "" && $answer != "Y" && $answer != "y" && $answer != "n" && $answer != "N" ]]; do
		read -p "$(echo -e "\n${blue}:: ${white}Run your original command ($0 $args)? [Y/n] ")" answer
	done
	case $answer in
		""|Y|y) ;;
		N|n) exit $EXIT_SUCCESS ;;
	esac
}

function install_aur_pkg ()
{
	PKG_NAME=$1
	#CHECK PKG EXISTENCE
	echo -ne "${green}==> ${white}Checking package existence... $nc"
	[[ $cower_ok -eq 1 ]] && cmd="cower -s ^$PKG_NAME$" || cmd="package-query -A $PKG_NAME"
	eval $cmd &>/dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${green}OK$nc"
	else
		echo -e "${red}Error$nc\n: Target not found: ${PKG}" && exit $EXIT_FAILURE
	fi
	#CD INTO TMP DIR AND DOWNLOAD TARBALL IN THERE
	cd $TEMP_DIR
	echo -ne "${green}==> ${white}Downloading tarball from AUR... $nc"
	eval $download_cmd ${aur_url}/${PKG_NAME}.$COMP_FILE_EXT
	if [[ $? -eq 0 ]]; then
		echo -e "${green}OK$nc"
	else
		echo -e "${red}Error$nc\nCould not retrieve file: ${PKG_NAME}.$COMP_FILE_EXT"
		return 1
	fi
	#DECOMPRESS TARBALL
	echo -ne "${green}==> ${white}Decompressing tarball... $nc"
	tar -xvf ${PKG_NAME}.$COMP_FILE_EXT &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "${green}OK$nc"
	else
		echo -e "${red}Error$nc"
		return 1
	fi
	cd $PKG_NAME
	
	#Check whether PKGBUILD exists
	! [[ -f PKGBUILD ]] && echo -e "${red}Error:$nc 'PKGBUILD' not found" && return 1
	
	#Allow the user to edit the PKGBUILD
	answer="none"
	while [[ $answer != "" && $answer != "Y" && $answer != "y" && $answer != "N" && $answer != "n" ]]; do
		read -p "$(echo -e "${blue}:: ${white}Edit PKGBUILD? [Y/n]$nc ")" answer
	done
	case $answer in
		""|Y|y)
			read -p "$(echo -e "${blue} -> ${white}Editor: $nc")" editor
			if [[ $editor != "" ]]; then
				[[ $(command -v $editor) ]] && $editor PKGBUILD || (echo "'$editor': No such file" && editor="")
			else
				[[ $default_editor != "" ]] && (editor=$default_editor && $editor PKGBUILD) || \
																echo "No default editor found"
			fi;;
		*) ;;
	esac

	#Check whether there is some .install file and allow the user to edit it
	if [[ -f ${PKG_NAME}.install ]]; then
	answer="none"
	while [[ $answer != "" && $answer != "Y" && $answer != "y" && $answer != "N" && $answer != "n" ]]; do
		read -p "$(echo -e "${blue}:: ${white}Edit ${PKG_NAME}.install? [Y/n]$nc ")" answer
	done
		case $answer in
			""|Y|y) [[ $editor != "" ]] && $editor ${PKG_NAME}.install ;;
			*) ;;
		esac
	fi

	#HANDLE DEPS###
	echo -e "${green}==> ${white}Checking dependencies for '${PKG_NAME}'... $nc"
	handle_deps
	#If something failed when handling dependencies, or they were not installed, remove the 
	#+tarball and its decompressed directory from TEMP_FILE
	if [[ $? -eq 1 ]]; then 
		clean $PKG_NAME
		exit $EXIT_FAILURE
	fi
	
	##CONFIRM PACKAGE INSTALLATION###
	answer="none"; echo ""
	while [[ $answer != "" && $answer != "Y" && $answer != "y" && $answer != "N" && $answer != "n" ]]; do
		read -p "$(echo -e "${blue}:: ${white}Install '${PKG_NAME}'? [Y/n]$nc ")" answer
	done
	case $answer in
		""|Y|y) ;;
		N|n) 
			clean $PKG_NAME
			remove_deps
			remove_make_deps
			exit $EXIT_SUCCESS ;;
	esac
	
	#INSTALL PACKAGE
	echo -e "${green}==> ${white}Installing '${PKG_NAME}'... $nc"	
	makepkg -si
	clean $PKG_NAME
	remove_make_deps
}

###MAIN####

#CHECK AURER DEPS (pacman && (cower || package-query))
! [[ $(command -v pacman) ]] && echo -e "${red}Error:$nc Pacman not found. Aurer can run only \
on Arch Linux or on an Arch-based Linux distribution" && exit $EXIT_FAILURE

[[ ! $(command -v cower) && ! $(command -v package-query) ]] && echo -e "${red}Error:$nc \
Either ${white}cower$nc or ${white}package-query$nc is required by $prog_name" && \
																install_aur_agent $@

# GET AURER CURRENT WORKING DIRECTORY (CWD). 
#+ This value will be used to recall the script (from within the scripts itself) when 
#+ installing AUR deps (to avoid overwritting original data: install_aur_pkg -> handle_deps -> 
#+ install_aur_pkg).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

#CREATE CONFIG FILE
! [[ -d $CONFIG_DIR ]] && mkdir $CONFIG_DIR
if ! [[ -f ${CONFIG_DIR}/${CONFIG_FILE} ]]; then
	echo -e "Aurer Configuration File
########################
aur_agent=cower
aur_url=$DEFAULT_AUR_URL
download_cmd=wget -q
#download_cmd=curl -L -O" > ${CONFIG_DIR}/${CONFIG_FILE}
fi

[[ $# -eq 0 ]] && echo -e "$prog_name: Missing operand\nTry 'aurer -h' for help" && exit $EXIT_FAILURE

###PARSE CONFIG FILE###

#GET AUR-AGENT
#At this point, either cower or package-query is installed. Therefore, if cower is not defined
#+in the config file as the aur_agent and/or cower is not installed, package-query will be the
#+aur_agent, which is what cower_ok=0 means.
if [[ $(grep "^aur_agent=" "${CONFIG_DIR}/${CONFIG_FILE}" | cut -d"=" -f2) == "cower" ]]; then
	[[ $(command -v cower) ]] && cower_ok=1 || cower_ok=0
else
	cower_ok=0
fi

#GET AUR URL
aur_url="$(grep "^aur_url=" "${CONFIG_DIR}/${CONFIG_FILE}" | cut -d"=" -f2)"
[[ $aur_url == "" ]] && aur_url=$DEFAULT_AUR_URL

#GET DOWNLOAD COMMAND
download_cmd="$(grep "^download_cmd=" "${CONFIG_DIR}/${CONFIG_FILE}" | cut -d"=" -f2)"
[[ $download_cmd == "" ]] && download_cmd=$DEFAULT_DOWNLOAD_CMD

#CREATE TMP DIR, IF IT DOESN'T EXIST YET
! [[ -d $TEMP_DIR ]] && mkdir $TEMP_DIR

#DEFINE DEFAULT EDITOR TO EDIT PKGBUILD'S AND .INSTALL FILES
[[ $EDITOR ]] && default_editor=$EDITOR || ([[ $(command -v nano) ]] && default_editor="nano" \
																		|| default_editor="")

#PARSE OPTIONS
OPTION=$1; shift; PKG="$@"
#Shift will move all positional parameters one place to the left, so that $@ will be what 
#+originally was $2, $3, $4, and so on, without $1 (OPTION). 

case $OPTION in
	-a|--aur-agent) echo -n "AUR agent: "; [[ $cower_ok -eq 1 ]] && echo -e "${white}cower$nc" || echo -e "${white}package-query$nc" ;;

	-h|--help|help) help ;;

	-R|--remove) remove_pkg $PKG ;;

	-Ss|--search) 
		[[ $cower_ok -eq 1 ]] && cower -s --color=always $PKG || package-query -sA $PKG ;;

	-Sn|--search-name) 
		[[ $cower_ok -eq 1 ]] && cower -s --color=always "^$PKG$" || package-query -A $PKG ;;

	-Sw|--download-only)
		echo -ne "${green}==> ${white}Checking package existence... $nc"
		[[ $cower_ok -eq 1 ]] && cmd="cower -s ^$PKG$" || cmd="package-query -A $PKG"
		eval $cmd &>/dev/null
		if [[ $? -eq 0 ]]; then
			echo -e "${green}OK$nc"
			echo -ne "${green}==> ${white}Downloading tarball from AUR... $nc"
			eval $download_cmd ${aur_url}/${PKG}.$COMP_FILE_EXT
			if [[ $? -eq 0 ]]; then 
				echo -e "${green}OK$nc"
			else
				echo -e "${red}Error$nc\nCould not retrieve file: ${PKG}.$COMP_FILE_EXT"
				exit $EXIT_FAILURE
			fi
		else
			echo -e "${red}Error$nc\ncTarget not found: $PKG"
			exit $EXIT_FAILURE
		fi ;;

	-Si|--info)
		[[ $cower_ok -eq 1 ]] && cower -i --color=always $PKG || (echo "$prog_name: Option only available for 'cower'" && exit $EXIT_FAILURE) ;;

	-S|--sync) install_aur_pkg $PKG ;;

	-u|--updates)
		[[ $cower_ok -ne 1 ]] && package-query -Au || cower -u --color=always ;;

	-v|--version) echo -e "$prog_name $version ($date)\nCopyright (C) 2018 $authorLincese GPL2 or later\nThis is free software: you are free to change and redistribute it.There is NO WARRANTY, to the extent permitted by law." ;;

	*)
		echo -e "${red}Error:$nc Invalid option -- '$(echo $OPTION | sed 's/-//g')'
Try 'aurer -h' for help"
		exit $EXIT_FAILURE ;;
esac

exit $EXIT_SUCCESS
