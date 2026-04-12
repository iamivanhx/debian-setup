#!/usr/bin/env bash
# shellcheck shell=bash

test_36a_readme_mentions_audience() {
    local readme="${REPO_ROOT}/README.md"
    if [[ ! -f "${readme}" ]]; then
        printf 'README.md missing\n'
        return 1
    fi
    if ! grep -Eqi 'audience of one|SER8' "${readme}"; then
        printf "README.md missing audience-of-one mention\n"
        return 1
    fi
    return 0
}

test_36b_readme_has_precommit_hook_install() {
    local readme="${REPO_ROOT}/README.md"
    if [[ ! -f "${readme}" ]]; then
        printf 'README.md missing\n'
        return 1
    fi
    if ! grep -Fq 'ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit' "${readme}"; then
        printf "README.md missing pre-commit hook install command\n"
        return 1
    fi
    return 0
}

test_36c_readme_links_to_docs() {
    local readme="${REPO_ROOT}/README.md"
    if [[ ! -f "${readme}" ]]; then
        printf 'README.md missing\n'
        return 1
    fi
    if ! grep -Fq 'docs/install.md' "${readme}"; then
        printf "README.md missing docs/install.md link\n"
        return 1
    fi
    if ! grep -Fq 'docs/recovery.md' "${readme}"; then
        printf "README.md missing docs/recovery.md link\n"
        return 1
    fi
    if ! grep -Fq 'docs/projects.md' "${readme}"; then
        printf "README.md missing docs/projects.md link\n"
        return 1
    fi
    return 0
}
