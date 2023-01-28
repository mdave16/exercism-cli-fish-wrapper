# List a mentoring discussion
# - https://exercism.org/mentoring/discussions/UUID
#
# option:
#   -u --uuid   the discussion uuid (required)
#   -i --index  the index of the discussion from the most recent
#               `exercism mentoring inbox` call
#
# Using `html-to-text` to render post as text
# https://www.npmjs.com/package/html-to-text

function __exercism__mentoring_discussion
    argparse --name="exercism mentoring discussion" \
        'u/uuid=' 'i/index=' 'dump' -- $argv
    or return 1

    if set -q _flag_index
        if not set -q __exercism_mentoring_discussions
            echo "call `exercism mentoring inbox` first" >&2
            return 1
        end
        if test $_flag_index -gt (count $__exercism_mentoring_discussions)
            echo "no such uuid index" >&2
            set -S __exercism_mentoring_discussions >&2
            return 1
        end
        echo $__exercism_mentoring_discussions[$_flag_index] \
        | read -d\v _flag_uuid exercise track_title student
        echo $exercise on $track_title by $student
        set track (
            # not all track slugs are just the title lower-cased
            __exercism__api_call /tracks \
            | jq --arg title $track_title -r '
                .tracks[] | select(.title == $title) | .slug
              '
        )
        set uri "/mentoring/students/$student?track_slug=$track"
        set json (__exercism__api_call $uri)
        echo
        echo $json | jq -r '.student.track_objectives' | fold -s | sed 's/^/    /'
        echo
    else if not set -q _flag_uuid
        echo "missing --uuid flag" >&2
        return 1
    end

    set uri "/mentoring/discussions/$_flag_uuid"
    set json (__exercism__api_call "$uri/posts")
    if set -q _flag_dump
        echo $json | jq .
        return
    end

    echo "https://exercism.org$uri"

    # Clearly, ruby can do what I'm using jq for here,
    # but I've already got that `duration` function, so ...

    echo $json \
    | jq -r '
        def duration: (now - .) as $d |
            if   ($d < 3600)       then "\($d / 60 | floor) minutes"
            elif ($d < 86400)      then "\($d / 3600 | floor) hours"
            elif ($d < 86400 * 30) then "\($d / 86400 | floor) days"
            else                        "\($d / (365 * 86400) * 12 | floor) months"
            end;

        [
          .items[] |
          { author_handle,
            date: (.updated_at | fromdateiso8601 | duration),
            content_html
          }
        ]
    ' \
    | ruby -ropen3 -rjson -rcolorize -e '
        hr = "-" * 86
        JSON.parse(STDIN.read).each do |post|
          puts hr
          puts post["author_handle"].green.bold + " - " + post["date"].green
          puts ""
          Open3.popen2("html-to-text") do |i, o, t|
            i << post["content_html"]
            i.close
            puts o.read.gsub(/^/m, "    ")
          end
        end
      '
end
