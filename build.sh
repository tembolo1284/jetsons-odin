#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-test}"; shift || true

case "$cmd" in
    check)   odin check src "$@" && odin check tests "$@" ;;
    build)   odin build src -out:jetsons -debug "$@" ;;
    release) odin build src -out:jetsons -o:speed "$@" ;;
    run)     odin run src -out:jetsons -o:speed -- "$@" ;;
    test)    odin test tests -out:jetsons_tests "$@" ;;
    tsan)    odin test tests -out:jetsons_tests_tsan -sanitize:thread "$@" ;;
    asan)    odin test tests -out:jetsons_tests_asan -sanitize:address "$@" ;;
    clean)   rm -f jetsons jetsons_tests jetsons_tests_tsan jetsons_tests_asan ;;
    *) echo "usage: $0 {check|build|release|run|test|tsan|asan|clean}" >&2; exit 2 ;;
esac
