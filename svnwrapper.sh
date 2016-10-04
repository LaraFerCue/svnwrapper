#!/bin/sh
# This script is just a wrapper that holds the username and password on the 
# local variables and allowing the user to navigate inside repositories without
# having to reauthenticate and allowing the user to use svn commands easily.
# $Format:Author:%an <%ae> - Commiter:%cn <%ce> - %cd$

SERVER_URL=${1}

if [ -z "${SERVER_URL}" ] ; then
    read -p "Enter the SVN Server's URL: " SERVER_URL
fi

USERNAME=
PASSWORD=
SVN=$(which svn || which svnlite)
SVN_COMMANDS=$(${SVN} help | awk ' BEGIN { filter = 1; } /^Available subcommands:$/ { filter = 0; next; } { if (filter == 1) next; else if ($0 ~ /^[[:space:]]/ ) print $0; }'| tr '[(),]' ' ')

read -p "Username: " USERNAME

stty_origin=$(stty -g)
stty -echo
read -p "Password: " PASSWORD
stty ${stty_origin}
unset stty_origin
echo

LOCALREP=false
while true ; do
    read -p "svn> " CMD URL OPTIONS

    case "${CMD}" in
		exit|quit)
	        exit 0
			;;
		sh)
			${URL} ${OPTIONS}
			continue
			;;
		local)
			LOCALREP=true
			continue
			;;
		remote)
			LOCALREP=false
			continue
			;;
	esac

    [ "${URL}" = "." ] && URL=""

    do_continue=true
    for ITEM in ${SVN_COMMANDS} ; do
        if [ "${ITEM}" = "${CMD}" ] ; then
            do_continue=false
            break
        fi
    done

    if ${do_continue} ; then
        echo "--- Unkown command ${CMD} ---"
        continue
    fi

	if ${LOCALREP} ; then
		${SVN} --no-auth-cache --username "${USERNAME}" --password "${PASSWORD}" ${CMD} \
			${OPTIONS}
	else
	    ${SVN} --no-auth-cache --username "${USERNAME}" --password "${PASSWORD}" ${CMD} \
    	   ${SERVER_URL}/${URL} ${OPTIONS}
	    [ ${?} -eq 0 -a -n "${URL}" ] && SERVER_URL="${SERVER_URL}/${URL}"
	fi
done

