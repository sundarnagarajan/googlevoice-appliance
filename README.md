## Asterisk with PJSIP Google Voice support on Raspberry Pi 3 Model B/B+ on Ubuntu Bionic

This repository contains scripts to automate the steps to:
- Create a bootable SD card with Ubuntu Bionic that can be booted on a Raspberry Pi 3 Model B/B+
- Update raspberrypi packages and kernel for Paspberry Pi 3 Model B/B+
- Install pre-requisites for compiling asterisk
- Fetch and compile asterisk (15) from [naf419's asterisk repository](https://github.com/naf419/asterisk)
- Create a DEB file with Requires set to (subsequently) install without having to compile asterisk
- Use a template file included in ```/etc/asterisk/pjsip.conf``` to enter your secret Google Voice OAuth details
- Do all the above from the command line, without needing Apache2, PHP, FreePBX etc

## Credits
- [naf419](https://github.com/naf419) for his work on patching asterisk to work with Google Voice
- [Bill Simon (Simon telephonics)](https://simonics.com/) for his GV-SIP gateway that many of us used for years
- [HOWTO I used to test GV using FreePBX](https://community.freepbx.org/t/how-to-guide-for-google-voice-with-freepbx-14-asterisk-gvsip-ubuntu-18-04/50933/1)
- Various articles on nerdvittles.com, including [this one](http://nerdvittles.com/?p=26204)
- [Google Voice Gateway beta test for SIP interop thread on dslreports.com](https://www.dslreports.com/forum/r31966059-Google-Voice-Gateway-beta-test-for-SIP-interop~start=300)
- Everyone who helped with making asterisk compatible with the new OAuth-SIP interface to Google Voice

## Who needs this
You will probably find this repository useful if you meet one or more of the following criteria:
- You use or want to use [Google Voice](https://voice.google.com]. This probably also means:
    - You make or receive a lot of calls to / from US and Canadian numbers
    - You (probably) live in the US
- You use or want to use [asterisk](https://asterisk.org) - a leading open source PBX
- You (probably) already use asterisk and are fairly comfortable configuring asterisk using files from the command line`
- You **prefer** to configure asterisk using configuration files under ```/etc/asterisk``` using the command line, **rather than using a web-GUI like FreePBX**
- You are comfortable using Linux on the command line
- You are interested in installing a GoogleVoice-compatible version of asterisk on a Raspberry Pi. These scripts are a **bit** specific to using a Raspberry Pi 3 **Model B/B+**, but most of the scripts will work for a Raspberry Pi 2 also

## Why did I create these scripts




