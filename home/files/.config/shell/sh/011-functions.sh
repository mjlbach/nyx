#!/usr/bin/env bash

# CMAKE Wrapper Function
#
# Wrapper function around cmake to conform more to my workflow when I write in
# c++ and cmake projects. This function wraps the generation of the cmake project
# and the building all in one command. It will first build the cmake project into
# the `build` directory and then build the project with `cmake --build build`.
#
# This function has some extra options:
#   - toggle tests
#   - set compilers (gcc or clang)
function cmake()
{
    local verbose=false
    local generate_args=()
    local build_args=()
    local native_args=()

    # If the first argument passed is -- then pass --config and --target options to the
    # cmake compile command and all other options to the cmake generate command
    if [ "$1" = '--' ]; then
        shift
        while (( $# ))
        do
            case "$1" in
                -v) verbose=true ;;
                -n) generate_args+=("-DNO_TESTS=ON") ;;
                -t) generate_args+=("-DNO_TESTS=OFF") ;;
                -g) generate_args+=("-DCMAKE_CXX_COMPILER=g++") ;;
                -c) generate_args+=("-DCMAKE_CXX_COMPILER=c++") ;;
                --verbose) verbose=true ;;
                --target) build_args+=("$1") ; build_args+=("$2") ; shift ;;
                --config) build_args+=("$1") ; build_args+=("$2") ; shift ;;
                --clean-first) build_args+=("$1") ;;
                --) native_args=("$@") ; break ;;
                *) generate_args+=("$1") ;;
            esac
            shift
        done
    else
        # If arguments are passed then pass then through to cmake
        (( $# != 0 )) && { env cmake "$@" ; return $? ; }
    fi

    (
        rootdir="$(git rev-parse --show-toplevel 2>/dev/null)" && cd "$rootdir"

        "$verbose" && count=$(tput cols) && printf "%${count}s\n" | tr ' ' '-'
        "$verbose" && echo "env cmake . -Bbuild ${generate_args[@]}"
        "$verbose" && count=$(tput cols) && printf "%${count}s\n" | tr ' ' '-'

        env cmake . -Bbuild "${generate_args[@]}"
        [ $? -ne 0 ] && return $?

        "$verbose" && count=$(tput cols) && printf "%${count}s\n" | tr ' ' '-'
        "$verbose" && echo "env cmake --build build ${build_args[@]} -- ${native_args[@]}"
        "$verbose" && count=$(tput cols) && printf "%${count}s\n" | tr ' ' '-'

        env cmake --build build "${build_args[@]}" "${native_args[@]}"
        return $?
    )
}

function crun()
{
    [ -z $(git root) &>/dev/null ] && echo "could not find the git directory" && return 1
    (
        cd $(git root) &>/dev/null # change the directory to root of the git directory
        [[ -d "./build" ]] || {
            echo "build directory not found"
            return 1
        }

        process()
        {
            echo "Running $(basename $1)"
            count=$(tput cols) && printf "%${count}s\n" | tr ' ' '-'
            $1
            [ $? -ne 0 ] && return $?
            count=$(tput cols) && printf "%${count}s\n" | tr ' ' '-'
            echo "$(basename $1) - Finished"
        }

        [[ -z $(find --version 2>/dev/null) ]] && exec_flag+=("-perm" "+111")
        [[ -z $(find --version 2>/dev/null) ]] || exec_flag+=("-executable")

        find build -type f -not -path "*CMakeFiles*" ${exec_flag[@]} -print | while read line ; do
            process $line
        done
    )
}

function dirsize()
{
    du -ah --max-depth=1 ${1:-.} | sort -hr
}

function extract()
{
    if [ -z "$1" ]; then
        # display usage
        echo "Usage: extract <path/file>.<zip|rar|gz|tar|Z|7z|tar.gz>"
        echo "       extract <path/file.ext> [path/file_2.ext] [path/file_2.ext]"
        return 1
    else
        for n in $@
        do
            if [ -f "$n" ]; then
                case "${n%,}" in
                    *tar.gz|*tar.xz|*.tar) tar xvf ./"$n" ;;
                    *.rar) unrar x -ad ./"$n" ;;
                    *.gz) gunzup ./"$n" ;;
                    *.zip) unzip ./"$n" ;;
                    *.z) uncompress ./"$n" ;;
                    *.7z|*.deb|*.dmg|*.iso|*.msi|*.rpm|*.xar) 7z x ./"$n" ;;
                    *)
                        echo "extract: '$n' - unknown archive method"
                        return 1 ;;
                esac
            else
                echo "'$n' - file does not exist"
                return 1
            fi
        done
    fi
}

function history()
{
    local DEFAULT=100
    builtin history ${1:-$DEFAULT}
}

# Make a directory and cd into it
function mkcd()
{
    mkdir -p -- "$1"
    cd -- "$1"
}

function p4()
{
    if [[ $1 == 'connect' ]]; then
        command echo $(read -s; echo $REPLY) | command p4 login;
    elif [[ $1 == 'log' ]]; then
        command p4 changes -l -t ${@:2} | less;
    elif [[ $1 == 'branch' ]]; then
        command p4 info | grep ^Client\ stream;
    elif [[ $1 == 'diff' ]]; then
        command p4 diff -du ${@:2} | vimpager;
    elif [[ $1 == 'fast' ]]; then
        command p4 sync --parallel=threads=4,batch=8,batchsize=534288,min=1,minsize=589824 "${@:2}";
    elif [[ $1 == 'pdiff' ]]; then
        command p4-pdiff ${@:2}
    elif [[ $1 == 'dirty' ]]; then
        command p4-dirty ${@:2}
    else
        command p4 $*;
    fi
}

# regmv = regex + mv (mv with regex parameter specification)
#       example: regmv '/\.tif$/.tiff/' *
#       replaces .tif with .tiff for all files in current dir
#       must quote the regex otherwise "\." becomes "."
# limitations: ? doesn't seem to work in the regex, nor *
regmv()
{
    if [ $# -lt 2 ]; then
        echo "  Usage: regmv 'regex' file(s)"
        echo "  Where:           'regex' should be of the format '/find/replace/'"
        echo "Example: regmv '/\.tif\$/.tiff/' *"
        echo "   Note: Must quote/escape the regex otherwise \"\.\" becomes \".\""
        return 1
    fi
    regex="$1"
    shift

    while (( $# ))
    do
        newname="$(sed -e "s${regex}g" <<<"$1")"
        [ "${newname}" != "$1" ] && mv -i -v -- "$1" "$newname"
        shift
    done
}

function rgl()
{
    rg --color always -n $@ | less
}

function tmux()
{
    # Make sure even pre-existing tmux sessions use the latest SSH_AUTH_SOCK.
    # (Inspired by: https://gist.github.com/lann/6771001)
    local SOCK_SYMLINK=~/.ssh/ssh_auth_sock
    if [ -r "$SSH_AUTH_SOCK" -a ! -L "$SSH_AUTH_SOCK" ]; then
        ln -sf "$SSH_AUTH_SOCK" $SOCK_SYMLINK
    fi

    # If provided with args, pass them through.
    if [[ -n "$@" ]]; then
        env SSH_AUTH_SOCK=$SOCK_SYMLINK tmux "$@"
        return
    fi

    # Check for .tmux file (poor man's Tmuxinator).
    if [ -x .tmux ]; then
        echo "the .tmux file exists"
        # Prompt the first time we see a given .tmux file before running it.

        local DIGEST="$(openssl sha -sha512 .tmux)"
        if ! grep -q "$DIGEST" ~/.tmux.digests 2> /dev/null; then
            cat .tmux
            read -n 1 -r -p \
                'REPLY?Trust (and run) this .tmux file? (t = trust, otherwise = skip) '
            echo
            if [[ $REPLY =~ ^[Tt]$ ]]; then
                echo "$DIGEST" >> ~/.tmux.digests
                ./.tmux
                return
            fi
        else
            echo "tmux session exists attaching to it"
            ./.tmux
            return
        fi
    fi

    # Attach to existing session, or create one, based on current directory.
    echo "attaching to existing session"
    SESSION_NAME=$(basename "$(pwd)")
    env SSH_AUTH_SOCK=$SOCK_SYMLINK tmux new -A -s "$SESSION_NAME"
}

function vscode-update-install()
{
    local output_file=$HOME/.config/code/install-extensions.sh

    # clear output file
    echo "#!/usr/bin/env bash" > $output_file
    echo "" >> $output_file

    # populate extension list
    echo "extension_list=(" >> $output_file
    local ext_list=($(code --list-extensions))
    for ext in ${ext_list[@]}; do
        echo "    $ext" >> $output_file
    done
    echo ")" >> $output_file
    echo "" >> $output_file

    cat >> $output_file << EOF
function main()
{
    local current_ext_list=(\$(code --list-extensions))
    local skip_count=0
    local install_count=0

    local a=()
    local name=''

    for ext in \${extension_list[@]}; do
        a=(\${ext//./ })
        name=\${a[1]}

        if [[ ! "\${current_ext_list[@]}" =~ "\$ext" ]]; then
            echo "Installing: \$name..."
            install "\$ext"
            install_count=\$((install_count+1))
        else
            echo "Skipping:   \$name..."
            skip_count=\$((skip_count+1))
        fi
    done

    # determine if there are any local extensions that are on in the saved list
    local local_extensions=()
    local local_count=0
    for ext in \${current_ext_list}; do
        a=(\${ext//./ })
        name=\${a[1]}

        if [[ ! "\$extension_list[@]" =~ "\$ext" ]]; then
            local_extensions+=(\$name)
            local_count=\$((local_count+1))
        fi
    done

    echo ""
    echo "Complete! Results:"
    echo "  Installed: \$install_count"
    echo "  Skipped:   \$skip_count"
    if [[ \$local_count -gt 0 ]]; then
        echo ""
        echo "There are currently \$local_count extensions installed that are not saved:"
        for e in \${local_extensions[@]}; do
            echo "  \$e"
        done
    fi
}

function install()
{
    code --install-extension "\$1" 1>/dev/null
}

main "\$@"
EOF
}
