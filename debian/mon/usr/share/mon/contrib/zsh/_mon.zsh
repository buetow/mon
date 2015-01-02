#compdef m mon

get_options() {
    elements=`${words[1,$[${CURRENT}-1]]} --dry --nocolor 2>&1`
    if [ $? -ne 0 ]; then
            elements=""
    fi

    echo `echo $elements | tr '\n' ' '`
}

_mon() { 
    local curcontext="$curcontext" state line
    typeset -A opt_args

    case $words[2] in
    getfmt)
        if [ $CURRENT -eq 5 ]; then
            compadd "$@" "where"
            return
        fi
    ;;
    post|put)
        if [ $CURRENT -eq 4 ]; then
            compadd "$@" "from"
            return
        fi
    ;;
    delete|edit|get|insert|update|view)
        if [ $CURRENT -eq 4 ]; then
            compadd "$@" "where"
            return
        fi
    ;;
    esac

    VALUES="`get_options`"
    if [ -z "${VALUES}" ]; then
        _files
    else
        ARGS=(${=VALUES})
        compadd "$@" ${ARGS[@]}
    fi
}

_mon "$@"
