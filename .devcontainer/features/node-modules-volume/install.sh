#!/bin/bash
set -e

echo "Node modules volume mount feature"
echo "Target: $TARGET"

# Create a script with target path embedded
cat > /usr/local/bin/setup-node-modules-symlink << EOF
#!/bin/bash
TARGET_PATH="$TARGET"
VOLUME_PATH="/mnt/node_modules_volume"

# Ensure volume has correct ownership
sudo chown "\$(whoami)" "\$VOLUME_PATH"

# Create symlink if target doesn't exist or is empty directory
if [ ! -e "\$TARGET_PATH" ] || [ -z "\$(ls -A "\$TARGET_PATH" 2>/dev/null)" ]; then
    rm -rf "\$TARGET_PATH"
    ln -s "\$VOLUME_PATH" "\$TARGET_PATH"
    echo "Created symlink: \$TARGET_PATH -> \$VOLUME_PATH"
else
    echo "Target already exists and is not empty: \$TARGET_PATH"
fi
EOF

chmod +x /usr/local/bin/setup-node-modules-symlink

echo "Feature installed."
