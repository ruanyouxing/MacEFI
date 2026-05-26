echo "=== macefi-sync: Starting..."

if [ ! -d "$EFI_MOUNT/EFI" ]; then
  echo "Warning: EFI mount point $EFI_MOUNT/EFI not found. Skipping sync."
  exit 0
fi

echo "Syncing MacEFI files to $EFI_MOUNT..."

mkdir -p "$EFI_MOUNT/EFI/BOOT" 2>/dev/null || true
mkdir -p "$EFI_MOUNT/EFI/OC" 2>/dev/null || true

echo "Copying rEFInd (BOOT)..."
cp -rf "$MACEFI_PKG/BOOT"/* "$EFI_MOUNT/EFI/BOOT/" 2>&1 || echo "Warning: Failed to copy BOOT"

echo "Copying OpenCore (OC)..."
cp -rf "$MACEFI_PKG/OC"/* "$EFI_MOUNT/EFI/OC/" 2>&1 || echo "Warning: Failed to copy OC"

if [ -d "$MACEFI_PKG/tools" ]; then
  mkdir -p "$EFI_MOUNT/EFI/tools" 2>/dev/null || true
  echo "Copying EFI tools..."
  cp -rf "$MACEFI_PKG/tools"/* "$EFI_MOUNT/EFI/tools/" 2>/dev/null || true
fi

echo "MacEFI files synced successfully."
exit 0
