#!/usr/bin/env bash
# shellcheck shell=bash

_guards_subshell() {
    bash -c "
        set -euo pipefail
        source '${REPO_ROOT}/lib/guards.sh'
        $*
    "
}

test_30_guards_sourceable() {
    if ! _guards_subshell ':'; then
        printf 'lib/guards.sh failed to source\n'
        return 1
    fi
}

test_31_command_exists_passes_for_ls() {
    if ! _guards_subshell 'guard::command_exists ls'; then
        printf 'guard::command_exists ls should return 0\n'
        return 1
    fi
}

test_32_command_exists_fails_for_nonexistent() {
    if _guards_subshell 'guard::command_exists __nonexistent_cmd_xyz_42'; then
        printf 'guard::command_exists __nonexistent_cmd_xyz_42 should return 1\n'
        return 1
    fi
}

test_33_file_exists_passes_for_etc_hostname() {
    if ! _guards_subshell 'guard::file_exists /etc/hostname'; then
        printf 'guard::file_exists /etc/hostname should return 0\n'
        return 1
    fi
}

test_34_file_exists_fails_for_nonexistent() {
    if _guards_subshell 'guard::file_exists /nonexistent_path_xyz_42'; then
        printf 'guard::file_exists /nonexistent_path_xyz_42 should return 1\n'
        return 1
    fi
}

test_35_dir_exists_passes_for_tmp() {
    if ! _guards_subshell 'guard::dir_exists /tmp'; then
        printf 'guard::dir_exists /tmp should return 0\n'
        return 1
    fi
}

test_36_dir_exists_fails_for_nonexistent() {
    if _guards_subshell 'guard::dir_exists /nonexistent_dir_xyz_42'; then
        printf 'guard::dir_exists /nonexistent_dir_xyz_42 should return 1\n'
        return 1
    fi
}

test_37_symlink_is_passes_for_correct_target() {
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' RETURN
    touch "${tmp}/real"
    ln -s "${tmp}/real" "${tmp}/mylink"

    if ! _guards_subshell "guard::symlink_is '${tmp}/mylink' '${tmp}/real'"; then
        printf 'guard::symlink_is should return 0 for correct symlink\n'
        return 1
    fi
}

test_38_symlink_is_fails_for_wrong_target() {
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' RETURN
    touch "${tmp}/real"
    ln -s "${tmp}/real" "${tmp}/mylink"

    if _guards_subshell "guard::symlink_is '${tmp}/mylink' '/wrong/target'"; then
        printf 'guard::symlink_is should return 1 for wrong symlink target\n'
        return 1
    fi
}

test_39_symlink_is_fails_for_nonexistent() {
    if _guards_subshell "guard::symlink_is '/nonexistent_link_xyz_42' '/some/target'"; then
        printf 'guard::symlink_is should return 1 for nonexistent symlink\n'
        return 1
    fi
}

test_40_file_has_line_passes_for_match() {
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' RETURN
    printf 'hello world\nfoo bar\n' > "${tmp}/testfile"
    if ! _guards_subshell "guard::file_has_line '${tmp}/testfile' '^foo'"; then
        printf 'guard::file_has_line should return 0 for matching regex\n'
        return 1
    fi
}

test_41_file_has_line_fails_for_no_match() {
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' RETURN
    printf 'hello world\nfoo bar\n' > "${tmp}/testfile"
    if _guards_subshell "guard::file_has_line '${tmp}/testfile' '^zzz_no_match'"; then
        printf 'guard::file_has_line should return 1 for non-matching regex\n'
        return 1
    fi
}

test_42_file_matches_template_passes_for_identical() {
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' RETURN
    printf 'same content\n' > "${tmp}/file"
    printf 'same content\n' > "${tmp}/template"
    if ! _guards_subshell "guard::file_matches_template '${tmp}/file' '${tmp}/template'"; then
        printf 'guard::file_matches_template should return 0 for identical files\n'
        return 1
    fi
}

test_43_file_matches_template_fails_for_different() {
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' RETURN
    printf 'file content\n' > "${tmp}/file"
    printf 'template content\n' > "${tmp}/template"
    if _guards_subshell "guard::file_matches_template '${tmp}/file' '${tmp}/template'"; then
        printf 'guard::file_matches_template should return 1 for different files\n'
        return 1
    fi
}

test_44_package_installed_passes_for_coreutils() {
    if ! _guards_subshell 'guard::package_installed coreutils'; then
        printf 'guard::package_installed coreutils should return 0\n'
        return 1
    fi
}

test_45_package_installed_fails_for_nonexistent() {
    if _guards_subshell 'guard::package_installed __nonexistent_pkg_xyz_42'; then
        printf 'guard::package_installed __nonexistent_pkg_xyz_42 should return 1\n'
        return 1
    fi
}

test_45b_package_installed_fails_for_deinstalled() {
    # Find a package in 'rc' (removed, config-files) state — dpkg -s returns 0
    # for these but the package is NOT actually installed.
    local pkg
    pkg="$(dpkg -l 2>/dev/null | awk '/^rc/ {print $2; exit}')"
    if [[ -z "${pkg}" ]]; then
        # No deinstalled packages on this system — skip test silently
        return 0
    fi
    if _guards_subshell "guard::package_installed '${pkg}'"; then
        printf 'guard::package_installed %s should return 1 (deinstalled, config-files only)\n' "$pkg"
        return 1
    fi
}

test_46_package_held_is_defined() {
    if ! _guards_subshell 'declare -F guard::package_held >/dev/null'; then
        printf 'guard::package_held not defined in lib/guards.sh\n'
        return 1
    fi
}

test_47_package_held_fails_for_coreutils() {
    if _guards_subshell 'guard::package_held coreutils'; then
        printf 'guard::package_held coreutils should return 1 (not held)\n'
        return 1
    fi
}

test_48_package_held_fails_for_nonexistent() {
    if _guards_subshell 'guard::package_held __nonexistent_pkg_xyz_42'; then
        printf 'guard::package_held __nonexistent_pkg_xyz_42 should return 1 (not held)\n'
        return 1
    fi
}

test_49_apt_repo_present_passes_for_debian() {
    if ! _guards_subshell 'guard::apt_repo_present debian'; then
        printf 'guard::apt_repo_present debian should return 0\n'
        return 1
    fi
}

test_50_apt_repo_present_fails_for_nonexistent() {
    if _guards_subshell 'guard::apt_repo_present __nonexistent_repo_xyz_42'; then
        printf 'guard::apt_repo_present __nonexistent_repo_xyz_42 should return 1\n'
        return 1
    fi
}

test_51_service_enabled_passes() {
    if ! _guards_subshell 'guard::service_enabled systemd-journald'; then
        printf 'guard::service_enabled systemd-journald should return 0\n'
        return 1
    fi
}

test_52_service_enabled_fails() {
    if _guards_subshell 'guard::service_enabled __fake_unit_xyz_42'; then
        printf 'guard::service_enabled __fake_unit_xyz_42 should return 1\n'
        return 1
    fi
}

test_53_service_active_passes() {
    if ! _guards_subshell 'guard::service_active systemd-journald'; then
        printf 'guard::service_active systemd-journald should return 0\n'
        return 1
    fi
}

test_54_service_active_fails() {
    if _guards_subshell 'guard::service_active __fake_unit_xyz_42'; then
        printf 'guard::service_active __fake_unit_xyz_42 should return 1\n'
        return 1
    fi
}

test_55_unit_file_exists_passes() {
    if ! _guards_subshell 'guard::unit_file_exists systemd-journald'; then
        printf 'guard::unit_file_exists systemd-journald should return 0\n'
        return 1
    fi
}

test_56_unit_file_exists_fails() {
    if _guards_subshell 'guard::unit_file_exists __fake_unit_xyz_42'; then
        printf 'guard::unit_file_exists __fake_unit_xyz_42 should return 1\n'
        return 1
    fi
}

test_57_user_in_group_passes() {
    local user group
    user="$(whoami)"
    group="$(id -gn)"
    if ! _guards_subshell "guard::user_in_group '${user}' '${group}'"; then
        printf 'guard::user_in_group %s %s should return 0\n' "$user" "$group"
        return 1
    fi
}

test_58_user_in_group_fails() {
    local user group
    user="$(whoami)"
    group="__fake_group_xyz_42"
    if _guards_subshell "guard::user_in_group '${user}' '${group}'"; then
        printf 'guard::user_in_group %s %s should return 1\n' "$user" "$group"
        return 1
    fi
}

test_59_user_shell_is_passes() {
    local user shell
    user="$(whoami)"
    shell="$(getent passwd "$(whoami)" | cut -d: -f7)"
    if ! _guards_subshell "guard::user_shell_is '${user}' '${shell}'"; then
        printf 'guard::user_shell_is %s %s should return 0\n' "$user" "$shell"
        return 1
    fi
}

test_60_user_shell_is_fails() {
    local user shell
    user="$(whoami)"
    shell="/bin/__fake_shell_xyz"
    if _guards_subshell "guard::user_shell_is '${user}' '${shell}'"; then
        printf 'guard::user_shell_is %s %s should return 1\n' "$user" "$shell"
        return 1
    fi
}

test_60b_user_shell_is_fails_for_nonexistent_user() {
    if _guards_subshell "guard::user_shell_is '__nonexistent_user_xyz_42' ''"; then
        printf 'guard::user_shell_is should return 1 for nonexistent user with empty shell\n'
        return 1
    fi
}

test_61_docker_network_exists_is_defined() {
    if ! _guards_subshell 'declare -F guard::docker_network_exists >/dev/null'; then
        printf 'guard::docker_network_exists not defined\n'
        return 1
    fi
}

test_62_docker_network_exists_fails_for_nonexistent() {
    if _guards_subshell 'guard::docker_network_exists __nonexistent_net_xyz_42'; then
        printf 'guard::docker_network_exists should return 1 for nonexistent\n'
        return 1
    fi
}

test_62b_docker_network_exists_passes_for_bridge() {
    # The 'bridge' network exists by default when Docker is installed.
    if ! command -v docker >/dev/null 2>&1; then
        return 0  # skip if Docker not available
    fi
    if ! _guards_subshell 'guard::docker_network_exists bridge'; then
        printf 'guard::docker_network_exists bridge should return 0\n'
        return 1
    fi
}

test_63_container_running_is_defined() {
    if ! _guards_subshell 'declare -F guard::container_running >/dev/null'; then
        printf 'guard::container_running not defined\n'
        return 1
    fi
}

test_64_container_running_fails_for_nonexistent() {
    if _guards_subshell 'guard::container_running __nonexistent_ctr_xyz_42'; then
        printf 'guard::container_running should return 1 for nonexistent\n'
        return 1
    fi
}

test_65_port_listening_is_defined() {
    if ! _guards_subshell 'declare -F guard::port_listening >/dev/null'; then
        printf 'guard::port_listening not defined\n'
        return 1
    fi
}

test_66_port_listening_fails_for_unused_port() {
    if _guards_subshell 'guard::port_listening tcp 59999'; then
        printf 'guard::port_listening unexpectedly reported tcp port 59999 as listening\n'
        return 1
    fi
}

test_67_port_listening_passes_for_sshd() {
    if ! _guards_subshell 'guard::port_listening tcp 22'; then
        printf 'guard::port_listening tcp 22 should return 0 (sshd listening)\n'
        return 1
    fi
}
