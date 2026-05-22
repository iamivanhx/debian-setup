#!/usr/bin/env bash
# shellcheck shell=bash

test_04_legacy_cleanup_removes_root_scripts() {
    local script
    for script in xfce-setup.sh hyprland-setup.sh debian-post-install.sh \
                  beelink_ubuntu_post_install.sh beelink_debian_post_install.sh; do
        if [[ -e "${REPO_ROOT}/${script}" || -L "${REPO_ROOT}/${script}" ]]; then
            printf '%s should not exist at repo root\n' "${script}"
            return 1
        fi
    done
    return 0
}

test_04_readme_clean_of_deleted_scripts() {
    local readme_path script

    readme_path="${REPO_ROOT}/README.md"
    if [[ ! -f "${readme_path}" ]]; then
        printf 'README.md should exist at repo root\n'
        return 1
    fi

    for script in xfce-setup.sh hyprland-setup.sh debian-post-install.sh \
                  beelink_ubuntu_post_install.sh beelink_debian_post_install.sh; do
        if grep -Fq -- "${script}" "${readme_path}"; then
            printf 'README.md should not reference deleted script %s\n' "${script}"
            return 1
        fi
    done

    return 0
}
