#!/bin/bash
# Managed by Puppet

# Define colors using robust printf to ensure they are interpreted as literal ANSI codes
C_CYAN=$(printf '\033[1;36m')
C_RESET=$(printf '\033[0m')
C_MAGENTA=$(printf '\033[1;35m')
C_WHITE=$(printf '\033[1;97m')
C_YELLOW=$(printf '\033[1;33m')
C_GREEN=$(printf '\033[1;32m')
C_L_YELLOW=$(printf '\033[1;93m')

# Helper to print a line with the cyan border stars
print_line() {
    local content="$1"
    # The box is ~95 chars wide
    printf "      ${C_CYAN}*${C_RESET}  %-90s  ${C_CYAN}*${C_RESET}\n" "$content"
}

# Top border
echo -e "      ${C_CYAN}***********************************************************************************************${C_RESET}"

print_line ""
print_line "      ${C_MAGENTA}This system is managed by Puppet${C_RESET}"
print_line ""
print_line "        ${C_WHITE} _                          _       _           _        __                ${C_RESET}"
print_line "        ${C_WHITE}| |__   ___  _ __ ___   ___| | __ _| |__       (_)_ __  / _|_ __ __ _     ${C_RESET}"
print_line "        ${C_WHITE}| '_ \\ / _ \\| '_ \` _ \\ / _ \\ |/ _\` | '_ \\      | | '_ \\| |_| '__/ _\` |   ${C_RESET}"
print_line "        ${C_WHITE}| | | | (_) | | | | | |  __/ | (_| | |_) |     | | | | |  _| | | (_| |   ${C_RESET}"
print_line "        ${C_WHITE}|_| |_|\\___/|_| |_| |_|\\___|_|\\__,_|_.__/      |_|_| |_|_| |_|  \\__,_|   ${C_RESET}"
print_line ""
print_line "      ${C_YELLOW}Any local changes will be overwritten.${C_RESET}"
print_line ""

# Dynamic wisdom part
if command -v fortune >/dev/null 2>&1 && command -v cowsay >/dev/null 2>&1; then
    # Pick a random cow
    COW=$(cowsay -l | tail -n +2 | tr ' ' '\n' | grep -vE '^$' | shuf -n 1)
    [ -z "$COW" ] && COW="default"
    
    print_line "      ${C_CYAN}✦ Today's wisdom (cow: ${C_YELLOW}${COW}${C_CYAN})${C_RESET}"
    print_line ""
    
    # Process cowsay output to fit in our box
    # Use a slightly narrower width for the cow to ensure it fits
    fortune | cowsay -f "$COW" -W 60 2>/dev/null | while read -r line; do
        print_line "    $line"
    done
    print_line ""
fi

# System Information
HOST=$(hostname -f 2>/dev/null || hostname)
OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
MEM=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
UPTIME=$(uptime -p | sed 's/up //')

print_line "      ${C_GREEN}◈ System Information${C_RESET}"
print_line ""
print_line "      ${C_CYAN}Hostname:          ${C_L_YELLOW}${HOST}${C_RESET}"
print_line "      ${C_CYAN}Operating System:  ${C_L_YELLOW}${OS}${C_RESET}"
print_line "      ${C_CYAN}Memory (Used/Tot): ${C_L_YELLOW}${MEM}${C_RESET}"
print_line "      ${C_CYAN}Uptime:            ${C_L_YELLOW}${UPTIME}${C_RESET}"
print_line ""

# Bottom border
echo -e "      ${C_CYAN}***********************************************************************************************${C_RESET}"
