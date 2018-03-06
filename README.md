# Aurer
> A simple, KISS AUR helper written in Bash

![alt_tag](https://github.com/leo-arch/aurer/blob/master/aurer.png)

Aurer (AUR helpER) is, just as any other AUR helper out there, mainly intended to automate all the 3 basic steps involved in the process of installing a package from the AUR: 
* Tarball download (via `curl` or `wget`)
* Tarball decompression (via `tar`)
* Package build and installation (via `makepkg`)

Besides AUR packages installation, Aurer also inlcudes the following features:

* Edition "on the fly" of PKGBUILD and .install files
* Dependencies resolution
* AUR packages search
* Updates check for installed AUR packages 

## Installing Aurer:

1. Clone or download the project files (**no compilation nor installation** is required)

       $ git clone https://github.com/leo-arch/aurer

2. Excecute the script:
    
       $ cd aurer
       $ ./aurer.sh

### NOTE: 
Aurer depends either on `cower` or on `package-query` to query the AUR. If none of them is installed, Aurer will ask you which one you want to use and will then automatically install it.

## Options:

**-a**               Show currently used AUR agent

**-h**               Show this help and exit

**-R** [pkg_name]    Remove `pkg_name`

**-Ss** [string]     Search for a package in the AUR. `string` could be either the package name or a keyword describing the package. E.g.           `aurer -Ss "terminal emulator"`

**-Sn** [string]     Display those packages in the AUR exactly matching `string`

**-Sw** [pkg_name]   Download `pkg_name` but do not install it

**-S** [pkg_name]    Download, build and install `pkg_name`

**-u**               Check updates for installed AUR packages

**-v**               Show program version and exit

Configuration file: `$HOME/.config/aurer/.aurerrc`
