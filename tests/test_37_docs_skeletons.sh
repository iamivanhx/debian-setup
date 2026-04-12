#!/usr/bin/env bash
# shellcheck shell=bash

test_37a_recovery_md_skeleton() {
    local recovery="${REPO_ROOT}/docs/recovery.md"
    local heading

    if [[ ! -f "${recovery}" ]]; then
        printf 'docs/recovery.md missing\n'
        return 1
    fi

    for heading in \
        'Overview' \
        'Expected time' \
        'Reinstall procedure' \
        'Restore from B2' \
        'Unlock NVMe2' \
        'Verify Docker volumes survived' \
        'Restart projects'
    do
        if ! grep -q "## ${heading}" "${recovery}"; then
            printf "docs/recovery.md missing heading: ## %s\n" "${heading}"
            return 1
        fi
    done

    return 0
}

test_37b_projects_md_skeleton() {
    local projects="${REPO_ROOT}/docs/projects.md"
    local heading

    if [[ ! -f "${projects}" ]]; then
        printf 'docs/projects.md missing\n'
        return 1
    fi

    for heading in \
        'Overview' \
        'Adding a project' \
        'Traefik label reference' \
        'Avahi alias convention' \
        'Known footguns'
    do
        if ! grep -q "## ${heading}" "${projects}"; then
            printf "docs/projects.md missing heading: ## %s\n" "${heading}"
            return 1
        fi
    done

    return 0
}

test_37c_acceptance_md_skeleton() {
    local acceptance="${REPO_ROOT}/docs/acceptance.md"

    if [[ ! -f "${acceptance}" ]]; then
        printf 'docs/acceptance.md missing\n'
        return 1
    fi

    if ! grep -q '### Phase' "${acceptance}"; then
        printf 'docs/acceptance.md missing phase subheading\n'
        return 1
    fi

    return 0
}
