# bash completion for seqfu                               -*- shell-script -*-


# ADD TO ~/.bash_completion
# ============================================
# for bcfile in ~/.bash_completion.d/* ; do
#   . $bcfile
# done
__seqfu_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__seqfu_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__seqfu_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__seqfu_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__seqfu_handle_reply()
{
    __seqfu_debug "${FUNCNAME[0]}"
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r c; do
                COMPREPLY+=("$c")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __seqfu_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __seqfu_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions=("${must_have_one_noun[@]}")
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r c; do
        COMPREPLY+=("$c")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r c; do
            COMPREPLY+=("$c")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
		if declare -F __seqfu_custom_func >/dev/null; then
			# try command name qualified custom func
			__seqfu_custom_func
		else
			# otherwise fall back to unqualified for compatibility
			declare -F __custom_func >/dev/null && __custom_func
		fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__seqfu_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__seqfu_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__seqfu_handle_flag()
{
    __seqfu_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __seqfu_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __seqfu_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __seqfu_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __seqfu_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __seqfu_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__seqfu_handle_noun()
{
    __seqfu_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __seqfu_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __seqfu_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__seqfu_handle_command()
{
    __seqfu_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_seqfu_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __seqfu_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__seqfu_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __seqfu_handle_reply
        return
    fi
    __seqfu_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __seqfu_handle_flag
    elif __seqfu_contains_word "${words[c]}" "${commands[@]}"; then
        __seqfu_handle_command
    elif [[ $c -eq 0 ]]; then
        __seqfu_handle_command
    elif __seqfu_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __seqfu_handle_command
        else
            __seqfu_handle_noun
        fi
    else
        __seqfu_handle_noun
    fi
    __seqfu_handle_word
}

_seqfu_amplicon()
{
    last_command="seqfu_amplicon"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--flanking-region")
    flags+=("-f")
    local_nonpersistent_flags+=("--flanking-region")
    flags+=("--forward=")
    two_word_flags+=("--forward")
    two_word_flags+=("-F")
    local_nonpersistent_flags+=("--forward=")
    flags+=("--max-mismatch=")
    two_word_flags+=("--max-mismatch")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--max-mismatch=")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region=")
    flags+=("--reverse=")
    two_word_flags+=("--reverse")
    two_word_flags+=("-R")
    local_nonpersistent_flags+=("--reverse=")
    flags+=("--strict-mode")
    flags+=("-s")
    local_nonpersistent_flags+=("--strict-mode")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_bam()
{
    last_command="seqfu_bam"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--bins=")
    two_word_flags+=("--bins")
    two_word_flags+=("-B")
    local_nonpersistent_flags+=("--bins=")
    flags+=("--count=")
    two_word_flags+=("--count")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--count=")
    flags+=("--delay=")
    two_word_flags+=("--delay")
    two_word_flags+=("-W")
    local_nonpersistent_flags+=("--delay=")
    flags+=("--dump")
    flags+=("-y")
    local_nonpersistent_flags+=("--dump")
    flags+=("--exec-after=")
    two_word_flags+=("--exec-after")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--exec-after=")
    flags+=("--exec-before=")
    two_word_flags+=("--exec-before")
    two_word_flags+=("-E")
    local_nonpersistent_flags+=("--exec-before=")
    flags+=("--field=")
    two_word_flags+=("--field")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--field=")
    flags+=("--idx-count")
    flags+=("-C")
    local_nonpersistent_flags+=("--idx-count")
    flags+=("--idx-stat")
    flags+=("-i")
    local_nonpersistent_flags+=("--idx-stat")
    flags+=("--img=")
    two_word_flags+=("--img")
    two_word_flags+=("-O")
    local_nonpersistent_flags+=("--img=")
    flags+=("--list-fields")
    flags+=("-H")
    local_nonpersistent_flags+=("--list-fields")
    flags+=("--log")
    flags+=("-L")
    local_nonpersistent_flags+=("--log")
    flags+=("--map-qual=")
    two_word_flags+=("--map-qual")
    two_word_flags+=("-q")
    local_nonpersistent_flags+=("--map-qual=")
    flags+=("--pass")
    flags+=("-x")
    local_nonpersistent_flags+=("--pass")
    flags+=("--prim-only")
    flags+=("-F")
    local_nonpersistent_flags+=("--prim-only")
    flags+=("--print-freq=")
    two_word_flags+=("--print-freq")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--print-freq=")
    flags+=("--quiet-mode")
    flags+=("-Q")
    local_nonpersistent_flags+=("--quiet-mode")
    flags+=("--range-max=")
    two_word_flags+=("--range-max")
    two_word_flags+=("-M")
    local_nonpersistent_flags+=("--range-max=")
    flags+=("--range-min=")
    two_word_flags+=("--range-min")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--range-min=")
    flags+=("--reset")
    flags+=("-R")
    local_nonpersistent_flags+=("--reset")
    flags+=("--stat")
    flags+=("-s")
    local_nonpersistent_flags+=("--stat")
    flags+=("--top-bam=")
    two_word_flags+=("--top-bam")
    two_word_flags+=("-@")
    local_nonpersistent_flags+=("--top-bam=")
    flags+=("--top-size=")
    two_word_flags+=("--top-size")
    two_word_flags+=("-?")
    local_nonpersistent_flags+=("--top-size=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_common()
{
    last_command="seqfu_common"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-name")
    flags+=("-n")
    local_nonpersistent_flags+=("--by-name")
    flags+=("--by-seq")
    flags+=("-s")
    local_nonpersistent_flags+=("--by-seq")
    flags+=("--ignore-case")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-case")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_concat()
{
    last_command="seqfu_concat"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_convert()
{
    last_command="seqfu_convert"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dry-run")
    flags+=("-d")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--from=")
    two_word_flags+=("--from")
    local_nonpersistent_flags+=("--from=")
    flags+=("--nrecords=")
    two_word_flags+=("--nrecords")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--nrecords=")
    flags+=("--thresh-B-in-n-most-common=")
    two_word_flags+=("--thresh-B-in-n-most-common")
    two_word_flags+=("-N")
    local_nonpersistent_flags+=("--thresh-B-in-n-most-common=")
    flags+=("--thresh-illumina1.5-frac=")
    two_word_flags+=("--thresh-illumina1.5-frac")
    two_word_flags+=("-F")
    local_nonpersistent_flags+=("--thresh-illumina1.5-frac=")
    flags+=("--to=")
    two_word_flags+=("--to")
    local_nonpersistent_flags+=("--to=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_duplicate()
{
    last_command="seqfu_duplicate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--times=")
    two_word_flags+=("--times")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--times=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_faidx()
{
    last_command="seqfu_faidx"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--full-head")
    flags+=("-f")
    local_nonpersistent_flags+=("--full-head")
    flags+=("--ignore-case")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-case")
    flags+=("--use-regexp")
    flags+=("-r")
    local_nonpersistent_flags+=("--use-regexp")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_fish()
{
    last_command="seqfu_fish"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--aln-params=")
    two_word_flags+=("--aln-params")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--aln-params=")
    flags+=("--invert")
    flags+=("-i")
    local_nonpersistent_flags+=("--invert")
    flags+=("--min-qual=")
    two_word_flags+=("--min-qual")
    two_word_flags+=("-q")
    local_nonpersistent_flags+=("--min-qual=")
    flags+=("--out-bam=")
    two_word_flags+=("--out-bam")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--out-bam=")
    flags+=("--pass")
    flags+=("-x")
    local_nonpersistent_flags+=("--pass")
    flags+=("--print-aln")
    flags+=("-g")
    local_nonpersistent_flags+=("--print-aln")
    flags+=("--print-desc")
    flags+=("-D")
    local_nonpersistent_flags+=("--print-desc")
    flags+=("--query-fastx=")
    two_word_flags+=("--query-fastx")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--query-fastx=")
    flags+=("--query-sequences=")
    two_word_flags+=("--query-sequences")
    two_word_flags+=("-F")
    local_nonpersistent_flags+=("--query-sequences=")
    flags+=("--ranges=")
    two_word_flags+=("--ranges")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--ranges=")
    flags+=("--stranded")
    flags+=("-s")
    local_nonpersistent_flags+=("--stranded")
    flags+=("--validate-seq")
    flags+=("-v")
    local_nonpersistent_flags+=("--validate-seq")
    flags+=("--validate-seq-length=")
    two_word_flags+=("--validate-seq-length")
    two_word_flags+=("-V")
    local_nonpersistent_flags+=("--validate-seq-length=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_fq2fa()
{
    last_command="seqfu_fq2fa"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_fx2tab()
{
    last_command="seqfu_fx2tab"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--alphabet")
    flags+=("-a")
    local_nonpersistent_flags+=("--alphabet")
    flags+=("--avg-qual")
    flags+=("-q")
    local_nonpersistent_flags+=("--avg-qual")
    flags+=("--base-content=")
    two_word_flags+=("--base-content")
    two_word_flags+=("-B")
    local_nonpersistent_flags+=("--base-content=")
    flags+=("--gc")
    flags+=("-g")
    local_nonpersistent_flags+=("--gc")
    flags+=("--gc-skew")
    flags+=("-G")
    local_nonpersistent_flags+=("--gc-skew")
    flags+=("--header-line")
    flags+=("-H")
    local_nonpersistent_flags+=("--header-line")
    flags+=("--length")
    flags+=("-l")
    local_nonpersistent_flags+=("--length")
    flags+=("--name")
    flags+=("-n")
    local_nonpersistent_flags+=("--name")
    flags+=("--only-id")
    flags+=("-i")
    local_nonpersistent_flags+=("--only-id")
    flags+=("--qual-ascii-base=")
    two_word_flags+=("--qual-ascii-base")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--qual-ascii-base=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_genautocomplete()
{
    last_command="seqfu_genautocomplete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--file=")
    two_word_flags+=("--file")
    local_nonpersistent_flags+=("--file=")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    flags+=("--type=")
    two_word_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_grep()
{
    last_command="seqfu_grep"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-name")
    flags+=("-n")
    local_nonpersistent_flags+=("--by-name")
    flags+=("--by-seq")
    flags+=("-s")
    local_nonpersistent_flags+=("--by-seq")
    flags+=("--degenerate")
    flags+=("-d")
    local_nonpersistent_flags+=("--degenerate")
    flags+=("--delete-matched")
    local_nonpersistent_flags+=("--delete-matched")
    flags+=("--ignore-case")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-case")
    flags+=("--invert-match")
    flags+=("-v")
    local_nonpersistent_flags+=("--invert-match")
    flags+=("--max-mismatch=")
    two_word_flags+=("--max-mismatch")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--max-mismatch=")
    flags+=("--pattern=")
    two_word_flags+=("--pattern")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--pattern=")
    flags+=("--pattern-file=")
    two_word_flags+=("--pattern-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--pattern-file=")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-R")
    local_nonpersistent_flags+=("--region=")
    flags+=("--use-regexp")
    flags+=("-r")
    local_nonpersistent_flags+=("--use-regexp")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_head()
{
    last_command="seqfu_head"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--number=")
    two_word_flags+=("--number")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--number=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_locate()
{
    last_command="seqfu_locate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--bed")
    local_nonpersistent_flags+=("--bed")
    flags+=("--degenerate")
    flags+=("-d")
    local_nonpersistent_flags+=("--degenerate")
    flags+=("--gtf")
    local_nonpersistent_flags+=("--gtf")
    flags+=("--ignore-case")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-case")
    flags+=("--max-mismatch=")
    two_word_flags+=("--max-mismatch")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--max-mismatch=")
    flags+=("--non-greedy")
    flags+=("-G")
    local_nonpersistent_flags+=("--non-greedy")
    flags+=("--only-positive-strand")
    flags+=("-P")
    local_nonpersistent_flags+=("--only-positive-strand")
    flags+=("--pattern=")
    two_word_flags+=("--pattern")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--pattern=")
    flags+=("--pattern-file=")
    two_word_flags+=("--pattern-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--pattern-file=")
    flags+=("--validate-seq-length=")
    two_word_flags+=("--validate-seq-length")
    two_word_flags+=("-V")
    local_nonpersistent_flags+=("--validate-seq-length=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_mutate()
{
    last_command="seqfu_mutate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-name")
    flags+=("-n")
    local_nonpersistent_flags+=("--by-name")
    flags+=("--deletion=")
    two_word_flags+=("--deletion")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--deletion=")
    flags+=("--ignore-case")
    flags+=("-I")
    local_nonpersistent_flags+=("--ignore-case")
    flags+=("--insertion=")
    two_word_flags+=("--insertion")
    two_word_flags+=("-i")
    local_nonpersistent_flags+=("--insertion=")
    flags+=("--invert-match")
    flags+=("-v")
    local_nonpersistent_flags+=("--invert-match")
    flags+=("--pattern=")
    two_word_flags+=("--pattern")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--pattern=")
    flags+=("--pattern-file=")
    two_word_flags+=("--pattern-file")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--pattern-file=")
    flags+=("--point=")
    two_word_flags+=("--point")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--point=")
    flags+=("--use-regexp")
    flags+=("-r")
    local_nonpersistent_flags+=("--use-regexp")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_range()
{
    last_command="seqfu_range"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--range=")
    two_word_flags+=("--range")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--range=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_rename()
{
    last_command="seqfu_rename"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-name")
    flags+=("-n")
    local_nonpersistent_flags+=("--by-name")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_replace()
{
    last_command="seqfu_replace"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-seq")
    flags+=("-s")
    local_nonpersistent_flags+=("--by-seq")
    flags+=("--ignore-case")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-case")
    flags+=("--keep-key")
    flags+=("-K")
    local_nonpersistent_flags+=("--keep-key")
    flags+=("--key-capt-idx=")
    two_word_flags+=("--key-capt-idx")
    two_word_flags+=("-I")
    local_nonpersistent_flags+=("--key-capt-idx=")
    flags+=("--key-miss-repl=")
    two_word_flags+=("--key-miss-repl")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--key-miss-repl=")
    flags+=("--kv-file=")
    two_word_flags+=("--kv-file")
    two_word_flags+=("-k")
    local_nonpersistent_flags+=("--kv-file=")
    flags+=("--nr-width=")
    two_word_flags+=("--nr-width")
    local_nonpersistent_flags+=("--nr-width=")
    flags+=("--pattern=")
    two_word_flags+=("--pattern")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--pattern=")
    flags+=("--replacement=")
    two_word_flags+=("--replacement")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--replacement=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_restart()
{
    last_command="seqfu_restart"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--new-start=")
    two_word_flags+=("--new-start")
    two_word_flags+=("-i")
    local_nonpersistent_flags+=("--new-start=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_rmdup()
{
    last_command="seqfu_rmdup"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-name")
    flags+=("-n")
    local_nonpersistent_flags+=("--by-name")
    flags+=("--by-seq")
    flags+=("-s")
    local_nonpersistent_flags+=("--by-seq")
    flags+=("--dup-num-file=")
    two_word_flags+=("--dup-num-file")
    two_word_flags+=("-D")
    local_nonpersistent_flags+=("--dup-num-file=")
    flags+=("--dup-seqs-file=")
    two_word_flags+=("--dup-seqs-file")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--dup-seqs-file=")
    flags+=("--ignore-case")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-case")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_sample()
{
    last_command="seqfu_sample"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--number=")
    two_word_flags+=("--number")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--number=")
    flags+=("--proportion=")
    two_word_flags+=("--proportion")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--proportion=")
    flags+=("--rand-seed=")
    two_word_flags+=("--rand-seed")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--rand-seed=")
    flags+=("--two-pass")
    flags+=("-2")
    local_nonpersistent_flags+=("--two-pass")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_sana()
{
    last_command="seqfu_sana"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--qual-ascii-base=")
    two_word_flags+=("--qual-ascii-base")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--qual-ascii-base=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_seq()
{
    last_command="seqfu_seq"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--complement")
    flags+=("-p")
    local_nonpersistent_flags+=("--complement")
    flags+=("--dna2rna")
    local_nonpersistent_flags+=("--dna2rna")
    flags+=("--gap-letters=")
    two_word_flags+=("--gap-letters")
    two_word_flags+=("-G")
    local_nonpersistent_flags+=("--gap-letters=")
    flags+=("--lower-case")
    flags+=("-l")
    local_nonpersistent_flags+=("--lower-case")
    flags+=("--max-len=")
    two_word_flags+=("--max-len")
    two_word_flags+=("-M")
    local_nonpersistent_flags+=("--max-len=")
    flags+=("--max-qual=")
    two_word_flags+=("--max-qual")
    two_word_flags+=("-R")
    local_nonpersistent_flags+=("--max-qual=")
    flags+=("--min-len=")
    two_word_flags+=("--min-len")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--min-len=")
    flags+=("--min-qual=")
    two_word_flags+=("--min-qual")
    two_word_flags+=("-Q")
    local_nonpersistent_flags+=("--min-qual=")
    flags+=("--name")
    flags+=("-n")
    local_nonpersistent_flags+=("--name")
    flags+=("--only-id")
    flags+=("-i")
    local_nonpersistent_flags+=("--only-id")
    flags+=("--qual")
    flags+=("-q")
    local_nonpersistent_flags+=("--qual")
    flags+=("--qual-ascii-base=")
    two_word_flags+=("--qual-ascii-base")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--qual-ascii-base=")
    flags+=("--remove-gaps")
    flags+=("-g")
    local_nonpersistent_flags+=("--remove-gaps")
    flags+=("--reverse")
    flags+=("-r")
    local_nonpersistent_flags+=("--reverse")
    flags+=("--rna2dna")
    local_nonpersistent_flags+=("--rna2dna")
    flags+=("--seq")
    flags+=("-s")
    local_nonpersistent_flags+=("--seq")
    flags+=("--upper-case")
    flags+=("-u")
    local_nonpersistent_flags+=("--upper-case")
    flags+=("--validate-seq")
    flags+=("-v")
    local_nonpersistent_flags+=("--validate-seq")
    flags+=("--validate-seq-length=")
    two_word_flags+=("--validate-seq-length")
    two_word_flags+=("-V")
    local_nonpersistent_flags+=("--validate-seq-length=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_shuffle()
{
    last_command="seqfu_shuffle"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--keep-temp")
    flags+=("-k")
    local_nonpersistent_flags+=("--keep-temp")
    flags+=("--rand-seed=")
    two_word_flags+=("--rand-seed")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--rand-seed=")
    flags+=("--two-pass")
    flags+=("-2")
    local_nonpersistent_flags+=("--two-pass")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_sliding()
{
    last_command="seqfu_sliding"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--circular-genome")
    flags+=("-C")
    local_nonpersistent_flags+=("--circular-genome")
    flags+=("--greedy")
    flags+=("-g")
    local_nonpersistent_flags+=("--greedy")
    flags+=("--step=")
    two_word_flags+=("--step")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--step=")
    flags+=("--window=")
    two_word_flags+=("--window")
    two_word_flags+=("-W")
    local_nonpersistent_flags+=("--window=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_sort()
{
    last_command="seqfu_sort"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-length")
    flags+=("-l")
    local_nonpersistent_flags+=("--by-length")
    flags+=("--by-name")
    flags+=("-n")
    local_nonpersistent_flags+=("--by-name")
    flags+=("--by-seq")
    flags+=("-s")
    local_nonpersistent_flags+=("--by-seq")
    flags+=("--ignore-case")
    flags+=("-i")
    local_nonpersistent_flags+=("--ignore-case")
    flags+=("--keep-temp")
    flags+=("-k")
    local_nonpersistent_flags+=("--keep-temp")
    flags+=("--natural-order")
    flags+=("-N")
    local_nonpersistent_flags+=("--natural-order")
    flags+=("--reverse")
    flags+=("-r")
    local_nonpersistent_flags+=("--reverse")
    flags+=("--seq-prefix-length=")
    two_word_flags+=("--seq-prefix-length")
    two_word_flags+=("-L")
    local_nonpersistent_flags+=("--seq-prefix-length=")
    flags+=("--two-pass")
    flags+=("-2")
    local_nonpersistent_flags+=("--two-pass")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_split()
{
    last_command="seqfu_split"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-id")
    flags+=("-i")
    local_nonpersistent_flags+=("--by-id")
    flags+=("--by-part=")
    two_word_flags+=("--by-part")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--by-part=")
    flags+=("--by-region=")
    two_word_flags+=("--by-region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--by-region=")
    flags+=("--by-size=")
    two_word_flags+=("--by-size")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--by-size=")
    flags+=("--dry-run")
    flags+=("-d")
    local_nonpersistent_flags+=("--dry-run")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--keep-temp")
    flags+=("-k")
    local_nonpersistent_flags+=("--keep-temp")
    flags+=("--out-dir=")
    two_word_flags+=("--out-dir")
    two_word_flags+=("-O")
    local_nonpersistent_flags+=("--out-dir=")
    flags+=("--two-pass")
    flags+=("-2")
    local_nonpersistent_flags+=("--two-pass")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_split2()
{
    last_command="seqfu_split2"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--by-part=")
    two_word_flags+=("--by-part")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--by-part=")
    flags+=("--by-size=")
    two_word_flags+=("--by-size")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--by-size=")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    flags+=("--out-dir=")
    two_word_flags+=("--out-dir")
    two_word_flags+=("-O")
    local_nonpersistent_flags+=("--out-dir=")
    flags+=("--read1=")
    two_word_flags+=("--read1")
    two_word_flags+=("-1")
    local_nonpersistent_flags+=("--read1=")
    flags+=("--read2=")
    two_word_flags+=("--read2")
    two_word_flags+=("-2")
    local_nonpersistent_flags+=("--read2=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_stats()
{
    last_command="seqfu_stats"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    flags+=("--basename")
    flags+=("-b")
    local_nonpersistent_flags+=("--basename")
    flags+=("--fq-encoding=")
    two_word_flags+=("--fq-encoding")
    two_word_flags+=("-E")
    local_nonpersistent_flags+=("--fq-encoding=")
    flags+=("--gap-letters=")
    two_word_flags+=("--gap-letters")
    two_word_flags+=("-G")
    local_nonpersistent_flags+=("--gap-letters=")
    flags+=("--skip-err")
    flags+=("-e")
    local_nonpersistent_flags+=("--skip-err")
    flags+=("--tabular")
    flags+=("-T")
    local_nonpersistent_flags+=("--tabular")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_subseq()
{
    last_command="seqfu_subseq"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--bed=")
    two_word_flags+=("--bed")
    local_nonpersistent_flags+=("--bed=")
    flags+=("--chr=")
    two_word_flags+=("--chr")
    local_nonpersistent_flags+=("--chr=")
    flags+=("--down-stream=")
    two_word_flags+=("--down-stream")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--down-stream=")
    flags+=("--feature=")
    two_word_flags+=("--feature")
    local_nonpersistent_flags+=("--feature=")
    flags+=("--gtf=")
    two_word_flags+=("--gtf")
    local_nonpersistent_flags+=("--gtf=")
    flags+=("--gtf-tag=")
    two_word_flags+=("--gtf-tag")
    local_nonpersistent_flags+=("--gtf-tag=")
    flags+=("--only-flank")
    flags+=("-f")
    local_nonpersistent_flags+=("--only-flank")
    flags+=("--region=")
    two_word_flags+=("--region")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--region=")
    flags+=("--up-stream=")
    two_word_flags+=("--up-stream")
    two_word_flags+=("-u")
    local_nonpersistent_flags+=("--up-stream=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_tab2fx()
{
    last_command="seqfu_tab2fx"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--comment-line-prefix=")
    two_word_flags+=("--comment-line-prefix")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--comment-line-prefix=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_translate()
{
    last_command="seqfu_translate"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--allow-unknown-codon")
    flags+=("-x")
    local_nonpersistent_flags+=("--allow-unknown-codon")
    flags+=("--clean")
    local_nonpersistent_flags+=("--clean")
    flags+=("--frame=")
    two_word_flags+=("--frame")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--frame=")
    flags+=("--init-codon-as-M")
    flags+=("-M")
    local_nonpersistent_flags+=("--init-codon-as-M")
    flags+=("--list-transl-table=")
    two_word_flags+=("--list-transl-table")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--list-transl-table=")
    flags+=("--list-transl-table-with-amb-codons=")
    two_word_flags+=("--list-transl-table-with-amb-codons")
    two_word_flags+=("-L")
    local_nonpersistent_flags+=("--list-transl-table-with-amb-codons=")
    flags+=("--transl-table=")
    two_word_flags+=("--transl-table")
    two_word_flags+=("-T")
    local_nonpersistent_flags+=("--transl-table=")
    flags+=("--trim")
    local_nonpersistent_flags+=("--trim")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_version()
{
    last_command="seqfu_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_watch()
{
    last_command="seqfu_watch"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--bins=")
    two_word_flags+=("--bins")
    two_word_flags+=("-B")
    local_nonpersistent_flags+=("--bins=")
    flags+=("--delay=")
    two_word_flags+=("--delay")
    two_word_flags+=("-W")
    local_nonpersistent_flags+=("--delay=")
    flags+=("--dump")
    flags+=("-y")
    local_nonpersistent_flags+=("--dump")
    flags+=("--fields=")
    two_word_flags+=("--fields")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--fields=")
    flags+=("--img=")
    two_word_flags+=("--img")
    two_word_flags+=("-O")
    local_nonpersistent_flags+=("--img=")
    flags+=("--list-fields")
    flags+=("-H")
    local_nonpersistent_flags+=("--list-fields")
    flags+=("--log")
    flags+=("-L")
    local_nonpersistent_flags+=("--log")
    flags+=("--pass")
    flags+=("-x")
    local_nonpersistent_flags+=("--pass")
    flags+=("--print-freq=")
    two_word_flags+=("--print-freq")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--print-freq=")
    flags+=("--qual-ascii-base=")
    two_word_flags+=("--qual-ascii-base")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--qual-ascii-base=")
    flags+=("--quiet-mode")
    flags+=("-Q")
    local_nonpersistent_flags+=("--quiet-mode")
    flags+=("--reset")
    flags+=("-R")
    local_nonpersistent_flags+=("--reset")
    flags+=("--validate-seq")
    flags+=("-v")
    local_nonpersistent_flags+=("--validate-seq")
    flags+=("--validate-seq-length=")
    two_word_flags+=("--validate-seq-length")
    two_word_flags+=("-V")
    local_nonpersistent_flags+=("--validate-seq-length=")
    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_seqfu_root_command()
{
    last_command="seqfu"

    command_aliases=()

    commands=()
    commands+=("amplicon")
    commands+=("bam")
    commands+=("common")
    commands+=("concat")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("concate")
        aliashash["concate"]="concat"
    fi
    commands+=("convert")
    commands+=("duplicate")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("dup")
        aliashash["dup"]="duplicate"
    fi
    commands+=("faidx")
    commands+=("fish")
    commands+=("fq2fa")
    commands+=("fx2tab")
    commands+=("genautocomplete")
    commands+=("grep")
    commands+=("head")
    commands+=("locate")
    commands+=("mutate")
    commands+=("range")
    commands+=("rename")
    commands+=("replace")
    commands+=("restart")
    commands+=("rmdup")
    commands+=("sample")
    commands+=("sana")
    commands+=("seq")
    commands+=("shuffle")
    commands+=("sliding")
    commands+=("sort")
    commands+=("split")
    commands+=("split2")
    commands+=("stats")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("stat")
        aliashash["stat"]="stats"
    fi
    commands+=("subseq")
    commands+=("tab2fx")
    commands+=("translate")
    commands+=("version")
    commands+=("watch")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--alphabet-guess-seq-length=")
    two_word_flags+=("--alphabet-guess-seq-length")
    flags+=("--id-ncbi")
    flags+=("--id-regexp=")
    two_word_flags+=("--id-regexp")
    flags+=("--line-width=")
    two_word_flags+=("--line-width")
    two_word_flags+=("-w")
    flags+=("--out-file=")
    two_word_flags+=("--out-file")
    two_word_flags+=("-o")
    flags+=("--quiet")
    flags+=("--seq-type=")
    two_word_flags+=("--seq-type")
    two_word_flags+=("-t")
    flags+=("--threads=")
    two_word_flags+=("--threads")
    two_word_flags+=("-j")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_seqfu()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __seqfu_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("seqfu")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local last_command
    local nouns=()

    __seqfu_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_seqfu seqfu
else
    complete -o default -o nospace -F __start_seqfu seqfu
fi

# ex: ts=4 sw=4 et filetype=sh
