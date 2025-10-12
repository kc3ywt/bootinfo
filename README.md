# Boot Info Install

This guide is to install the "Boot Info" script, which shows you the Hostname and IP Address at boot, or when a ssh terminal is opened.


**THIS SCRIPT WAS CREATED TO BE USED ON DEBIAN 12/13, AND IT MAY NOT FULLY WORK ON OLDER VERSIONS OF DEBIAN OR ANOTHER OS.**

## How to install:
Run as root:

```bash
cd 
apt install git
git clone https://github.com/kc3ywt/bootinfo
chmod +x /bootinfo/install-bootinfo.sh
/bootinfo/install-bootinfo.sh
```

---
If you have any tips or suggestions on how I could make this better, please share.
giourano@gmail.com 
