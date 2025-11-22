#!/bin/bash

################################################################################
# Linux System Update Script
# Location: /home/administrator/projects/devscripts/updatelinux.sh
# Purpose: Safely update Linux system with user prompts and error handling
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show command before running
run_command() {
    local cmd="$1"
    local description="$2"

    echo ""
    log_info "$description"
    echo -e "${YELLOW}Command:${NC} $cmd"

    if ! eval "$cmd"; then
        log_error "Command failed: $cmd"
        return 1
    fi

    return 0
}

# Function to prompt user for confirmation
prompt_continue() {
    local message="$1"
    local default="${2:-n}"

    echo ""
    if [ "$default" = "y" ]; then
        read -p "$(echo -e ${YELLOW}$message' [Y/n]: '${NC})" response
        response=${response:-y}
    else
        read -p "$(echo -e ${YELLOW}$message' [y/N]: '${NC})" response
        response=${response:-n}
    fi

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if running as root or with sudo
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        log_info "Please run: sudo $0"
        exit 1
    fi
}

# Function to check disk space
check_disk_space() {
    log_info "Checking available disk space..."

    local available=$(df / | awk 'NR==2 {print $4}')
    local available_gb=$(echo "scale=2; $available / 1024 / 1024" | bc)

    echo -e "Available space on /: ${GREEN}${available_gb}GB${NC}"

    if [ "$available" -lt 1048576 ]; then  # Less than 1GB
        log_warning "Less than 1GB free space available!"
        if ! prompt_continue "Continue anyway?"; then
            log_info "Update cancelled by user"
            exit 0
        fi
    fi
}

# Function to update package lists
update_package_lists() {
    if ! run_command "apt update" "Updating package lists"; then
        log_error "Failed to update package lists"
        return 1
    fi
    log_success "Package lists updated"
    return 0
}

# Function to show upgradeable packages
show_upgradeable() {
    log_info "Checking for upgradeable packages..."

    local upgradeable_count=$(apt list --upgradeable 2>/dev/null | grep -c "upgradable" || true)

    if [ "$upgradeable_count" -eq 0 ]; then
        log_success "System is already up to date!"
        return 1
    fi

    echo ""
    log_info "Found $upgradeable_count package(s) to upgrade:"
    echo ""
    apt list --upgradeable 2>/dev/null
    echo ""

    return 0
}

# Function to upgrade packages
upgrade_packages() {
    if ! prompt_continue "Proceed with package upgrade?"; then
        log_info "Package upgrade skipped"
        return 1
    fi

    if ! run_command "apt upgrade -y" "Upgrading packages"; then
        log_error "Package upgrade failed"
        return 1
    fi

    log_success "Packages upgraded successfully"
    return 0
}

# Function to perform distribution upgrade
dist_upgrade() {
    if ! prompt_continue "Perform distribution upgrade (full-upgrade)?"; then
        log_info "Distribution upgrade skipped"
        return 1
    fi

    if ! run_command "apt dist-upgrade -y" "Performing distribution upgrade"; then
        log_error "Distribution upgrade failed"
        return 1
    fi

    log_success "Distribution upgrade completed"
    return 0
}

# Function to clean up old packages
cleanup_packages() {
    log_info "Checking for packages that can be removed..."

    local autoremove_count=$(apt autoremove --dry-run 2>/dev/null | grep -oP '\d+(?= to remove)' || echo "0")

    if [ "$autoremove_count" -eq 0 ]; then
        log_info "No packages to auto-remove"
    else
        echo ""
        log_info "Found $autoremove_count package(s) that can be removed:"
        apt autoremove --dry-run 2>/dev/null | grep "^Remv" || true
        echo ""

        if prompt_continue "Remove these packages?"; then
            if ! run_command "apt autoremove -y" "Removing unnecessary packages"; then
                log_warning "Auto-remove failed, but continuing..."
            else
                log_success "Unnecessary packages removed"
            fi
        fi
    fi

    # Clean package cache
    if prompt_continue "Clean package cache?"; then
        if ! run_command "apt clean" "Cleaning package cache"; then
            log_warning "Cache cleaning failed, but continuing..."
        else
            log_success "Package cache cleaned"
        fi
    fi
}

# Function to check for reboot requirement
check_reboot() {
    log_info "Checking if reboot is required..."

    if [ -f /var/run/reboot-required ]; then
        echo ""
        log_warning "*** SYSTEM REBOOT REQUIRED ***"

        if [ -f /var/run/reboot-required.pkgs ]; then
            echo ""
            log_info "Packages requiring reboot:"
            cat /var/run/reboot-required.pkgs
        fi

        echo ""
        if prompt_continue "Reboot now?"; then
            log_info "System will reboot in 5 seconds..."
            sleep 5
            reboot
        else
            log_warning "Please remember to reboot the system soon"
        fi
    else
        log_success "No reboot required"
    fi
}

# Function to show update summary
show_summary() {
    echo ""
    echo "========================================="
    log_success "UPDATE COMPLETE"
    echo "========================================="

    log_info "System information:"
    echo ""
    run_command "uname -a" "Kernel version" || true
    echo ""
    run_command "lsb_release -a 2>/dev/null || cat /etc/os-release | head -5" "OS information" || true
    echo ""
}

################################################################################
# Main execution
################################################################################

main() {
    echo "========================================="
    echo "  Linux System Update Script"
    echo "========================================="
    echo ""

    # Check privileges
    check_privileges

    # Check disk space
    check_disk_space

    # Update package lists
    if ! update_package_lists; then
        log_error "Failed to update package lists. Exiting."
        exit 1
    fi

    # Show upgradeable packages
    if ! show_upgradeable; then
        # No updates available
        show_summary
        exit 0
    fi

    # Upgrade packages
    if upgrade_packages; then
        # Ask about dist-upgrade if standard upgrade succeeded
        dist_upgrade || true
    else
        log_warning "Skipping distribution upgrade due to failed/skipped package upgrade"
    fi

    # Cleanup
    cleanup_packages

    # Show summary
    show_summary

    # Check for reboot
    check_reboot

    echo ""
    log_success "All done!"
}

# Trap errors
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"
