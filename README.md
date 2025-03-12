# Automated Setup Script for RoME Workshop Tools

This script automates the installation and configuration of **Robotool** and **Atelier B**, essential tools used during the **Robotic Mission Engineering International Summer School (RoME)**. It simplifies the setup process for Linux users, ensuring a smooth experience during the workshop.

---

## Table of Contents
- [Features](#features)
- [Supported Distributions](#supported-distributions)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Script Steps](#script-steps)
- [Troubleshooting](#troubleshooting)
- [Logs](#logs)
- [Contact](#contact)

---

## Features
- Installs system dependencies for multiple Linux distributions.
- Downloads and installs **Robotool** (a robotic mission modeling tool).
- Downloads and installs **Atelier B** (a formal method-based IDE for B models).
- Creates desktop shortcuts for both tools.
- Handles permissions and post-install cleanup.

---

## Supported Distributions
- Ubuntu/Debian/Linux Mint/Pop!_OS
- Fedora/CentOS/RHEL
- openSUSE/SLES
- Arch Linux/Manjaro

---

## Prerequisites
- A Linux-based operating system (see [supported distributions](#supported-distributions)).
- `sudo` privileges for package installation.
- Internet connection to download tools and dependencies.
- `wget`, `unzip`, and `tar` utilities (installed automatically by the script).

---

## Usage

1. **Download the Script**  
   Copy the script content into a file named `setup_script.sh`:
   ```bash
   nano setup_script.sh # Paste the script content, then save (Ctrl+O, Ctrl+X).
   ```

2. **Make the Script Executable**
    ```bash
    chmod +x setup_script.sh
    ```

3. **Run the Script**
    ```bash
    sudo ./setup_script.sh
    ```

4. **Follow On-Screen Instructions**  

   The script displays real-time status updates with colored indicators:

   - 🟢 **Completed**: Step succeeded.
   - 🟡 **In progress**: Currently running.
   - 🔴 **ERROR**: Critical failure (script exits immediately).

---

## Script Steps

1. **Install Dependencies**  
   Installs packages like `wget`, `unzip`, `zstd`, and `imagemagick` based on your OS.

2. **Install Robotool**  
   - Downloads Robotool from GitHub.  
   - Extracts it to `/opt/robotool`.  
   - Sets executable permissions.  

3. **Create Robotool Shortcut**  
   Adds a desktop entry to your applications menu. Converts the `.xpm` icon to `.png` if needed.  

4. **Adjust Robotool Permissions**  
   Ensures proper access rights for the installation directory.  

5. **Install Atelier B**  
   Downloads the Atelier B `.deb` package and extracts its contents.  

6. **Extract and Move Atelier B**  
   Moves Atelier B to `/opt/atelierb-cssp-24.04`.  

7. **Adjust Atelier B Permissions**  
   Sets executable permissions for the `startAB` binary.  

8. **Create Atelier B Shortcut**  
   Adds a desktop entry with the correct icon and execution path.  

9. **Final Cleanup**  
   Removes temporary installation files.  

## Troubleshooting

### Common Issues

- **"Icon conversion failed"**: The script falls back to using the `.xpm` icon.  
- **Missing folders (e.g., `/opt/robotool`)**: The script exits on critical errors. Check logs at `/tmp/install_script.log`.  
- **Unsupported OS**: Manual installation may be required for non-listed distributions.  

## Post-Installation

Tools are accessible via your system’s application menu.  

If shortcuts are missing, run:  

    ```bash
    gtk-update-icon-cache
    ```

## Logs

Detailed logs are saved to `/tmp/install_script.log`. Review this file if errors occur:  

    ```bash
    cat /tmp/install_script.log
    ```

## Contact

For issues or questions, open an issue in the repository where this script is hosted.

## Contribution
If you want to contribute to the script, follow these steps:
1. Fork the repository.
2. Create a new branch for your feature (`git checkout -b feature/new-feature`).
3. Commit your changes (`git commit -m 'Add new feature'`).
4. Push to the branch (`git push origin feature/new-feature`).
5. Open a Pull Request.
