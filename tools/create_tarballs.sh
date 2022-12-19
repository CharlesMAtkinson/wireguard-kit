#! /bin/bash

# Copyright (C) 2022 Charles Atkinson
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA

# Purpose: creates tarballs in the current directory's parent directory
#   * Name: wireguard-kit_<version>.source.tgz
#     The source directory less any files matching .git/info/exclude patterns
#   * Name: wireguard-kit_<version>.installation.tgz
#     As above with the man pages compressed
#     To install from using the user guide "From tarball" procedure

# Usage:
#   See usage.fun or use -h option

# Programmers' notes: function call tree
#    +
#    |
#    +-- initialise
#    |   |
#    |   +-- usage
#    |
#    +-- mk_tarballs
#    |   |
#    |   +-- mk_htm_and_pdf_from_odts
#    |       |
#    |       +-- mk_htm_and_pdf_from_odt
#    |           |
#    |           +-- mk_htm_or_pdf_from_odt
#    |
#    +-- finalise
#
# Utility functions called from various places:
#    ck_file fct msg

# Function definitions in alphabetical order.  Execution begins after the last function definition.

#--------------------------
# Name: ck_file
# Purpose: for each file listed in the argument list: checks that it is
#   * reachable and exists
#   * is of the type specified (block special, ordinary file or directory)
#   * has the requested permission(s) for the user
#   * optionally, is absolute (begins with /)
# Usage: ck_file [ path <file_type>:<permissions>[:[a]] ] ...
#   where
#     file  is a file name (path)
#     file_type  is b (block special file), f (file) or d (directory)
#     permissions  is none or more of r, w and x
#     a  requests an absoluteness test (that the path begins with /)
#   Example:
#     buf=$(ck_file foo f:rw 2>&1)
#     if [[ $buf != '' ]]; then
#          msg W "$buf"
#          fct "${FUNCNAME[0]}" 'returning 1'
#          return 1
#     fi
# Outputs:
#   * For the first requested property each file does not have, a message to
#     stderr
#   * For the first detected programminng error, a message to
#     stderr
# Returns:
#   0 when all files have the requested properties
#   1 when at least one of the files have the requested properties
#   2 when a programming error is detected
#--------------------------
function ck_file {

    local absolute_flag buf file_name file_type perm perms retval

    # For each file ...
    # ~~~~~~~~~~~~~~~~~
    retval=0
    while [[ $# -gt 0 ]]
    do
        file_name=$1
        file_type=${2%%:*}
        buf=${2#$file_type:}
        perms=${buf%%:*}
        absolute=${buf#$perms:}
        [[ $absolute = $buf ]] && absolute=
        case $absolute in
            '' | a )
                ;;
            * )
                echo "ck_file: invalid absoluteness flag in '$2' specified for file '$file_name'" >&2
                return 2
        esac
        shift 2

        # Is the file reachable and does it exist?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        case $file_type in
            b )
                if [[ ! -b $file_name ]]; then
                    echo "file '$file_name' is unreachable, does not exist or is not a block special file" >&2
                    retval=1
                    continue
                fi
                ;;
            f )
                if [[ ! -f $file_name ]]; then
                    echo "file '$file_name' is unreachable, does not exist or is not an ordinary file" >&2
                    retval=1
                    continue
                fi
                ;;
            d )
                if [[ ! -d $file_name ]]; then
                    echo "directory '$file_name' is unreachable, does not exist or is not a directory" >&2
                    retval=1
                    continue
                fi
                ;;
            * )
                echo "Programming error: ck_file: invalid file type '$file_type' specified for file '$file_name'" >&2
                return 2
        esac

        # Does the file have the requested permissions?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        buf="$perms"
        while [[ $buf ]]
        do
            perm="${buf:0:1}"
            buf="${buf:1}"
            case $perm in
                r )
                    if [[ ! -r $file_name ]]; then
                        echo "$file_name: no read permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                w )
                    if [[ ! -w $file_name ]]; then
                        echo "$file_name: no write permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                x )
                    if [[ ! -x $file_name ]]; then
                        echo "$file_name: no execute permission" >&2
                        retval=1
                        continue
                    fi
                    ;;
                * )
                    echo "Programming error: ck_file: invalid permisssion '$perm' requested for file '$file_name'" >&2
                    return 2
            esac
        done

        # Does the file have the requested absoluteness?
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if [[ $absolute = a && ${file_name:0:1} != / ]]; then
            echo "$file_name: does not begin with /" >&2
            retval=1
        fi

    done

    return $retval

}  #  end of function ck_file

#--------------------------
# Name: ck_uint
# Purpose: checks for a valid unsigned integer
# Usage: ck_uint <putative uint>
# Outputs: none
# Returns:
#   0 when $1 is a valid unsigned integer
#   1 otherwise
#--------------------------
function ck_uint {
    local regex='^[[:digit:]]+$'
    [[ $1 =~ $regex ]] && return 0 || return 1
}  #  end of function ck_uint

#--------------------------
# Name: fct
# Purpose: function call trace (for debugging)
# $1 - name of calling function
# $2 - message.  If it starts with "started" or "returning" then the output is prettily indented
#--------------------------
function fct {

    if [[ ! $debugging_flag ]]; then
        return 0
    fi

    fct_indent="${fct_indent:=}"

    case $2 in
        'started'* )
            fct_indent="$fct_indent  "
            msg D "$fct_indent$1: $2"
            ;;
        'returning'* )
            msg D "$fct_indent$1: $2"
            fct_indent="${fct_indent#  }"
            ;;
        * )
            msg D "$fct_indent$1: $2"
    esac
}  # end of function fct

#--------------------------
# Name: finalise
# Purpose: cleans up and exits
# Arguments:
#    $1  exit code
# Exit code:
#   When not terminated by a signal, the sum of zero plus
#      1 when any warnings
#      2 when any errors
#   When terminated by a trapped signal, the sum of 128 plus the signal number
#--------------------------
function finalise {
    fct "${FUNCNAME[0]}" "started with args $*"
    local my_exit_code sig_name

    finalising_flag=$true

    # Interrupted?
    # ~~~~~~~~~~~~
    my_exit_code=0
    if ck_uint "${1:-}"; then
        if (($1>128)); then    # Trapped interrupt
            interrupt_flag=$true
            i=$((128+${#sig_names[*]}))    # Max valid interrupt code
            if (($1<i)); then
                my_exit_code=$1
                sig_name=${sig_names[$1-128]}
                msg I "Finalising on $sig_name"
                [[ ${summary_fn:-} != '' ]] \
                    && echo "Finalising on $sig_name" >> "$summary_fn"
            else
               msg="${FUNCNAME[0]} called with invalid exit value '${1:-}'"
               msg+=" (> max valid interrupt code $i)"
               msg E "$msg"    # Returns because finalising_flag is set
            fi
        fi
    fi

    # Exit code value adjustment
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ ! $interrupt_flag ]]; then
        if [[ $warning_flag ]]; then
            msg I "There was at least one WARNING"
            ((my_exit_code+=1))
        fi
        if [[ $error_flag ]]; then
            msg I "There was at least one ERROR"
            ((my_exit_code+=2))
        fi
        if ((my_exit_code==0)) && ((${1:-0}!=0)); then
            my_exit_code=2
        fi
    else
        msg I "There was a $sig_name interrupt"
    fi

    # Remove temporary directory
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $tmp_dir_created_flag ]]; then
        if [[ ! $debugging_flag && ${tmp_dir:-} =~ $tmp_dir_regex ]]; then
            msg I "Removing temporary directory $tmp_dir (use option -d to keep it)"
            rm -fr "$tmp_dir"
        else
            msg I "Temporary directory $tmp_dir is kept for inspection"
        fi
    fi

    # Remove PID file
    # ~~~~~~~~~~~~~~~
    [[ $pid_file_locked_flag ]] && rm "$pid_fn"

    # Exit
    # ~~~~
    fct "${FUNCNAME[0]}" 'exiting'
    exit $my_exit_code
}  # end of function finalise

#--------------------------
# Name: initialise
# Purpose: sets up environment, parses command line, reads config file
#--------------------------
function initialise {
    local args buf conf_fn emsg opt usage_reports_csv_fn

    # Configure shell environment
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
    buf=$(locale --all-locales | grep 'en_.*utf8')
    if [[ $buf = '' ]]; then
        echo 'ERROR: locale --all-locales did not list any English UTF8 locales' >&2
        exit 1
    fi
    export LANG=$(echo "$buf" | head -1)
    export LANGUAGE=$LANG
    for var_name in LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE LC_IDENTIFICATION \
        LC_MEASUREMENT LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER \
        LC_TELEPHONE LC_TIME
    do
        unset $var_name
    done

    export PATH=/usr/sbin:/sbin:/usr/bin:/bin
    IFS=$' \n\t'
    set -o nounset
    shopt -s extglob            # Enable extended pattern matching operators
    unset CDPATH                # Ensure cd behaves as expected
    umask 022

    # Initialise some global logic variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    readonly false=
    readonly true=true

    debugging_flag=$false
    error_flag=$false
    finalising_flag=$false
    interrupt_flag=$false
    logging_flag=$false
    pid_file_locked_flag=$false
    tmp_dir_created_flag=$false
    warning_flag=$false

    # Set global read-only non-logic variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    declare -gr fn_date_format='%Y-%m-%d'
    declare -gr fn_date_regex='[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}'
    declare -gr log_date_format='+%H:%M:%S'
    declare -gr msg_lf=$'\n    '
    declare -gr my_name=${0##*/}
    declare -gr my_pid=$$
    declare -gr sig_names=(. $(kill -L | sed 's/[[:digit:]]*)//g'))
    declare -gr version_fn=version

    # Using variables set above
    declare -gr tmp_dir_mktemp_str=/tmp/$my_name.XXXXXX
    declare -gr tmp_dir_regex="^/tmp/$my_name\..{6}\$"

    # Initialise some global non-logic variables
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # None wanted

    # Parse command line
    # ~~~~~~~~~~~~~~~~~~
    args=("$@")
    args_org="$*"
    emsg=
    while getopts :dh opt "$@"
    do
        case $opt in
            d )
                debugging_flag=$true
                ;;
            h )
                debugging_flag=$false
                usage verbose
                exit 0
                ;;
            * )
                emsg+=$msg_lf"Invalid option '-$OPTARG'"
        esac
    done

    # Check for mandatory options missing
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # There are no mandatory options

    # Test for mutually exclusive options
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # There are no mutually exclusive options

    # Validate option values
    # ~~~~~~~~~~~~~~~~~~~~~~
    # There are no option values

    # Test for extra arguments
    # ~~~~~~~~~~~~~~~~~~~~~~~~
    shift $(($OPTIND-1))
    if [[ $* != '' ]]; then
        emsg+=$msg_lf"Invalid extra argument(s) '$*'"
    fi

    # Report any command line errors
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        emsg+=$msg_lf'(-h for help)'
        msg E "Command line error(s)$emsg"
    fi

    # Report any errors
    # ~~~~~~~~~~~~~~~~~
    if [[ $emsg != '' ]]; then
        msg E "$emsg"
    fi

    # Set traps
    # ~~~~~~~~~
    for ((i=1;i<${#sig_names[*]};i++))
    do
        ((i==9)) && continue     # SIGKILL
        ((i==17)) && continue    # SIGCHLD
        trap "finalise $((128+i))" ${sig_names[i]#SIG}
    done

    # Create temporary directory
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    # If the mktemp template is changed, tmp_dir_regex in the finalise function
    # must be changed to suit
    buf=$(mktemp -d "/tmp/$my_name.XXXXXX" 2>&1)
    if (($?==0)); then
        tmp_dir=$buf
        tmp_dir_created_flag=$true
        chmod 700 "$tmp_dir"
    else
        msg E "Unable to create temporary directory:$buf"
    fi

    # Ensure in the root of the git working tree
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    [[ ! -d .git ]] && msg E "$my_name must be run in the root of the git working tree"

    # Get the version number
    # ~~~~~~~~~~~~~~~~~~~~~~
    version=$(<"$version_fn")

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function initialise

#--------------------------
# Name: mk_htm_and_pdf_from_odt
# Purpose: makes .htm and .pdf versions of the .odt file
#--------------------------
function mk_htm_and_pdf_from_odt {
    fct "${FUNCNAME[0]}" 'started'
    local buf cmd rc
    local htm_fn odt_fn out_dir pdf_fn

    # Parse the argument
    # ~~~~~~~~~~~~~~~~~~
    odt_fn=$1
    buf=$(ck_file "$odt_fn" f:r 2>&1)
    [[ $buf != '' ]] && msg E "$buf"
    out_dir=${odt_fn%/*}
    buf=$(ck_file "$out_dir" d:rwx 2>&1)
    [[ $buf != '' ]] && msg E "$buf"

    # Make the new versions
    # ~~~~~~~~~~~~~~~~~~~~~
    mk_htm_or_pdf_from_odt htm:HTML "$odt_fn" "$out_dir" .htm
    mk_htm_or_pdf_from_odt pdf:writer_pdf_Export "$odt_fn" "$out_dir" .pdf

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function mk_htm_and_pdf_from_odt

#--------------------------
# Name: mk_htm_and_pdf_from_odts
# Purpose: makes .pdf and .htm versions of the .odt files
#--------------------------
function mk_htm_and_pdf_from_odts {
    fct "${FUNCNAME[0]}" 'started'
    local i

    while IFS= read -r -d '' odt_fn; do
        mk_htm_and_pdf_from_odt "$odt_fn"
    done < <(find "$tmp_dir" -type f -name '*.odt' -print0)

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function mk_htm_and_pdf_from_odts

#--------------------------
# Name: mk_htm_or_pdf_from_odt
# Purpose: makes .htm or .pdf version of the .odt file
# Arguments
#   $1 --convert-to option argument
#   $2 .odt file name
#   $3 output directory
#   $4 output file extension
#--------------------------
function mk_htm_or_pdf_from_odt {
    fct "${FUNCNAME[0]}" 'started'
    local buf cmd msg rc
    local convert_to_opt_arg out_dir out_fn_ext
    local odt_fn out_fn
    local ck_file_out

    # Parse the arguments
    # ~~~~~~~~~~~~~~~~~~
    convert_to_opt_arg=$1
    odt_fn=$2
    out_dir=$3
    out_fn_ext=$4

    # Make the new version
    # ~~~~~~~~~~~~~~~~~~~~
    #   * soffice is difficult to error trap (0 exit status on error, error messages not documented) so any existing output file is
    #     removed before running soffice so output file creation can be used as a success indication
    #   * -env is required to workaound failure when soffice is aready running
    msg I "Making $out_fn_ext version of $odt_fn"
    out_fn=${odt_fn%.odt}$out_fn_ext
    rm -f "$out_fn"
    cmd=(soffice
        --headless
        -env:UserInstallation="file:///$tmp_dir/LibreOffice_Conversion"
        --convert-to "$convert_to_opt_arg"
        --outdir "$out_dir"
        "$odt_fn"
    )
    buf=$("${cmd[@]}" 2>&1)
    rc=$?
    ck_file_out=$(ck_file "$out_fn" f:r 2>&1)
    if ((rc!=0)) || [[ $ck_file_out != '' ]]; then
        msg="Command: ${cmd[*]}"
        msg+=$'\n'"Return code: $rc"
        msg+=$'\n'"Output: $buf"
        [[ $ck_file_out != '' ]] && msg+=$'\n'"$ck_file_out"
        msg E "$msg"
    fi

    # Remove soffice's temporary user profile path tree
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    rm -r "$tmp_dir/LibreOffice_Conversion"

    # Ensure newline at .htm EoF
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Requred by POSIX and by Debian packaging
    [[ $out_fn_ext = .htm ]] && echo >> "$out_fn"

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function mk_htm_or_pdf_from_odt

#--------------------------
# Name: mk_tarballs
# Purpose: makes a tarball of the current source files
#--------------------------
function mk_tarballs {
    fct "${FUNCNAME[0]}" 'started'
    local installation_tarball_fn source_tarball_fn
    local man_page_fn pattern section

    # Copy the source directory to the temporary directory
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg I 'Copying the source directory to the temporary directory'
    cp -pr source/. "$tmp_dir" || finalise 1

    # Remove files matching .git/info/exclude patterns
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg I 'Removing files matching .git/info/exclude patterns'
    while IFS= read -r pattern; do
       find "$tmp_dir" -name "$pattern" -execdir rm {} + || finalise 1
    done < <(grep --extended-regexp --invert-match '^#|^[[:space:]]*$' .git/info/exclude)

    # Create the source tarball
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    source_tarball_fn=../wireguard-kit_$version.source.tgz
    msg I "Creating source tarball $source_tarball_fn"
    tar --create --directory="$tmp_dir" --file="$source_tarball_fn" --gzip . || finalise 1
    msg I "Created $source_tarball_fn"

    # Add .htm and .pdf versions of the .odt files
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    mk_htm_and_pdf_from_odts

    # Create compressed versions of man pages and remove uncompressed versions
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    msg I 'Compressing the man pages'
    for section in 5 8
    do
        for man_page_fn in $tmp_dir/usr/share/man/man$section/*.$section
        do
            gzip -9 --to-stdout "$man_page_fn" > "$man_page_fn.gz" || finalise 1
            rm "$man_page_fn"
        done
    done

    # Create the installation tarball
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    installation_tarball_fn=../wireguard-kit_$version.installation.tgz
    msg I "Creating installation tarball $installation_tarball_fn"
    tar --create --directory="$tmp_dir" --file="$installation_tarball_fn" --gzip . || finalise 1
    msg I "Created installation tarball $installation_tarball_fn"

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function mk_tarballs

#--------------------------
# Name: msg
# Purpose: generalised messaging interface
# Arguments:
#    $1 class: D, E, I or W indicating Debug, Error, Information or Warning
#    $2 message text
# Global variables read:
#     my_name
# Output: information messages to stdout; the rest to stderr
# Returns:
#   Does not return (calls finalise) when class is E for error
#   Otherwise returns 0
#--------------------------
function msg {
    local buf class logger_msg message_text prefix priority

    # Process arguments
    # ~~~~~~~~~~~~~~~~~
    class="${1:-}"
    message_text="${2:-}"

    # Class-dependent set-up
    # ~~~~~~~~~~~~~~~~~~~~~~
    case "$class" in
        D )
            [[ ! $debugging_flag ]] && return
            prefix='DEBUG: '
            priority=
            ;;
        E )
            error_flag=$true
            prefix='ERROR: '
            priority=err
            ;;
        I )
            prefix=
            priority=info
            ;;
        W )
            warning_flag=$true
            prefix='WARN: '
            priority=warning
            ;;
        * )
            msg E "msg: invalid class '$class': '$*'"
    esac

    # Write to stdout or stderr
    # ~~~~~~~~~~~~~~~~~~~~~~~~~
    message_text="$(date "$log_date_format") $prefix$message_text"
    if [[ $class = I ]]; then
        echo "$message_text"
    else
        echo "$message_text" >&2
        if [[ $class = E ]]; then
            [[ ! $finalising_flag ]] && finalise 1
        fi
    fi

    return 0
}  #  end of function msg

#--------------------------
# Name: usage
# Purpose: prints usage message
#--------------------------
function usage {
    fct "${FUNCNAME[0]}" 'started'
    local msg usage

    # Build the messages
    # ~~~~~~~~~~~~~~~~~~
    usage="usage: $my_name "
    msg='  where:'
    usage+='[-d] [-h] [-k]'
    msg+=$'\n    -d debugging on'
    msg+=$'\n    -h prints this help and exits'

    # Display the message(s)
    # ~~~~~~~~~~~~~~~~~~~~~~
    echo "$usage" >&2
    if [[ ${1:-} != 'verbose' ]]; then
        echo "(use -h for help)" >&2
    else
        echo "$msg" >&2
    fi

    fct "${FUNCNAME[0]}" 'returning'
}  # end of function usage

#--------------------------
# Name: main
# Purpose: where it all happens
#--------------------------
initialise "${@:-}"
mk_tarballs
finalise 0
