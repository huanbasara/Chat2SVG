#!/bin/bash

# Auto-setup script for Git and SSH configuration on new instances
# This script should be run when starting a new spot instance

echo "🔧 Setting up Git and SSH configuration from EBS..."

# Create symbolic links for SSH
if [ ! -L ~/.ssh ]; then
    rm -rf ~/.ssh
    ln -s /opt/chat2svg-env/.ssh ~/.ssh
    echo "✅ SSH directory linked from EBS"
else
    echo "✅ SSH directory already linked"
fi

# Create symbolic link for Git config
if [ ! -L ~/.gitconfig ]; then
    rm -f ~/.gitconfig
    ln -s /opt/chat2svg-env/.gitconfig ~/.gitconfig
    echo "✅ Git config linked from EBS"
else
    echo "✅ Git config already linked"
fi

# Set correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Verify Git configuration
echo "📋 Current Git configuration:"
git config --global user.name
git config --global user.email

# Start SSH agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

echo "🎉 Git and SSH setup completed!"
echo ""
echo "🔑 Your SSH public key (add this to GitHub):"
echo "----------------------------------------"
cat ~/.ssh/id_rsa.pub
echo "----------------------------------------"
echo ""
echo "📝 To add this key to GitHub:"
echo "1. Go to https://github.com/settings/keys"
echo "2. Click 'New SSH key'"
echo "3. Copy and paste the above public key"
echo "4. Give it a title like 'AWS Chat2SVG Environment'" 