#!/bin/bash
# Enable options to abort on errors, undefined variables, and pipeline errors
set -euo pipefail

# Function to check if a command is installed
check_command() {
    command -v "$1" >/dev/null 2>&1 || { echo "Command '$1' is not installed. Aborting." >&2; exit 1; }
}

# Verify necessary dependencies
check_command wget
check_command unzip
check_command convert
check_command gtk-update-icon-cache

# Color settings for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No color

# Log file with more restricted permissions
LOG_FILE="/tmp/install_script.log"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

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

# Function to log messages with a timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to print the status of each step
print_status() {
    # Clear the screen only if output is a terminal
    if [ -t 1 ]; then clear; fi
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

# Function to execute a step and handle errors
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
        echo -e "${RED}An error occurred in '$step_name'. Exiting the script.${NC}"
        exit 1
    fi
    print_status
}

# Request elevation of privileges once, if necessary
if [[ $EUID -ne 0 ]]; then
    echo "This script requires administrative privileges. Please enter your password if prompted."
    sudo -v
fi

# Function to determine the correct user home directory
get_user_home() {
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        getent passwd "$SUDO_USER" | cut -d: -f6
    else
        echo "$HOME"
    fi
}

########################
#      Step Functions      #
########################

# 1. Install dependencies
install_dependencies() {
    # Extract distro ID, removing quotes if present
    local distro_id
    distro_id=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
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

# 3. Create Robotool shortcut
step_create_robotool_shortcut() {
    local USER_HOME
    USER_HOME=$(get_user_home)
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

    # Update icon cache without error messages
    gtk-update-icon-cache >/dev/null 2>&1 || true
    rm -f /tmp/robotool.product-linux.gtk.x86_64.zip
}

# 4. Adjust Robotool permissions
step_adjust_robotool_permissions() {
    if [ -d "/opt/robotool" ]; then
        sudo chmod -R 755 /opt/robotool/eclipse || return 1
        local USER_HOME
        USER_HOME=$(get_user_home)
        sudo chmod +x "$USER_HOME/.local/share/applications/robotool.desktop" || return 1
    else
        echo "Directory /opt/robotool not found." >&2
        return 1
    fi
}

# 5. Install Atelier B (initial download and extraction)
step_install_atelierb() {
    cd /tmp/ || return 1
    wget "https://www.atelierb.eu/wp-content/uploads/2024/09/atelierb-cssp-24.04-ubuntu-24.04.deb" -O atelierb.deb || return 1
    ar x atelierb.deb || return 1
}

# Function to extract Atelier B (used in step 6)
extract_atelier() {
    local data_file="$1"
    echo "Analyzing package structure..."
    mkdir -p /tmp/atelier || return 1
    tar -xf "$data_file" -C /tmp/atelier || return 1
    if [ -d "/tmp/atelier/opt/atelierb-cssp-24.04" ]; then
        echo "Moving Atelier B to /opt..."
        sudo mv /tmp/atelier/opt/atelierb-cssp-24.04 /opt/ || return 1
    else
        echo "Extracted structure does not match the expected one! Please manually inspect /tmp/atelier." >&2
        return 1
    fi
}

# 6. Extract and move Atelier B
step_extract_atelierb() {
    if [ -f data.tar.zst ]; then
        extract_atelier data.tar.zst
    elif [ -f data.tar.gz ]; then
        extract_atelier data.tar.gz
    elif [ -f data.tar.xz ]; then
        extract_atelier data.tar.xz
    else
        echo "Error: data.tar.* file not found!" >&2
        return 1
    fi
}

# 7. Adjust Atelier B permissions
step_adjust_atelierb_permissions() {
    if [ -d "/opt/atelierb-cssp-24.04" ]; then
        sudo chmod -R 755 /opt/atelierb-cssp-24.04/bin/startAB || return 1
    else
        echo "Directory /opt/atelierb-cssp-24.04 not found." >&2
        return 1
    fi
}

# 8. Create Atelier B shortcut
step_create_atelierb_shortcut() {
    local USER_HOME
    USER_HOME=$(get_user_home)
    mkdir -p "$USER_HOME/.local/share/applications" || return 1
    
    cat << EOF > "$USER_HOME/.local/share/applications/atelierb.desktop"
[Desktop Entry]
Name=Atelier B
GenericName=Atelier B
Comment=IDE for B model development
Type=Application
Exec=/opt/atelierb-cssp-24.04/bin/startAB
Terminal=false
Icon=/opt/atelierb-cssp-24.04/share/icons/AtelierB128.png
EOF

    # Force update of the icon cache
    gtk-update-icon-cache >/dev/null 2>&1 || true
}

# 9. Final cleanup
step_cleanup() {
    rm -f atelierb.deb control.tar.* data.tar.* debian-binary || return 1
}

############################
#    Execution of Steps    #
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
run_step "Final Cleanup" step_cleanup

echo -e "${GREEN}Installation completed successfully!${NC}"
echo "Robotool and Atelier B are available in your applications menu."
log "Script completed successfully."
