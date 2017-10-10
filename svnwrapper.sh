#!/bin/sh
# This script is just a wrapper that holds the username and password on the 
# local variables and allowing the user to navigate inside repositories without
# having to reauthenticate and allowing the user to use svn commands easily.
# $Format:Author:%an <%ae> - Commiter:%cn <%ce> - %cd$

# Gets the real URL either by setting the right option or by getting the
# previous path
# $1:	The current URL
# $2:	The sub-directory
get_real_url()
{
	local URL=${1}
	local P=${2}

	if [ "${P}" = ".." ] ; then
		echo ${URL} | awk -F '/' \
			'{ 
				for (i = 1; i < NF; i++)
					if (i == NF - 1)
						printf "%s", $i; 
					else
						printf "%s/", $i; 
					
	       		}'
	else
		echo ${URL}/${P}
	fi
}

# Gets the right option for the given list
# $1:	The option to choose.
# $@:	The list of options
get_option()
{
	local OPT=${1}
	
	shift
	OPT=$((OPT * 2))
	echo ${@} | awk "{ print \$${OPT}; }" | tr -d '/'
}

: ${CONFIG_DIR:=${HOME}/.config/svnwrapper}

SERVER_URL=${1}
BASEDIR=$(dirname ${0})
BASEDIR=$(realpath ${BASEDIR})

BACKTITLE="SVN Wrapper"
USERNAME=
PASSWORD=
SVN=$(which svn || which svnlite)
SVN_COMMANDS=$(${SVN} help | awk -f ${BASEDIR}/svncmds.awk | tr '[(),]' ' ')
SVN_OPTS="--non-interactive --no-auth-cache --trust-server-cert"
CMD=ls

[ ! -d ${CONFIG_DIR} ] && mkdir -p ${CONFIG_DIR}

[ -z "${SERVER_URL}" ] && \
	dialog --backtitle "${BACKTITLE}" \
		--title "Server configuration" \
		--inputbox "Server to connect to:" 8 65 2> \
		${CONFIG_DIR}/server
SERVER_URL=$(cat ${CONFIG_DIR}/server)
SERVER_INIT=${SERVER_URL}

# Test for anonymus server
${SVN} ${CMD} ${SVN_OPTS} --username none --password "" ${SERVER_URL} \
	> /dev/null 2> /dev/null
if [ ${?} -ne 0 ] ; then
	dialog --backtitle "${BACKTITLE}" --title "Username" \
		--inputbox "Username for ${SERVER_URL}" 8 65 2> \
		${CONFIG_DIR}/username
	USERNAME=$(cat ${CONFIG_DIR}/username)
	rm ${CONFIG_DIR}/username

	dialog --backtitle "${BACKTITLE}" --title "Password" \
		--passwordbox "Password for ${USERNAME}" 8 65 2> \
		${CONFIG_DIR}/password
	PASSWORD=$(cat ${CONFIG_DIR}/password)
	rm ${CONFIG_DIR}/password

	${SVN} ${CMD} ${SVN_OPTS} --username "${USERNAME}" \
		--password "${PASSWORD}" ${SERVER_URL} > /dev/null 2> /dev/null
	[ ${?} -ne 0 ] && echo "[ERROR] Wrong credentials or wrong URL" && \
		exit 1
	SVN_OPTS="${SVN_OPTS} --username ${USERNAME} --password ${PASSWORD}"
	unset USERNAME PASSWORD
fi

while true ; do
	DISP_TXT="Current command: ${CMD}\nCurrent URL: ${SERVER_URL}"

	case "${CMD}" in
	ls|list)
		OPTIONS="1 .."
		ITER=2
		for ITEM in $(${SVN} ${SVN_OPTS} ${CMD} ${SERVER_URL}) ; do
			OPTIONS="${OPTIONS} ${ITER} ${ITEM}"
			ITER=$((ITER + 1))
		done
		dialog --backtitle "${BACKTITLE}" --title "Listing" \
			--extra-button --extra-label "Commands" \
			--menu "${DISP_TXT}" 60 65 55 ${OPTIONS} 2> \
			${CONFIG_DIR}/results
		case "${?}" in
		0)
			RES=$(cat ${CONFIG_DIR}/results)
			RES=$(get_option ${RES} ${OPTIONS})
			SERVER_URL=$(get_real_url ${SERVER_URL} ${RES})
			;;
		3)
			CMD=cmds
			;;
		*)
			exit 0
			;;
		esac
		;;
	cmds)
		OPTIONS=""
		ITER=1
		for ITEM in ${SVN_COMMANDS} ; do
			OPTIONS="${OPTIONS} ${ITER} ${ITEM}"
			ITER=$((ITER + 1))
		done
		dialog --backtitle "${BACKTITLE}" --title "Available Commands" \
			--menu "${DISP_TXT}" 60 65 55 ${OPTIONS} 2> \
			${CONFIG_DIR}/results
		if [ ${?} -eq 0 ] ; then
			CMD=$(cat ${CONFIG_DIR}/results)
			CMD=$(get_option ${CMD} ${OPTIONS})
		else
			CMD=ls
		fi
		;;
	*)
		${SVN} ${SVN_OPTS} ${CMD} ${SERVER_URL} | \
		dialog --backtitle "${BACKTITLE}" --title "SVN ${CMD} output" \
			--programbox 60 65
		CMD=ls
	esac
done
