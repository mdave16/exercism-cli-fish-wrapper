function __exercism__test__jq
    argparse --ignore-unknown track= help -- $argv
    set -q _flag_help; and return

    __exercism__test__validate_runner $_flag_track jq; or return 1
    __exercism__test__bash --track=$_flag_track $argv
end
