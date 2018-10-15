## Asterisk with PJSIP Google Voice support on Raspberry Pi 3 Model B/B+ on Ubuntu Bionic

This repository contains scripts to automate the steps to:
- Create a bootable SD card with Ubuntu Bionic that can be booted on a Raspberry Pi 3 Model B/B+
- Update raspberrypi packages and kernel for Paspberry Pi 3 Model B/B+
- Install pre-requisites for compiling asterisk
- Fetch and compile asterisk (15) from [naf419's asterisk repository](https://github.com/naf419/asterisk)
- Create a DEB file with Requires set to (subsequently) install without having to compile asterisk
- Use a template file included in ```/etc/asterisk/pjsip.conf``` to enter your secret Google Voice OAuth details
- Do all the above from the command line, without needing Apache2, PHP, FreePBX etc
- At the end, if you have entered your Google Voice credentials correctly in a single file, asterisk should be running, registered to Google Voice, visible with ```pjsip show registration```
- No SIP client credentials, inward call routing rules or outward calling rules or dial plans are created, but this repository contains some (basic) tips for doing this.

## News
Working on following:
- Support for Raspbian Stretch minimal image
- Integrate [traud/asterisk-opus](https://github.com/traud/asterisk-opus) to get Opus support - [Issue 6](https://github.com/sundarnagarajan/googlevoice-appliance/issues/6)
- See Issues I have opened

## License, code of conduct, goals and policies
Though this is 'non-technical', please familiarize yourself with the following:
- The [LICENSE (GPLv3)](/LICENSE) used for everything on this repository, unless otherwise explicitly indicated
- [Code of conduct](/CODE_OF_CONDUCT.md)
- Please read the [FAQ](/docs/faq.md) before reporting an issue
- If you are a beginner or are not experienced with operating at the Linux command line, please see: [FAQ #1](https://github.com/sundarnagarajan/ast-gv-pjsip-raspi-ubuntu/blob/master/docs/faq.md#1-i-am-new-to-linux--ubuntu--debian-i-do-not-understand-the-instructions)

## Credits
- [naf419](https://github.com/naf419) for his work on patching asterisk to work with Google Voice
- [Bill Simon (Simon telephonics)](https://simonics.com/) for his GV-SIP gateway that many of us used for years
- [HOWTO I used to test GV using FreePBX](https://community.freepbx.org/t/how-to-guide-for-google-voice-with-freepbx-14-asterisk-gvsip-ubuntu-18-04/50933/1)
- Various articles on nerdvittles.com, including [this one](http://nerdvittles.com/?p=26204)
- [Google Voice Gateway beta test for SIP interop thread on dslreports.com](https://www.dslreports.com/forum/r31966059-Google-Voice-Gateway-beta-test-for-SIP-interop~start=300)
- [How-To: Ubuntu Server 18.04.01 (Bionic Beaver) on the Raspberry Pi 3 B+](https://www.invik.xyz/linux/Ubuntu-Server-18-04-1-RasPi3Bp/) or [Wayback Machine](https://web.archive.org/web/20181011231733/https://www.invik.xyz/linux/Ubuntu-Server-18-04-1-RasPi3Bp/)
- [traud/asterisk-opus](https://github.com/traud/asterisk-opus) for Opus patches - useful for Google Voice
- Everyone who helped with making asterisk compatible with the new asterisk-PJSIP-OAuth2 interface to Google Voice

## For the impatient
- Take a look at [directory layout](/docs/directory_layout.md)
- Take a look at [the scripts and usage](/docs/usage.md)
- Take a look at [how to get help](/docs/getting_help.md)

## Who needs this
You will probably find this repository useful if you meet MOST of the criteria below:
- You are comfortable using Linux on the command line
- You use or want to use [asterisk](https://www.asterisk.org) - a leading open source PBX
- You (probably) already use asterisk and are fairly comfortable configuring asterisk using files from the command line. If you are new to asterisk, see [FAQ #2](/docs/faq.md#1-i-am-new-to-linux--ubuntu--debian-i-do-not-understand-the-instructions)
- You **prefer** to configure asterisk using configuration files under ```/etc/asterisk``` using the command line, **rather than using a web-GUI like FreePBX**
- You use or want to use [Google Voice](https://voice.google.com). This probably also means:
    - You make or receive a lot of calls to / from US and Canadian numbers
    - You (probably) live in the US
- You are interested in installing a GoogleVoice-compatible version of asterisk on a Raspberry Pi. These scripts are a **bit** specific to using a Raspberry Pi 3 **Model B/B+**, but most of the scripts will work for a Raspberry Pi 2 also
- You already have asterisk configured with a lot of custom dialplans, calling rules and incoming call routing rules, and want to avoid porting these to FreePBX by provisioning a **second** asterisk server dedicated to routing incoming and outgoing Google Voice calls.
- Your knowledge of Linux is between moderate to expert - the documentation on this repository is not expected to be a guide for users new to Linux. See [FAQ #1](/docs/faq.md#1-i-am-new-to-linux--ubuntu--debian-i-do-not-understand-the-instructions)

## Contributions
See [contributions.md](/contributions.md)

## Why did I create this repository
My situation:
- I have been using asterisk since 2011 (late entrant !)
- I have a multi-site setup with multiple asterisk instances connecting on IAX2 over VPN
- I have quite a bit of custom calling rules, dial plans, DID rules, custom macros and external web applications integrating through AMI/originate to initiate multi-way calls, dial into conference calls for work etc
- I have done extensive work on organizing extensions.conf and other asterisk configuration files using #include and templates
- My asterisk instances already ran on Raspberry pi / Ubuntu xenial
- I am very comfortable with working on the command line in Linux and configuring asterisk in this way. In fact, I **prefer** setting up my Linux box and asterisk form the command line.
- I was already using GoogleVoice integrated with asterisk using [Bill Simon's Google Voice Gateway service](https://simonics.com/gw/)
- I wanted to setup a separate asterisk instance to connect to Google Voice, installing and configuring asterisk from the ground up, preferably compiling asterisk from source, allowing me a clear path to migrate to future versions of asterisk as they come out.
- I did **not** want to use an asterisk instance hosted in the cloud, nor did I want to use a web GUI that would either constrain the configuration I could do using asterisk configuration files, overwrite my changes when I used the web GUI or both. That ruled out using FreePBX

I looked around for guides to get asterisk working (again) with Google Voice working using the new PJSIP-OAuth2 interface, but all the guides I could find explained hot to install FreePBX and make all configuration changes in the web GUI.

I found this [excellent HOWTO](https://community.freepbx.org/t/how-to-guide-for-google-voice-with-freepbx-14-asterisk-gvsip-ubuntu-18-04/50933/1) for compiling and installing asterisk with patches from [naf419's asterisk repository](https://github.com/naf419/asterisk) and installing and configuring Google Voice trunks using FreePBX. I initially tried this in an AMD64 Ubuntu Bionic VirtualBox VM, and found it worked.

I found [How-To: Ubuntu Server 18.04.01 (Bionic Beaver) on the Raspberry Pi 3 B+](https://www.invik.xyz/linux/Ubuntu-Server-18-04-1-RasPi3Bp/) and managed to follow it to get Ubuntu 18.04 Bionic on my Raspberry Pi 3 Model B+. I then used the [HOWTO](https://community.freepbx.org/t/how-to-guide-for-google-voice-with-freepbx-14-asterisk-gvsip-ubuntu-18-04/50933/1) above to get asterisk compiled and working with Google Voice

I wanted to automate most of the steps, so that I could perform them multiple times. One thing led to the next, and the result is this repository, which I hope will be useful to people with similar needs to mine.

## Limitations
- When using Ubuntu 18.04 Bionic, libspeex1 package (wrongly?) conflicts with asterisk package with version > 13. Solution in THAT case is to rename package name in DEB that we build to 'asterisk-gvsip'. See [Issue 2](https://github.com/sundarnagarajan/googlevoice-appliance/issues/2)
- DEB file generated on Ubuntu 18.04 Bionic cannot be installed on Raspbian Stretch minimal and vice versa because I generate a DEB file with dependencies strictly bound to minimum required package versions - and these dependencies (probably) will not be met in the other operating system. Solution is to build from source on each operating system.
- Current scripts do not include support for Opus - required / beneficial for Google Voice. Working on integrating Opus patches from [traud/asterisk-opus](https://github.com/traud/asterisk-opus). Have tries the patches, and Opus support works. See [Issue 6](https://github.com/sundarnagarajan/googlevoice-appliance/issues/6)

## Getting started
### Installation
There is no installation. Just clone the repo, and use the scripts under the [scripts](/scripts) directory.
### Steps




