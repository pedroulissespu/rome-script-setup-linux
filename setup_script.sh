#!/bin/bash
# Color settings for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No color

# Log file
LOG_FILE="/tmp/install_script.log"
touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE" 2>/dev/null || true

# Associative array for step statuses
declare -A steps_status=(
    ["Install Dependencies"]="Pending"
    ["Install Robotool"]="Pending"
    ["Create Robotool Shortcut"]="Pending"
    ["Adjust Robotool Permissions"]="Pending"
    ["Install Atelier B"]="Pending"
    ["Extract and Move Atelier B"]="Pending"
    ["Adjust Atelier B Permissions"]="Pending"
    ["Create Atelier B Shortcut"]="Pending"
    ["Final Cleanup"]="Pending"
)

# Function to log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to print the status of steps in the terminal
print_status() {
    clear
    echo "Step status:"
    for step in "Install Dependencies" "Install Robotool" "Create Robotool Shortcut" "Adjust Robotool Permissions" \
                "Install Atelier B" "Extract and Move Atelier B" "Adjust Atelier B Permissions" \
                "Create Atelier B Shortcut" "Final Cleanup"; do
        status="${steps_status[$step]}"
        case "$status" in
            "Completed")
                echo -e "$step: ${GREEN}$status${NC}" ;;
            "In progress")
                echo -e "$step: ${YELLOW}$status${NC}" ;;
            "ERROR")
                echo -e "$step: ${RED}$status${NC}" ;;
            *)
                echo -e "$step: $status" ;;
        esac
    done
    echo ""
}

# Function to execute a step, update status and handle errors
run_step() {
    local step_name="$1"
    shift
    steps_status["$step_name"]="In progress"
    print_status
    log "$step_name started."
    
    # Execute the passed command or function
    "$@"
    local ret=$?
    if [ $ret -eq 0 ]; then
        steps_status["$step_name"]="Completed"
        log "$step_name completed successfully."
    else
        steps_status["$step_name"]="ERROR"
        log "$step_name failed with code $ret."
        print_status
        echo -e "${RED}An error occurred in '$step_name'. Closing the script.${NC}"
        exit 1
    fi
    print_status
}

########################
#    Step Functions    #
########################

# 1. Install Dependencies
install_dependencies() {
    local distro_id
    distro_id=$(grep -oP '^ID=\K\w+' /etc/os-release | tr '[:upper:]' '[:lower:]')
    case $distro_id in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get update && sudo apt-get install -y wget unzip binutils zstd imagemagick
            ;;
        fedora|centos|rhel)
            sudo dnf install -y wget unzip binutils zstd ImageMagick
            ;;
        opensuse*|sles)
            sudo zypper install -y wget unzip binutils zstd ImageMagick
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm wget unzip binutils zstd imagemagick
            ;;
        *)
            echo "Unsupported distribution: $distro_id" >&2
            return 1
            ;;
    esac
}

# 2. Install Robotool
step_install_robotool() {
    cd /tmp/ || return 1
    wget https://github.com/UoY-RoboStar/robotool/releases/download/v1.1.2025022101/robotool.product-linux.gtk.x86_64.zip || return 1
    sudo mkdir -p /opt/robotool || return 1
    sudo unzip robotool.product-linux.gtk.x86_64.zip -d /opt/robotool/ || return 1
    sudo chmod +x /opt/robotool/eclipse || return 1
}

# 3. Create shortcut for Robotool
step_create_robotool_shortcut() {
    local USER_HOME=$(getent passwd $(logname) | cut -d: -f6)  # Crucial fix
    mkdir -p "$USER_HOME/.local/share/applications" || return 1
    
    # Icon conversion with verification
    if ! convert /opt/robotool/icon.xpm /opt/robotool/icon.png; then
        echo "Icon conversion failed, using fallback"
        sudo cp /opt/robotool/icon.xpm /opt/robotool/icon.png
    fi

    cat << EOF > "$USER_HOME/.local/share/applications/robotool.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Robotool
Icon=/opt/robotool/icon.png
Exec=env GDK_BACKEND=x11 /opt/robotool/eclipse
Comment=Robotool
Terminal=false
Categories=Development
EOF

    # Update icons without error messages
    gtk-update-icon-cache >/dev/null 2>&1 || true
    rm -f /tmp/robotool.product-linux.gtk.x86_64.zip
}

# 4. Adjust Robotool permissions
step_adjust_robotool_permissions() {
    if [ -d "/opt/robotool" ]; then
        sudo chmod -R 755 /opt/robotool/eclipse || return 1
        sudo chmod +x ~/.local/share/applications/robotool.desktop || return 1
    else
        echo "Folder /opt/robotool not found." >&2
        return 1
    fi
}

# 5. Install Atelier B (initial download and extraction)
step_install_atelierb() {
    cd /tmp/ || return 1
    wget "https://www.atelierb.eu/wp-content/uploads/2024/09/atelierb-cssp-24.04-ubuntu-24.04.deb" -O atelierb.deb || return 1
    ar x atelierb.deb || return 1
}

# Function to extract Atelier B (used in step 5)
extract_atelier() {
    local data_file="$1"
    echo "Analyzing package structure..."
    mkdir -p /tmp/atelier || return 1
    tar -xf "$data_file" -C /tmp/atelier || return 1
    if [ -d "/tmp/atelier/opt/atelierb-cssp-24.04" ]; then
        echo "Moving Atelier B to /opt..."
        sudo mv /tmp/atelier/opt/atelierb-cssp-24.04 /opt/ || return 1
    else
        echo "The extracted structure does not match what you expected! Please manually inspect the contents of /tmp/atelier." >&2
        return 1
    fi
}

#6. Extract and move Atelier B
step_extract_atelierb() {
    if [ -f data.tar.zst ]; then
        extract_atelier data.tar.zst
    elif [ -f data.tar.gz ]; then
        extract_atelier data.tar.gz
    elif [ -f data.tar.xz ]; then
        extract_atelier data.tar.xz
    else
        echo "Error: File data.tar.* not found!" >&2
        return 1
    fi
}

# 7. Adjust Atelier B permissions
step_adjust_atelierb_permissions() {
    if [ -d "/opt/atelierb-cssp-24.04" ]; then
        sudo chmod -R 755 /opt/atelierb-cssp-24.04/bin/startAB || return 1
    else
        echo "Folder /opt/atelierb-cssp-24.04 not found." >&2
        return 1
    fi
}

# 8. Create shortcut to Atelier B
step_create_atelierb_shortcut() {
    local USER_HOME=$(getent passwd $(logname) | cut -d: -f6)  # Crucial fix
    mkdir -p "$USER_HOME/.local/share/applications" || return 1
    
    cat << EOF > "$USER_HOME/.local/share/applications/atelierb.desktop"
[Desktop Entry]
Name=Atelier B
GenericName=Atelier B
Comment=IDE for B creating B models
Type=Application
Exec=/opt/atelierb-cssp-24.04/bin/startAB
Terminal=false
Icon=/opt/atelierb-cssp-24.04/share/icons/AtelierB128.png
EOF

    # Force refresh icon cache
    gtk-update-icon-cache >/dev/null 2>&1 || true
}

#9. Final cleaning
step_cleanup() {
    rm -f atelierb.deb control.tar.* data.tar.* debian-binary || return 1
}

############################
#    Execution of steps    #
############################

print_status

run_step "Install Dependencies" install_dependencies
run_step "Install Robotool" step_install_robotool
run_step "Create Robotool Shortcut" step_create_robotool_shortcut
run_step "Adjust Robotool Permissions" step_adjust_robotool_permissions
run_step "Install Atelier B" step_install_atelierb
run_step "Extract and Move Atelier B" step_extract_atelierb
run_step "Adjust Atelier B Permissions" step_adjust_atelierb_permissions
run_step "Create Atelier B Shortcut" step_create_atelierb_shortcut
run_step "Final Cleaning" step_cleanup

echo -e "${GREEN}Installation completed successfully!${NC}"
echo "Robotool and Atelier B are available in your applications menu"
log "Script completed successfully."
