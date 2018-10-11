# Asterisk with PJSIP Google Voice support on Raspberry Pi 3 Model B/B+ on Ubuntu Bionic

This repository contains scripts to automate the steps to:
- Create a bootable SD card with Ubuntu Bionic that can be booted on a Raspberry Pi 3 Model B/B+
- Update raspberrypi packages and kernel for Paspberry Pi 3 Model B/B+
- Install pre-requisites for compiling asterisk
- Fetch and compile asterisk (15) from [naf419's asterisk repository](https://github.com/naf419/asterisk)
- Create a DEB file with Requires set to (subsequently) install without having to compile asterisk
- Use a template file included in ```/etc/asterisk/pjsip.conf``` to enter your secret Google Voice OAuth details
- Do all the above from the command line, without needing Apache2, PHP, FreePBX etc

# Credits
- [naf419](https://github.com/naf419) for his work on patching asterisk to work with Google Voice
- [Bill Simon (Simon telephonics)](https://simonics.com/) for his GV-SIP gateway that many of used for years
- [HOWTO I used to test GV using FreePBX](https://community.freepbx.org/t/how-to-guide-for-google-voice-with-freepbx-14-asterisk-gvsip-ubuntu-18-04/50933/1)

# Why did I create these scripts




