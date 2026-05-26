echo "=== macefi-boot-entry: Starting..."

if [ ! -x "$EFIBOOTMGR" ]; then
  echo "Warning: efibootmgr not found"
  exit 0
fi

if [ ! -d "/sys/firmware/efi/efivars" ]; then
  echo "Warning: EFI variables not available. Not booted in UEFI mode?"
  exit 0
fi

EFI_DISK=""
EFI_PART=""

for blk in /sys/block/*; do
  devname=$(basename "$blk")
  for part in "$blk"/"$devname"*; do
    [ -e "$part" ] || continue
    partname=$(basename "$part")
    mountpoint=$(findmnt -n -o TARGET "/dev/$partname" 2>/dev/null || true)
    if [ "$mountpoint" = "$EFI_MOUNT" ]; then
      EFI_DISK="/dev/$devname"
      EFI_PART=$(echo "$partname" | sed -e "s/^$devname//")
      break 2
    fi
  done
done

BOOT_ENTRY_LABEL="MacEFI rEFInd"
BOOT_ENTRY_PATH="\\EFI\\BOOT\\BOOTx64.efi"

echo "Checking for existing boot entry: $BOOT_ENTRY_LABEL"

EXISTING_ENTRY=""
while IFS= read -r line; do
  if echo "$line" | grep -qFi "$BOOT_ENTRY_LABEL"; then
    EXISTING_ENTRY=$(echo "$line" | grep -oP 'Boot\K[0-9A-Fa-f]{4}')
    break
  fi
done < <($EFIBOOTMGR -v 2>/dev/null || true)

CURRENT_ORDER=$($EFIBOOTMGR 2>/dev/null | grep -i "BootOrder" | cut -d: -f2 | tr -d ' ' || true)

if [ -n "$EXISTING_ENTRY" ]; then
  echo "Found existing boot entry: Boot$EXISTING_ENTRY"

  if [ -n "$CURRENT_ORDER" ]; then
    FIRST_IN_ORDER=$(echo "$CURRENT_ORDER" | cut -d, -f1)
    if [ "$FIRST_IN_ORDER" != "$EXISTING_ENTRY" ]; then
      echo "Setting $BOOT_ENTRY_LABEL as first boot entry..."
      NEW_ORDER="$EXISTING_ENTRY,$(echo "$CURRENT_ORDER" | sed -e "s/$EXISTING_ENTRY//g" -e 's/,,*/,/g' -e 's/^,//' -e 's/,$//')"
      $EFIBOOTMGR -o "$NEW_ORDER" 2>&1 || echo "Warning: Could not set boot order"
    else
      echo "$BOOT_ENTRY_LABEL is already the first boot entry."
    fi
  fi
else
  echo "Creating new boot entry: $BOOT_ENTRY_LABEL"

  CREATE_FAILED=0
  if [ -n "$EFI_DISK" ] && [ -n "$EFI_PART" ]; then
    $EFIBOOTMGR --create --disk "$EFI_DISK" --part "$EFI_PART" --label "$BOOT_ENTRY_LABEL" --loader "$BOOT_ENTRY_PATH" 2>&1 || CREATE_FAILED=1
  else
    $EFIBOOTMGR --create --label "$BOOT_ENTRY_LABEL" --loader "$BOOT_ENTRY_PATH" 2>&1 || CREATE_FAILED=1
  fi

  if [ $CREATE_FAILED -eq 1 ]; then
    echo "Warning: Failed to create boot entry. You may need to create it manually:"
    echo "  efibootmgr --create --label \"$BOOT_ENTRY_LABEL\" --loader \"$BOOT_ENTRY_PATH\""
    exit 0
  fi

  echo "Boot entry created."

  if [ -n "$CURRENT_ORDER" ]; then
    NEW_ENTRY_NUM=$($EFIBOOTMGR -v 2>/dev/null | grep -i "$BOOT_ENTRY_LABEL" | grep -oP 'Boot\K[0-9A-Fa-f]{4}' || true)
    if [ -n "$NEW_ENTRY_NUM" ]; then
      echo "Setting $BOOT_ENTRY_LABEL as first boot entry..."
      NEW_ORDER="$NEW_ENTRY_NUM,$CURRENT_ORDER"
      $EFIBOOTMGR -o "$NEW_ORDER" 2>&1 || echo "Warning: Could not set boot order"
    fi
  fi
fi

echo "Boot entry management completed."
exit 0
