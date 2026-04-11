#!/usr/bin/env bash
# shellcheck shell=bash

test_15_readme_documents_core_rule() {
    local readme="${REPO_ROOT}/README.md"
    if [[ ! -f "${readme}" ]]; then
        printf 'README.md missing\n'
        return 1
    fi
    if ! grep -qi 'edit the automation, not the box' "${readme}"; then
        printf "README.md missing core rule 'edit the automation, not the box'\n"
        return 1
    fi
    if ! grep -q 'git clone' "${readme}"; then
        printf "README.md missing clone/run instructions\n"
        return 1
    fi
    if ! grep -qi 'phase' "${readme}"; then
        printf "README.md missing phase status checklist\n"
        return 1
    fi
    return 0
}

test_16_templates_tree_exists() {
    local d
    for d in etc home/user home/user/.config srv/data/lab systemd; do
        if [[ ! -d "${REPO_ROOT}/templates/${d}" ]]; then
            printf 'templates/%s missing\n' "${d}"
            return 1
        fi
    done
    return 0
}
