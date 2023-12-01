#!/bin/sh
disk="/dev/sda"
index=1
efibootmgr -c -d "$disk" -p "$index" -L "rEFInd" -l "\EFI\BOOT\BOOTx64.efi"
