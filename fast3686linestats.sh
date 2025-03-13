#!/bin/bash

# Parse cmdline options
#

function show_help() {
	echo "Usage: $(basename "${0}") [-c] [-h] [-i] [-p]"
	echo "  -c   Output modem line stats in CSV format"
	echo "  -h   Print this help and exit"
	echo "  -i   Post modem line stats to InfluxDB"
	echo "  -p   Pretty print modem line stats in human readable form"
}

if [ -z "${1}" ] 
then
	echo "Error: Nothing to do" >&2
	show_help >&2
	exit 1
fi

while getopts "chip" OPT
do
	case "${OPT}" in
	c)
		PRINT_CSV=1
		;;
	h)
		show_help
		exit 0
		;;
	i)
		POST_INFLUX=1
		;;
	p)
		PRINT_STDOUT=1
		;;
	*)
		exit 1
		;;
	esac
done

# Get credentials
#

[ -e "${HOME}/.fast3686linestats.conf" ] && source "${HOME}/.fast3686linestats.conf"

if [ -z "${FAST3686_URL}" ] \
	|| [ -z "${FAST3686_PASSWORD}" ]
then
	cat <<EOF >&2
Error: Missing cable modem credentials.
Please export the following variables:
  \$FAST3686_URL
  \$FAST3686_PASSWORD
or set it in \$HOME/.fast3686linestats.conf
EOF
	exit 1
fi

if [ -n "${POST_INFLUX}" ]
then
	if  [ -z "${INFLUX_URL}" ] \
		|| [ -z "${INFLUX_TOKEN}" ] \
		|| [ -z "${INFLUX_ORG}" ] \
		|| [ -z "${INFLUX_BUCKET_DOWNSTREAM}" ] \
		|| [ -z "${INFLUX_BUCKET_UPSTREAM}" ]
	then
		cat <<EOF >&2
Error: Missing InfluxDB credentials.
Please export the following variables:
  \$INFLUX_URL
  \$INFLUX_TOKEN
  \$INFLUX_ORG
  \$INFLUX_BUCKET_DOWNSTREAM
  \$INFLUX_BUCKET_UPSTREAM
or set them in \$HOME/.fast3686linestats.conf
EOF
		exit 1
	fi
fi

# Scrape data from modem
#

LOGINHTML="$(curl -s ${FAST3686_URL}/)"
TEMPFILE="$(mktemp "/tmp/rgConnect_stat_XXXXXXXX.txt")"

KEY="$(grep 'var SessionKey' <<<"${LOGINHTML}")"
KEY="${KEY//[!0-9]/}"
DSFREQ="$(grep -o '"currentDsFrequency" value=".*">' <<<"${LOGINHTML}" | cut -d '"' -f 4)"
INITDS="$(grep -o '"loginOrInitDS" value=".*"' <<<"${LOGINHTML}" | cut -d '"' -f 4)"
USCHAN="$(grep -o 'value=".*" align=right size=10 name="currentUSChannelID' <<<"${LOGINHTML}" | cut -d '"' -f 2)"
ADMUSR="$(grep -o 'name="loginUsername" maxlength="127" value=.*' <<<"${LOGINHTML}" | cut -d '=' -f 4 | cut -d '>' -f 1)"

LOGINURL="${FAST3686_URL}/goform/login?sessionKey=${KEY}"
LOGINDATA="loginOrInitDS=${INITDS}&loginUsername=${ADMUSR}&loginPassword=${FAST3686_PASSWORD}&currentDsFrequency=${DSFREQ}&currentUSChannelID=${USCHAN}"

SESSIONCOOKIE=$(curl -X POST -s -D - -o /dev/null -d "${LOGINDATA}" "${LOGINURL}" | grep Set-Cookie | cut -b 13-55)
curl -s --cookie "${SESSIONCOOKIE}" ${FAST3686_URL}/RgConnect.asp \
	| sed -e 's/<[^>]*>/ /g' >"${TEMPFILE}"

# Parse data to variables
#

IFS=$'\n' read -d '' -r -a DOWNSTREAM_DATA <<<$(grep QAM256 "${TEMPFILE}" \
	| awk '{printf("%s %s %s\n", $4, $7, $9);}')
for ((i=0; i<${#DOWNSTREAM_DATA[@]}; i++))
do
	read CHANNEL POWER SNR <<<${DOWNSTREAM_DATA[${i}]}
	DOWNSTREAM_POST_DATA="${DOWNSTREAM_POST_DATA}snr,channel=${CHANNEL} value=${SNR}"$'\n'
	DOWNSTREAM_POST_DATA="${DOWNSTREAM_POST_DATA}power,channel=${CHANNEL} value=${POWER}"$'\n'
	printf -v OUTPUT_LINE "%02d  %.1f dBmV  %.1f dB\n" "${CHANNEL}" "${POWER}" "${SNR}"
	DOWNSTREAM_PRINT_DATA="${DOWNSTREAM_PRINT_DATA}${OUTPUT_LINE}"
	printf -v CSV_LINE "DOWNSTREAM,%02d,%.1f,%.1f\n" "${CHANNEL}" "${POWER}" "${SNR}"
	DOWNSTREAM_CSV_DATA="${DOWNSTREAM_CSV_DATA}${CSV_LINE}"
done

IFS=$'\n' read -d '' -r -a UPSTREAM_DATA <<<$(grep ATDMA "${TEMPFILE}" \
	| awk '{printf("%s %s\n", $4, $9);}' \
	| sed 's/^\(.\) /0\1 /g')
for ((i=0; i<${#UPSTREAM_DATA[@]}; i++))
do
	read CHANNEL POWER <<<${UPSTREAM_DATA[${i}]}
	UPSTREAM_POST_DATA="${UPSTREAM_POST_DATA}power,channel=${CHANNEL} value=${POWER}"$'\n'
	printf -v OUTPUT_LINE "%02d  %.1f dBmV\n" "${CHANNEL}" "${POWER}"
	UPSTREAM_PRINT_DATA="${UPSTREAM_PRINT_DATA}${OUTPUT_LINE}"
	printf -v CSV_LINE "UPSTREAM,%02d,%.1f\n" "${CHANNEL}" "${POWER}"
	UPSTREAM_CSV_DATA="${UPSTREAM_CSV_DATA}${CSV_LINE}"
done

# Print and/or post values
#

if [ -n "${PRINT_STDOUT}" ]
then
	echo "DOWNSTREAM"
	echo "Ch  Power     SNR"
	echo -n "${DOWNSTREAM_PRINT_DATA}" | sort -n
	echo "UPSTREAM"
	echo "Ch  Power"
	echo -n "${UPSTREAM_PRINT_DATA}" | sort -n
fi

if [ -n "${PRINT_CSV}" ]
then
	echo -n "${DOWNSTREAM_CSV_DATA}" | sort -n
	echo -n "${UPSTREAM_CSV_DATA}" | sort -n
fi

if [ -n "${POST_INFLUX}" ]
then
	curl -s -X POST "${INFLUX_URL}/api/v2/write?org=${INFLUX_ORG}&bucket=${INFLUX_BUCKET_DOWNSTREAM}" \
		--header "Authorization: Token ${INFLUX_TOKEN}" \
		--data-raw "${DOWNSTREAM_POST_DATA}"
	curl -s -X POST "${INFLUX_URL}/api/v2/write?org=${INFLUX_ORG}&bucket=${INFLUX_BUCKET_UPSTREAM}" \
		--header "Authorization: Token ${INFLUX_TOKEN}" \
		--data-raw "${UPSTREAM_POST_DATA}"
fi

# Cleanup
#

rm "${TEMPFILE}"
