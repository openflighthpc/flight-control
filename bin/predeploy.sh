!/bin/bash
set -euo pipefail
#IFS=$'\n\t'

main() {
    parse_arguments "$@"
    header "Creating database"
    create_database
    header "Migrating database"
    migrate_database
}

create_database() {
    rake db:create
}

migrate_database() {
    rake db:migrate:with_data
}

header() {
    echo -e "=====> $@"
}

usage() {
    echo "Usage: $(basename $0) [options]"
    echo
    echo "Predeploy script to be ran during dokku deployment"
    echo
    echo -e "      --help\t\tShow this help message"
}

parse_arguments() {
    while [[ $# > 0 ]] ; do
        key="$1"

        case $key in
            --help)
                usage
                exit 0
                ;;

            *)
                echo "$(basename $0): unrecognized option ${key}"
                usage
                exit 1
                ;;
        esac
    done
}


main "$@"
