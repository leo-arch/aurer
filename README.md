# Aurer
> A simple, KISS AUR helper written in Bash

Aurer (AUR helpER) is mainly intended to help the user to learn and understand how an AUR package is installed, showing all the 3 basic steps involved in this process: 
* Tarball download (via `curl`)
* Tarball decompression (via `tar`)
* Package build and installation (via `makepkg`)

Besides AUR packages installation, Aurer also inlcudes the following functions:

* Edition "on the fly" of PKGBUILD and .install files
* Dependencies handling
* Search packages in the AUR
* Check available updates for installed AUR packages 

With less than 200 lines of code, and being only one source file, it may be easily modified and customized by the user. "I give you only a minimal program. Learn about it and make it your own"; this is the motto of the KISS principle, and this is what this script is aimed to do.

## Installing Aurer:

First of all, Aurer depends, just as Yaourt, on `package-query` to query the AUR for available packages. To install `package-query` follow these steps:

1. Add these lines at the end of you `/etc/pacman.conf`:
```
[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/$arch
```

2. Update `pacman` database:

`# pacman -Sy`

3. Install `package-query`:

`# pacman -S package-query`

NOTE: Once `package-query` is installed, you may remove `[archlinuxfr]` by simply deleting or commenting the corresponding lines in `/etc/pacman.conf`

Now, you can donwload and install Aurer:

1. Clone or download the project files (**no compilation nor installation** is required)

       $ git clone https://github.com/leo-arch/aurer

2. Excecute the script:
    
       $ cd aurer
       $ ./aurer.sh

## Options:

**-Ss** [string]     Search for a package in the AUR. `string` is either the package name or a keyword describing the package. E.g.           `aurer -Ss "terminal emulator"`

**-Ssi** [string]    Display those packages in the AUR exactly matching `string`

**-Sw** [pkg_name]   Download `pkg_name` but do not install it

**-S** [pkg_name]    Download, build and install `pkg_name`

**-u**               Check installed AUR packages for updates

### NOTE:
Being only a beta version, Aurer does not handle dependencies version yet. Feel free to modify it to achieve this or wathever else you want it to do.
