#!/bin/sh

#A simple, KISS AUR helper written in Bash. With less than 200 lines of code and just one file, 
#+it can be easily modified and customized by the user.

#TODO list:
#Handle dependencies version!!

! [[ $(command -v pacman) ]] && echo "Aurer can run only on Arch Linux or on an Arch-based \
Linux distribution" && exit 1

###COLORS###
white="\033[1;37m"
red="\033[1;31m"
green="\033[1;32m"
cyan="\033[1;36m"
magenta="\033[1;35m"
#blue="\033[1;34m"
#yellow="\033[1;33m"
#d_red="\033[0;31m"
#d_yellow="\033[0;33m"
#d_cyan="\033[0;36m"
#d_green="\033[0;32m"
nc="\033[0m"

###PROGRAM DATA###
prog_name="aurer"
version="0.0.2"
date="Feb 26, 2018"
author="L. M. Abramovich"

###FUNCTIONS####

function help ()
{
	echo "$prog_name $version ($date), by $author"
	echo -e "A simple, KISS AUR helper\n"
	echo "Usage: aurer [options] [pkg_name]"
	echo -e "\t-Ss | --search string\t\tSearch a package in the AUR. \"string\" is either the \
package name or a keyword describing the package. E.g. aurer -Ss 'terminal emulator'"
	echo -e "\t-Ssi | --search-name string\tDisplay those packages in the AUR exactly matching \"string\""
	echo -e "\t-Sw | --download-only\t\tDownload the package but do not install it"
	echo -e "\t-S | --sync pkg_name\t\tInstall an AUR package"
	echo -e "\t-u | --updates\t\t\tCheck installed AUR packages for updates\n"
}

function handle_deps ()
{
	non_inst_deps=0; not_found=0 #flags
	#Check both "depends" and "makedepends"
	#Parse and save into array
	#This will ignore dependencies version. FIX!!!
	DEPENDS=( $(grep "^depends" PKGBUILD | cut -d")" -f1 | cut -d"(" -f2 | sed 's/[=|.][0-9]//g' | sed 's/[>|<]//g' | tr -d "\',") )
	MAKEDEPENDS=( $(grep "^makedepends" PKGBUILD | cut -d")" -f1 | cut -d "(" -f2 | sed 's/[=|.][0-9]//g' | sed 's/[>|<]//g' | tr -d "\',") )
	#List dependencies and check source availability
	for (( i=0;i<${#DEPENDS[@]};i++ )); do 
		echo -n "${DEPENDS[$i]} " 
		if [[ $(pacman -Qq | grep "^${DEPENDS[$i]}$") ]]; then
			echo -e "${white}(installed)$nc"
		elif [[ $(pacman -Ss ^${DEPENDS[$i]}$) ]]; then
			echo -e "${green}(found)$nc"
			non_inst_deps=$((non_inst_deps+1))
			eval ${DEPENDS[$i]}_state="found"
		elif [[ $(package-query -A --nocolor ${DEPENDS[$i]}) ]]; then
			echo -e "${magenta}(AUR)$nc"
			non_inst_deps=$((non_inst_deps+1))
			eval ${DEPENDS[$i]}_state="aur"
		else
			echo -e "${red}(not found)$nc"
			not_found=$((not_found+1))
		fi
	done
	
	[[ $not_found -gt 0 ]] && echo -e "\nCannot satisfy dependencies" && return 1
	for (( i=0;i<${#MAKEDEPENDS[@]};i++ )); do 
		echo -n "${MAKEDEPENDS[$i]} "
		if [[ $(pacman -Qq | grep "^${MAKEDEPENDS[$i]}$") ]]; then
			echo -e "${white}(installed)$nc [makedepends]"
		elif [[ $(pacman -Ss ^${MAKEDEPENDS[$i]}$) ]]; then
			echo -e "${green}(found)$nc [makedepends]"
			non_inst_deps=$((non_inst_deps+1))			
			eval ${MAKEDEPENDS[$i]}_state="found"
		elif [[ $(package-query -A --nocolor ${MAKEDEPENDS[$i]}) ]]; then
			echo -e "${magenta}(AUR)$nc [makedepends]"
			non_inst_deps=$((non_inst_deps+1))
			eval ${MAKEDEPENDS[$i]}_state="aur"
		else
			echo -e "${red}(not found)$nc [makedepends]" && return 1
		fi
	done

	if [[ $non_inst_deps -gt 0 ]]; then
		echo ""; read -p "Install dependencies? [Y/n] " answer
		case $answer in
			""|Y|y) ;;
			N|n) return 1;;
			*) echo "'$answer': Invalid answer" && return 1;;
		esac
	fi

	for (( i=0;i<${#DEPENDS[@]};i++ )); do
		if [[ ${DEPENDS[$i]}_state == "found" ]]; then
			sudo pacman -S ${DEPENDS[$i]}
			INSTALLED_DEPS[${#INSTALLED_DEPS[@]}]=${DEPENDS[$i]}
		elif [[ ${DEPENDS[$i]}_state == "aur" ]]; then 
			install_aur_pkg ${DEPENDS[$i]}
			INSTALLED_DEPS[${#INSTALLED_DEPS[@]}]=${DEPENDS[$i]}
		fi
	done
	for (( i=0;i<${#MAKEDEPENDS[@]};i++ )); do
		if [[ ${MAKEDEPENDS[$i]}_state == "found" ]]; then
			sudo pacman -S ${MAKEDEPENDS[$i]}
			INSTALLED_MAKEDEPS[${#INSTALLED_MAKEDEPS[@]}]=${MAKEDEPENDS[$i]}
		elif [[ ${MAKEDEPENDS[$i]}_state == "found" ]]; then
			install_aur_pkg ${MAKEDEPENDS[$i]}
			INSTALLED_MAKEDEPS[${#INSTALLED_MAKEDEPS[@]}]=${MAKEDEPENDS[$i]}
		fi
	done
	return 0
}

function install_aur_pkg ()
{
	PKG_NAME=$1
	cd $TEMP_DIR
	echo -e "\n${cyan}Downloading snapshot from the AUR... $nc"
	curl -L -O https://aur.archlinux.org/cgit/aur.git/snapshot/${PKG_NAME}.tar.gz
	[[ $? -ne 0 ]] && echo -e "\n${red}Error:$nc Failed retrieving $PKG_NAME" && return 1
	echo -e "\n${cyan}Decompressing snapshot... $nc"
	tar -xvf ${PKG_NAME}.tar.gz
	[[ $? -ne 0 ]] && return 1
	cd $PKG_NAME
	#Check whether PKGBUILD exists
	! [[ -f PKGBUILD ]] && echo -e "${red}Error:$nc 'PKGBUILD' not found" && return 1
	#Allow the user to edit the PKGBUILD
	echo ""; read -p "Edit PKGBUILD? [Y/n] " answer
	case $answer in
		""|Y|y)
			read -p "Editor: " editor
			if [[ $editor != "" ]]; then
				[[ $(command -v $editor) ]] && $editor PKGBUILD || (editor="" && \
													echo "'$editor': No such file")
			else
				[[ $default_editor != "" ]] && (editor=$default_editor && $editor PKGBUILD) || \
																echo "No default editor found"
			fi;;
		*) ;;
	esac
	#Check whether ${PKG_NAME}.install exists and allow the user to edit it
	if [[ -f ${PKG_NAME}.install ]]; then
		echo ""; read -p "Edit ${PKG_NAME}.install? [Y/n] " answer
		case $answer in
			""|Y|y) [[ $editor != "" ]] && $editor ${PKG_name}.install ;;
			*) ;;
		esac
	fi
	echo -e "\n${cyan}Checking dependencies for '${PKG_NAME}'... $nc"
	handle_deps; [[ $? -eq 1 ]] && exit 1
	echo -e "\n${cyan}Installing '${PKG_NAME}'... $nc"	
	makepkg -si
	#Remove installed make dependencies, if any
	if [[ ${#INSTALLED_MAKEDEPS[@]} -gt 0 ]]; then
		echo -e "\n${cyan}Removing make dependencies... $nc"
		for (( i=0;i<${#INSTALLED_MAKEDEPS[@]};i++ )); do 
			sudo pacman -Rns ${INSTALLED_MAKEDEPS[$i]}
		done
	fi
	return 0
}

###MAIN####

[[ $# -eq 0 || $1 == "help" || $1 == "-h" || $1 == "--help" ]] && help && exit 0

! [[ $(command -v package-query) ]] && echo "$prog_name: Dependency error: package-query is \
not installed. 

How to install 'package-query':
1) Add the 'archlinuxfr' (unofficial) repository to the end of your /etc/pacman.conf:
  [archlinuxfr]
  SigLevel = Never
  Server = http://repo.archlinux.fr/\$arch
2) Update pacman database:
 # pacman -Sy
3) Install the package:
 # pacman -S package-query

NOTE: After installing 'package-query' you can remove [archlinuxfr] from your repos by deleting \
or simply commenting the corresponding lines." && exit 1

[[ $EDITOR ]] && default_editor=$EDITOR || ([[ $(command -v nano) ]] && default_editor="nano" \
																		|| default_editor="")
OPTION=$1; shift; PKG="$@"; TEMP_DIR="/tmp/aurer"
#Shift will move all positional parameters one place to the left, so that $@ will be what 
#+originally was $2, $3, $4, and so on, without $1. 

! [[ -d $TEMP_DIR ]] && mkdir $TEMP_DIR

case $OPTION in
	-Ss|--search) package-query -sA $PKG ;;
	-Ssi|--search-name) package-query -A $PKG ;;
	-Sw|--download-only)
		echo -ne "${cyan}Checking package existence... $nc"
		if [[ $(package-query -A $PKG) ]]; then
			echo -e "${green}OK$nc"
			curl -L -O https://aur.archlinux.org/cgit/aur.git/snapshot/${PKG}.tar.gz
		else
			echo "'${PKG}': package does not exist"
		fi ;;
	-S|--sync) 
		echo -ne "${cyan}Checking package existence... $nc"
		if [[ $(package-query -A $PKG) ]]; then
			echo -e "${green}OK$nc"; install_aur_pkg $PKG; rm -rf $TEMP_DIR
		else
			echo "'${PKG}': package does not exist"
		fi ;;
	-u|--updates) package-query -Au ;;
	*) help ;;
esac

exit 0
