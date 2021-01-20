#!/bin/sh
#
# simple usage: 
# wget -O /usr/lib/nagios/plugins/check_ssl_cert "https://git.io/fhJWr"
#
# check_ssl_cert
#
# Checks an X.509 certificate:
# - checks if the server is running and delivers a valid certificate
# - checks if the CA matches a given pattern
# - checks the validity
#
# See  the INSTALL file for installation instructions
#
# Copyright (c) 2007-2012 ETH Zurich.
# Copyright (c) 2007-2021 Matteo Corti <matteo@corti.li>
#
# This module is free software; you can redistribute it and/or modify it
# under the terms of GNU general public license (gpl) version 3.
# See the LICENSE file for details.

################################################################################
# Constants

VERSION=1.132.0
SHORTNAME="SSL_CERT"

VALID_ATTRIBUTES=",startdate,enddate,subject,issuer,modulus,serial,hash,email,ocsp_uri,fingerprint,"

SIGNALS="HUP INT QUIT TERM ABRT"

LC_ALL=C

# return value for the creation of temporary files
TEMPFILE=""

################################################################################
# Variables
STATUS_OK=0
STATUS_WARNING=1
STATUS_CRITICAL=2
STATUS_UNKNOWN=3
WARNING_MSG=""
CRITICAL_MSG=""
ALL_MSG=""
################################################################################
# Functions

################################################################################
# Prints usage information
# Params
#   $1 error message (optional)
usage() {

    if [ -n "$1" ] ; then
        echo "Error: $1" 1>&2
    fi

    #### The following line is 80 characters long (helps to fit the help text in a standard terminal)
    ######--------------------------------------------------------------------------------

    echo
    echo "Usage: check_ssl_cert -H host [OPTIONS]"
    echo
    echo "Arguments:"
    echo "   -H,--host host                  server"
    echo
    echo "Options:"
    echo "   -A,--noauth                     ignore authority warnings (expiration only)"
    echo "      --altnames                   matches the pattern specified in -n with"
    echo "                                   alternate names too"
    echo "   -C,--clientcert path            use client certificate to authenticate"
    echo "      --clientpass phrase          set passphrase for client certificate."
    echo "   -c,--critical days              minimum number of days a certificate has to"
    echo "                                   be valid to issue a critical status. Default: ${CRITICAL_DAYS}"
    echo "      --crl                        checks revokation via CRL (requires --rootcert-file)"
    echo "      --curl-bin path              path of the curl binary to be used"
    echo "      --curl-user-agent string     user agent that curl shall use to obtain the"
    echo "                                   issuer cert"
    echo "      --custom-http-header string  custom HTTP header sent when getting the cert"
    echo "                                   example: 'X-Check-Ssl-Cert: Foobar=1'"
    echo "      --dane                       verify that valid DANE records exist (since OpenSSL 1.1.0)"
    echo "      --dane 211                   verify that a valid DANE-TA(2) SPKI(1) SHA2-256(1) TLSA record exists"
    echo "      --dane 301                   verify that a valid DANE-EE(3) Cert(0) SHA2-256(1) TLSA record exists"
    echo "      --dane 302                   verify that a valid DANE-EE(3) Cert(0) SHA2-512(2) TLSA record exists"
    echo "      --dane 311                   verify that a valid DANE-EE(3) SPKI(1) SHA2-256(1) TLSA record exists"
    echo "   -d,--debug                      produces debugging output"
    echo "      --dig-bin path               path of the dig binary to be used"
    echo "      --ecdsa                      signature algorithm selection: force ECDSA certificate"
    echo "      --element number             checks N cert element from the begining of the chain"
    echo "   -e,--email address              pattern to match the email address contained"
    echo "                                   in the certificate"
    echo "   -f,--file file                  local file path (works with -H localhost only)"
    echo "                                   with -f you can not only pass a x509"
    echo "                                   certificate file but also a certificate"
    echo "                                   revocation list (CRL) to check the validity"
    echo "                                   period"
    echo "      --file-bin path              path of the file binary to be used"
    echo "      --fingerprint SHA1           pattern to match the SHA1-Fingerprint"
    echo "      --first-element-only         verify just the first cert element, not the whole chain"
    echo "      --force-perl-date            force the usage of Perl for date computations"
    echo "      --format FORMAT              format output template on success, for example"
    echo "                                   \"%SHORTNAME% OK %CN% from '%CA_ISSUER_MATCHED%'\""
    echo "   -h,--help,-?                    this help message"
    echo "      --http-use-get               use GET instead of HEAD (default) for the HTTP"
    echo "                                   related checks"
    echo "      --ignore-exp                 ignore expiration date"
    echo "      --ignore-ocsp                do not check revocation with OCSP"
    echo "      --ignore-ocsp-timeout        ignore OCSP result when timeout occurs while checking"
    echo "      --ignore-sig-alg             do not check if the certificate was signed with SHA1"
    echo "                                   or MD5"
    echo "      --ignore-ssl-labs-cache      Forces a new check by SSL Labs (see -L)"
    echo "      --inetproto protocol         Force IP version 4 or 6"
    echo "   -i,--issuer issuer              pattern to match the issuer of the certificate"
    echo "      --issuer-cert-cache dir      directory where to store issuer certificates cache"
    echo "   -K,--clientkey path             use client certificate key to authenticate"
    echo "   -L,--check-ssl-labs grade       SSL Labs assessment"
    echo "                                   (please check https://www.ssllabs.com/about/terms.html)"
    echo "      --check-ssl-labs-warn grade  SSL-Labs grade on which to warn"
    echo "      --long-output list           append the specified comma separated (no spaces) list"
    echo "                                   of attributes to the plugin output on additional lines"
    echo "                                   Valid attributes are:"
    echo "                                     enddate, startdate, subject, issuer, modulus,"
    echo "                                     serial, hash, email, ocsp_uri and fingerprint."
    echo "                                   'all' will include all the available attributes."
    echo "   -n,--cn name                    pattern to match the CN of the certificate (can be"
    echo "                                   specified multiple times)"
    echo "      --nmap-bin path              path of the nmap binary to be used"
    echo "      --no-proxy                   ignores the http_proxy and https_proxy environment variables"
    echo "      --no-ssl2                    disable SSL version 2"
    echo "      --no-ssl3                    disable SSL version 3"
    echo "      --no-tls1                    disable TLS version 1"
    echo "      --no-tls1_1                  disable TLS version 1.1"
    echo "      --no-tls1_2                  disable TLS version 1.2"
    echo "      --no-tls1_3                  disable TLS version 1.3"
    echo "      --not-issued-by issuer       check that the issuer of the certificate does not match"
    echo "                                   the given pattern"
    echo "      --not-valid-longer-than days critical if the certificate validity is longer than"
    echo "                                   the specified period"
    echo "   -N,--host-cn                    match CN with the host name"
    echo "      --ocsp-critical hours        minimum number of hours an OCSP response has to be valid to"
    echo "                                   issue a critical status"
    echo "      --ocsp-warning hours         minimum number of hours an OCSP response has to be valid to"
    echo "                                   issue a warning status"
    echo "   -o,--org org                    pattern to match the organization of the certificate"
    echo "      --openssl path               path of the openssl binary to be used"
    echo "   -p,--port port                  TCP port"
    echo "   -P,--protocol protocol          use the specific protocol"
    echo "                                   {ftp|ftps|http|https|h2|imap|imaps|irc|ircs|ldap|ldaps|mysql|pop3|pop3s|"
    echo "                                    postgres|sieve|smtp|smtps|xmpp|xmpp-server}"
    echo "                                   https:                             default"
    echo "                                   h2:                                forces HTTP/2"
    echo "                                   ftp,imap,irc,ldap,pop3,postgres,sieve,smtp: switch to"
    echo "                                   TLS using StartTLS"
    echo "      --proxy proxy                sets http_proxy and the s_client -proxy option"
    echo "      --require-no-ssl2            critical if SSL version 2 is offered"
    echo "      --require-no-ssl3            critical if SSL version 3 is offered"
    echo "      --require-no-tls1            critical if TLS 1 is offered"
    echo "      --require-no-tls1_1          critical if TLS 1.1 is offered"
    echo "   -s,--selfsigned                 allows self-signed certificates"
    echo "      --serial serialnum           pattern to match the serial number"
    echo "      --skip-element number        skip checks on N cert element from the begining of the chain"
    echo "      --sni name                   sets the TLS SNI (Server Name Indication) extension"
    echo "                                   in the ClientHello message to 'name'"
    echo "      --ssl2                       forces SSL version 2"
    echo "      --ssl3                       forces SSL version 3"
    echo "      --require-ocsp-stapling      require OCSP stapling"
    echo "      --require-san                require the presence of a Subject Alternative Name"
    echo "                                   extension"
    echo "   -r,--rootcert path              root certificate or directory to be used for"
    echo "                                   certificate validation"
    echo "      --rootcert-dir path          root directory to be used for certificate validation"
    echo "      --rootcert-file path         root certificate to be used for certificate validation"
    echo "      --rsa                        signature algorithm selection: force RSA certificate"
    echo "      --temp dir                   directory where to store the temporary files"
    echo "      --terse                      terse output"
    echo "   -t,--timeout                    seconds timeout after the specified time"
    echo "                                   (defaults to ${TIMEOUT} seconds)"
    echo "      --tls1                       force TLS version 1"
    echo "      --tls1_1                     force TLS version 1.1"
    echo "      --tls1_2                     force TLS version 1.2"
    echo "      --tls1_3                     force TLS version 1.3"
    echo "   -v,--verbose                    verbose output"
    echo "   -V,--version                    version"
    echo "   -w,--warning days               minimum number of days a certificate has to be valid"
    echo "                                   to issue a warning status. Default: ${WARNING_DAYS}"
    echo "      --xmpphost name              specifies the host for the 'to' attribute of the stream element"
    echo "   -4                              force IPv4"
    echo "   -6                              force IPv6"
    echo
    echo "Deprecated options:"
    echo "      --days days                  minimum number of days a certificate has to be valid"
    echo "                                   (see --critical and --warning)"
    echo "      --ocsp                       check revocation via OCSP"
    echo "   -S,--ssl version                force SSL version (2,3)"
    echo "                                   (see: --ssl2 or --ssl3)"
    echo
    echo "Report bugs to https://github.com/matteocorti/check_ssl_cert/issues"
    echo

    exit "${STATUS_UNKNOWN}"

}

################################################################################
# Prints the given message to STDERR with the prefix '[DBG] ' if the debug
# command line option was specified
# $1: string
debuglog() {
    if [ -n "${DEBUG}" ] ; then
	echo "${1}" | sed 's/^/[DBG] /' >&2
    fi
}

################################################################################
# Prints the given message to STDOUT if the verbose command line opttion was
# specified
# $1: string
verboselog() {
    if [ -n "${VERBOSE}" ] ; then
        echo "${1}" >&2
    fi
}

################################################################################
# trap passing the signal name
# see https://stackoverflow.com/questions/2175647/is-it-possible-to-detect-which-trap-signal-in-bash/2175751#2175751
trap_with_arg() {
    func="$1" ; shift
    for sig ; do
        # shellcheck disable=SC2064
        trap "${func} ${sig}" "${sig}"
    done
}

################################################################################
# Cleanup temporary files
remove_temporary_files() {
    debuglog "cleaning up temporary files"
    debuglog "$(echo "${TEMPORARY_FILES}" | tr '\ ' '\n')"
    # shellcheck disable=SC2086
    if [ -n "${TEMPORARY_FILES}" ]; then
        rm -f ${TEMPORARY_FILES}
    fi
}

################################################################################
# Cleanup when exiting
cleanup() {
    SIGNAL=$1
    debuglog "signal caught ${SIGNAL}"
    remove_temporary_files
    # shellcheck disable=SC2086
    trap - ${SIGNALS}
    exit
}

create_temporary_file() {

    # create a temporary file    
    TEMPFILE="$( mktemp "${TMPDIR}/XXXXXX" 2> /dev/null )"
    if [ -z "${TEMPFILE}" ] || [ ! -w "${TEMPFILE}" ] ; then
        unknown 'temporary file creation failure.'
    fi

    debuglog "temporary file ${TEMPFILE} created"

    # add the file to the list of temporary files
    TEMPORARY_FILES="${TEMPORARY_FILES} ${TEMPFILE}"

}

################################################################################
# Compute the number of hours until a given date
# Params
#   $1 date
# return HOURS_UNTIL
hours_until() {

    DATE=$1

    debuglog "Date computations: ${DATETYPE}"
    debuglog "Computing number of hours until '${DATE}'"

    case "${DATETYPE}" in
        "BSD")
            HOURS_UNTIL=$(( ( $(${DATEBIN} -jf "%b %d %T %Y %Z" "${DATE}" +%s) - $(${DATEBIN} +%s) ) / 3600 ))
            ;;

        "GNU")
            HOURS_UNTIL=$(( ( $(${DATEBIN} -d "${DATE}" +%s) - $(${DATEBIN} +%s) ) / 3600 ))
            ;;

        "PERL")
            # Warning: some shell script formatting tools will indent the EOF! (should be at position 0)
            if ! HOURS_UNTIL=$(perl - "${DATE}" <<-"EOF"
                    use strict;
                    use warnings;
                    use Date::Parse;
                    my $cert_date = str2time( $ARGV[0] );
                    my $hours = int (( $cert_date - time ) / 3600 + 0.5);
                    print "$hours\n";
EOF
                 ) ; then
                # something went wrong with the embedded Perl code: check the indentation of EOF
                unknown "Error computing the certificate validity with Perl"
            fi
            ;;
    *)
        unknown "Internal error: unknown date type"
    esac

    debuglog "Hours until ${DATE}: ${HOURS_UNTIL}"
    echo "${HOURS_UNTIL}"

}

################################################################################
# prepends critical messages to list of all messages
# Params
#   $1 error message
prepend_critical_message() {

    debuglog "CRITICAL >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    debuglog "prepend_critical_message: new message    = $1"
    debuglog "prepend_critical_message: HOST           = ${HOST}"
    debuglog "prepend_critical_message: CN             = ${CN}"
    debuglog "prepend_critical_message: SNI            = ${SNI}"
    debuglog "prepend_critical_message: FILE           = ${FILE}"
    debuglog "prepend_critical_message: SHORTNAME      = ${SHORTNAME}"
    debuglog "prepend_critical_message: MSG            = ${MSG}"
    debuglog "prepend_critical_message: CRITICAL_MSG   = ${CRITICAL_MSG}"
    debuglog "prepend_critical_message: ALL_MSG 1      = ${ALL_MSG}"

    if [ -n "${CN}" ] ; then
        tmp=" ${CN}"
    else
        if [ -n "${HOST}" ] ; then
            if [ -n "${SNI}" ] ; then
                tmp=" ${SNI}"
            elif [ -n "${FILE}" ] ; then
                tmp=" ${FILE}"
            else
                tmp=" ${HOST}"
            fi
        fi
    fi

    MSG="${SHORTNAME} CRITICAL${tmp}: ${1}${LONG_OUTPUT}"

    if [ "${CRITICAL_MSG}" = "" ]; then
        CRITICAL_MSG="${MSG}"
    fi

    ALL_MSG="\n    ${MSG}${ALL_MSG}"

    debuglog "prepend_critical_message: MSG 2          = ${MSG}"
    debuglog "prepend_critical_message: CRITICAL_MSG 2 = ${CRITICAL_MSG}"
    debuglog "prepend_critical_message: ALL_MSG 2      = ${ALL_MSG}"
    debuglog "CRITICAL <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

}

################################################################################
# Exits with a critical message
# Params
#   $1 error message
critical() {

    remove_temporary_files

    debuglog 'exiting with CRITICAL'
    debuglog "ALL_MSG = ${ALL_MSG}"

    NUMBER_OF_ERRORS=$( printf '%b' "${ALL_MSG}" | wc -l )

    debuglog "number of errors = ${NUMBER_OF_ERRORS}"

    if [ "${NUMBER_OF_ERRORS}" -ge 2 ] && [ -n "${VERBOSE}" ] ; then
        printf '%s%s\nError(s):%b\n' "$1" "${PERFORMANCE_DATA}" "${ALL_MSG}"
    else
        printf '%s%s \n' "$1" "${PERFORMANCE_DATA}"
    fi

    exit "${STATUS_CRITICAL}"
}

################################################################################
# append all warning messages to list of all messages
# Params
#   $1 warning message
append_warning_message() {

    debuglog "WARNING >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    debuglog "append_warning_message: HOST         = ${HOST}"
    debuglog "append_warning_message: CN           = ${CN}"
    debuglog "append_warning_message: SNI          = ${SNI}"
    debuglog "append_warning_message: FILE         = ${FILE}"
    debuglog "append_warning_message: SHORTNAME    = ${SHORTNAME}"
    debuglog "prepend_warning_message: MSG         = ${MSG}"
    debuglog "prepend_warning_message: WARNING_MSG = ${WARNING_MSG}"
    debuglog "prepend_warning_message: ALL_MSG 1   = ${ALL_MSG}"

    if [ -n "${CN}" ] ; then
        tmp=" ${CN}"
    else
        if [ -n "${HOST}" ] ; then
            if [ -n "${SNI}" ] ; then
                tmp=" ${SNI}"
            elif [ -n "${FILE}" ] ; then
                tmp=" ${FILE}"
            else
                 tmp=" ${HOST}"
            fi
        fi
    fi

    MSG="${SHORTNAME} WARN${tmp}: ${1}${LONG_OUTPUT}"

    if [ "${WARNING_MSG}" = "" ]; then
        WARNING_MSG="${MSG}"
    fi

    ALL_MSG="${ALL_MSG}\n    ${MSG}"


    debuglog "prepend_warning_message: MSG 2          = ${MSG}"
    debuglog "prepend_warning_message: WARNING_MSG 2 = ${WARNING_MSG}"
    debuglog "prepend_warning_message: ALL_MSG 2      = ${ALL_MSG}"
    debuglog "WARNING <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"

}


################################################################################
# Exits with a warning message
# Param
#   $1 warning message
warning() {

    remove_temporary_files

    NUMBER_OF_ERRORS=$( printf '%b' "${ALL_MSG}" | wc -l )

    if [ "${NUMBER_OF_ERRORS}" -ge 2 ] && [ -n "${VERBOSE}" ]; then
        printf '%s%s\nError(s):%b\n' "$1" "${PERFORMANCE_DATA}" "${ALL_MSG}"
    else
        printf '%s %s\n' "$1" "${PERFORMANCE_DATA}"
    fi

    exit "${STATUS_WARNING}"
}

################################################################################
# Exits with an 'unknown' status
# Param
#   $1 message
unknown() {
    if [ -n "${HOST}" ] ; then
        if [ -n "${SNI}" ] ; then
            tmp=" ${SNI}"
        elif [ -n "${FILE}" ] ; then
            tmp=" ${FILE}"
        else
            tmp=" ${HOST}"
        fi
    fi
    remove_temporary_files
    printf '%s UNKNOWN%s: %s\n' "${SHORTNAME}" "${tmp}" "$1"
    exit "${STATUS_UNKNOWN}"
}


################################################################################
# Exits with unknown if s_client does not support the given option
#
# Usage:
#   require_s_client_option '-no_ssl2'
#
require_s_client_option() {
    debuglog "Checking if s_client supports the $1 option"
    if ! "${OPENSSL}" s_client -help 2>&1 | grep -q -- "$1" ; then
	unknown "s_client does not support the $1 option"
    fi
}

################################################################################
# To set a variable with an HEREDOC in a POSIX compliant way
# see: https://unix.stackexchange.com/questions/340718/how-do-i-bring-heredoc-text-into-a-shell-script-variable
# Usage:
#   set_variable variablename<<'HEREDOC'
#   ...
#  HEREDOC
set_variable() {
    # shellcheck disable=SC2016
    eval "$1"'=$(cat)'
}

################################################################################
# Executes command with a timeout
# Params:
#   $1 timeout in seconds
#   $2 command
# Returns 1 if timed out 0 otherwise
exec_with_timeout() {

    time=$1

    # start the command in a subshell to avoid problem with pipes
    # (spawn accepts one command)
    command="/bin/sh -c \"$2\""

    debuglog "executing with timeout (${time}s): $2"

    if [ -n "${TIMEOUT_BIN}" ] ; then

        debuglog "$(printf "%s %s %s\n" "${TIMEOUT_BIN}" "${time}" "${command}")"

	# We execute timeout in the backgroud so that it can be relay a signal to 'timeout'
	# https://unix.stackexchange.com/questions/57667/why-cant-i-kill-a-timeout-called-from-a-bash-script-with-a-keystroke/57692#57692	
        eval "${TIMEOUT_BIN} ${time} ${command} &" > /dev/null 2>&1
	TIMEOUT_PID=$!
	wait "${TIMEOUT_PID}"
        RET=$?

        # return codes
        # https://www.gnu.org/software/coreutils/manual/coreutils.html#timeout-invocation
        if [ "${RET}" -eq 137 ] ; then
            prepend_critical_message "SIGKILL received"
        elif [ "${RET}" -eq 124 ] ; then
            prepend_critical_message "Timeout after ${time} seconds"
        elif [ "${RET}" -eq 125 ] ; then
            prepend_critical_message "execution of ${command} failed"
        elif [ "${RET}" -eq 126 ] ; then
            prepend_critical_message "${command} is found but cannot be invoked"
        elif [ "${RET}" -eq 127 ] ; then
            prepend_critical_message "${command} cannot be found"
        fi

        return "${RET}"

    elif [ -n "${EXPECT}" ] ; then

        # just to tell shellcheck that the variable is assigned
        # (in fact the value is assigned with the function set_value)
        EXPECT_SCRIPT=''
        TIMEOUT_ERROR_CODE=42

        set_variable EXPECT_SCRIPT << EOT

set echo \"-noecho\"
set timeout ${time}

# spawn the process
spawn -noecho sh -c { ${command} }

expect {
  timeout { exit ${TIMEOUT_ERROR_CODE} }
  eof
}

# Get the return value
# https://stackoverflow.com/questions/23614039/how-to-get-the-exit-code-of-spawned-process-in-expect-shell-script

foreach { pid spawnid os_error_flag value } [wait] break

# return the command return value
exit \$value

EOT

        debuglog 'Executing expect script'
        debuglog "$(printf '%s' "${EXPECT_SCRIPT}")"

        echo "${EXPECT_SCRIPT}" | expect
        RET=$?

        debuglog "expect returned ${RET}"

        if [ "${RET}" -eq "${TIMEOUT_ERROR_CODE}" ] ; then
            prepend_critical_message "Timeout after ${time} seconds"
            critical "${SHORTNAME} CRITICAL: Timeout after ${time} seconds"
        fi

        return "${RET}"

    else

        debuglog "$(printf "%s\n" eval "${command}")"

        eval "${command}"
        return $?

    fi

}

################################################################################
# Checks if a given program is available and executable
# Params
#   $1 program name
# Returns 1 if the program exists and is executable
check_required_prog() {

    PROG=$(command -v "$1" 2> /dev/null)

    if [ -z "${PROG}" ] ; then
        unknown "cannot find program: $1"
    fi

    if [ ! -x "${PROG}" ] ; then
        unknown "${PROG} is not executable"
    fi

}


################################################################################
# Checks cert revokation via CRL
# Params
#   $1 cert
#   $2 element number
check_crl() {
    el_number=1
    if [ -n "$2" ]; then
        el_number=$2
    fi

    create_temporary_file; CERT_ELEMENT=${TEMPFILE}
    debuglog "Storing the chain element in ${CERT_ELEMENT}"
    echo "${1}" > "${CERT_ELEMENT}"
    
    # We check all the elements of the chain (but the root) for revocation
    # If any element is revoked, the certificate should not be trusted
    # https://security.stackexchange.com/questions/5253/what-happens-when-an-intermediate-ca-is-revoked
 
    debuglog "Checking CRL status of element ${el_number}"

    # See https://raymii.org/s/articles/OpenSSL_manually_verify_a_certificate_against_a_CRL.html

    CRL_URI=$( "${OPENSSL}" x509 -noout -text -in "${CERT_ELEMENT}" |
		   grep -A 4 'X509v3 CRL Distribution Points' |
		   grep URI |
		   sed 's/^.*URI://'
	   )

    if [ -n "${CRL_URI}" ] ; then

	debuglog "Certificate revokation list available (${CRL_URI})"

	debuglog "CRL: fetching CRL ${CRL_URI} to ${CRL_TMP_DER}"

        if [ -n "${CURL_USER_AGENT}" ] ; then
            exec_with_timeout "${TIMEOUT}" "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent --user-agent '${CURL_USER_AGENT}' --location \\\"${CRL_URI}\\\" > ${CRL_TMP_DER}"
        else
            exec_with_timeout "${TIMEOUT}" "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent --location \\\"${CRL_URI}\\\" > ${CRL_TMP_DER}"
        fi

	# convert DER to
	debuglog "Converting ${CRL_TMP_DER} (DER) to ${CRL_TMP_PEM} (PEM)"
	"${OPENSSL}" crl -inform DER -in "${CRL_TMP_DER}" -outform PEM -out "${CRL_TMP_PEM}"     

	# combine the certificate and the CRL
	debuglog "Combining the certificate, the CRL and the root cert"
	debuglog "cat ${CRL_TMP_PEM} ${CERT} ${ROOT_CA_FILE} > ${CRL_TMP_CHAIN}"
	cat "${CRL_TMP_PEM}" "${CERT}" "${ROOT_CA_FILE}" > "${CRL_TMP_CHAIN}"

	debuglog "${OPENSSL} verify -crl_check -CRLfile ${CRL_TMP_PEM} ${CERT_ELEMENT}"
	CRL_RESULT=$( "${OPENSSL}" verify -crl_check -CAfile "${CRL_TMP_CHAIN}" -CRLfile "${CRL_TMP_PEM}"  "${CERT_ELEMENT}" 2>&1 |
			  grep ':' |
			  head -n 1 |
			  sed 's/^.*:\ //'
		  )

	debuglog "  result: ${CRL_RESULT}"

	if ! [ "${CRL_RESULT}" = 'OK' ] ; then
	    prepend_critical_message "certificate element ${el_number} is revoked (CRL)"
	fi
	
    else

	debuglog "Certificate revokation list not available"

    fi
    
}

################################################################################
# Checks cert revokation via OCSP
# Params
#   $1 cert
#   $2 element number
check_ocsp() {
    el_number=1
    if [ -n "$2" ]; then
        el_number=$2
    fi

    # We check all the elements of the chain (but the root) for revocation
    # If any element is revoked, the certificate should not be trusted
    # https://security.stackexchange.com/questions/5253/what-happens-when-an-intermediate-ca-is-revoked
    
    debuglog "Checking OCSP status of element ${el_number}"

    create_temporary_file; CERT_ELEMENT=${TEMPFILE}
    debuglog "Storing the chain element in ${CERT_ELEMENT}"
    echo "${1}" > "${CERT_ELEMENT}"

    ################################################################################
    # Check revocation via OCSP
    if [ -n "${OCSP}" ]; then

        debuglog "Checking revokation via OCSP"

        ISSUER_HASH="$(${OPENSSL} x509 -in "${CERT_ELEMENT}" -noout -issuer_hash)"
	debuglog "Issuer hash: ${ISSUER_HASH}"

        if [ -z "${ISSUER_HASH}" ] ; then
            unknown 'unable to find issuer certificate hash.'
        fi

	ISSUER_CERT=
        if [ -n "${ISSUER_CERT_CACHE}" ] ; then

            if [ -r "${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt" ]; then

                debuglog "Found cached Issuer Certificate: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

                ISSUER_CERT="${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

            else

                debuglog "Not found cached Issuer Certificate: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"


            fi

        fi
	
	# we just consider the first HTTP(S) URI
	# TODO check SC2016
	# shellcheck disable=SC2086,SC2016

	ELEMENT_ISSUER_URI="$( ${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -text -noout -in ${CERT_ELEMENT} | grep "CA Issuers" | grep -i "http" | head -n 1 | sed -e "s/^.*CA Issuers - URI://" | tr -d '"!|;$(){}<>`&')"

	debuglog "Chain element issuer URI: ${ELEMENT_ISSUER_URI}"

	# TODO: should be checked
	# shellcheck disable=SC2021
	if [ -z "${ELEMENT_ISSUER_URI}" ] ; then
            verboselog "cannot find the CA Issuers in the certificate: disabling OCSP checks on element ${el_number}"
            return
	elif [ "${ELEMENT_ISSUER_URI}" != "$(echo "${ELEMENT_ISSUER_URI}" | tr -d '[[:space:]]')" ]; then
            verboselog "unable to fetch the CA issuer certificate (spaces in URI): disabling OCSP checks on element ${el_number}"
	    return 
	elif ! echo "${ELEMENT_ISSUER_URI}" | grep -qi '^http' ; then
            verboselog "unable to fetch the CA issuer certificate (unsupported protocol): disabling OCSP checks on element ${el_number}"
            return
	fi


        if [ -z "${ISSUER_CERT}" ] ; then

            debuglog "OCSP: fetching issuer certificate ${ELEMENT_ISSUER_URI} to ${ISSUER_CERT_TMP}"

            if [ -n "${CURL_USER_AGENT}" ] ; then
                exec_with_timeout "${TIMEOUT}" "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent --user-agent '${CURL_USER_AGENT}' --location \\\"${ELEMENT_ISSUER_URI}\\\" > ${ISSUER_CERT_TMP}"
            else
                exec_with_timeout "${TIMEOUT}" "${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent --location \\\"${ELEMENT_ISSUER_URI}\\\" > ${ISSUER_CERT_TMP}"
            fi

            debuglog "OCSP: issuer certificate type (1): $(${FILE_BIN} "${ISSUER_CERT_TMP}" | sed 's/.*://' )"

	    if echo "${ELEMENT_ISSUER_URI}" | grep -q 'p7c' ; then
		debuglog "OCSP: converting issuer certificate from PKCS #7 to PEM"

                cp "${ISSUER_CERT_TMP}" "${ISSUER_CERT_TMP2}"

                ${OPENSSL} pkcs7 -print_certs -inform DER -outform PEM -in "${ISSUER_CERT_TMP2}" -out "${ISSUER_CERT_TMP}"

	    fi

	    debuglog "OCSP: issuer certificate type (2): $(${FILE_BIN} "${ISSUER_CERT_TMP}" | sed 's/.*://' )"

            # check the result
            if ! "${FILE_BIN}" "${ISSUER_CERT_TMP}" | grep -E -q ': (ASCII|PEM)' ; then
		
                if "${FILE_BIN}" "${ISSUER_CERT_TMP}" | grep -E -q '(data|Certificate)' ; then

                    debuglog "OCSP: converting issuer certificate from DER to PEM"

                    cp "${ISSUER_CERT_TMP}" "${ISSUER_CERT_TMP2}"

                    ${OPENSSL} x509 -inform DER -outform PEM -in "${ISSUER_CERT_TMP2}" -out "${ISSUER_CERT_TMP}"

                else

		    debuglog "OCSP: complete issuer certificate type $( ${FILE_BIN} "${ISSUER_CERT_TMP}" )"

                    unknown "Unable to fetch a valid certificate issuer certificate."

                fi

            fi

	    debuglog "OCSP: issuer certificate type (3): $(${FILE_BIN} "${ISSUER_CERT_TMP}" | sed 's/.*://' )"

            if [ -n "${DEBUG}" ] ; then

                # remove trailing /
                FILE_NAME=${ELEMENT_ISSUER_URI%/}

                # remove everything up to the last slash
                FILE_NAME="${TMPDIR}/${FILE_NAME##*/}"

                debuglog "OCSP: storing a copy of the retrieved issuer certificate to ${FILE_NAME}"

                cp "${ISSUER_CERT_TMP}" "${FILE_NAME}"
            fi

            if [ -n "${ISSUER_CERT_CACHE}" ] ; then
                if [ ! -w "${ISSUER_CERT_CACHE}" ]; then

                    unknown "Issuer certificates cache ${ISSUER_CERT_CACHE} is not writeable!"

                fi

                debuglog "Storing Issuer Certificate to cache: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

                cp "${ISSUER_CERT_TMP}" "${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

            fi

            ISSUER_CERT=${ISSUER_CERT_TMP}

        fi


	# TO DO: we just take the first result: a loop over all the hosts should
        # shellcheck disable=SC2086
        OCSP_URI="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT_ELEMENT}" -ocsp_uri -noout | head -n 1)"
	debuglog "OSCP: URI = ${OCSP_URI}"
	
        OCSP_HOST="$(echo "${OCSP_URI}" | sed -e "s@.*//\\([^/]\\+\\)\\(/.*\\)\\?\$@\\1@g" | sed 's/^http:\/\///' | sed 's/\/.*//' )"

        debuglog "OCSP: host = ${OCSP_HOST}"

        if [ -n "${OCSP_HOST}" ] ; then

            # check if -header is supported
            OCSP_HEADER=""

            # ocsp -header is supported in OpenSSL versions from 1.0.0, but not documented until 1.1.0
            # so we check if the major version is greater than 0
            if "${OPENSSL}" version | grep -q '^LibreSSL' || [ "$( ${OPENSSL} version | sed -e 's/OpenSSL \([0-9]\).*/\1/g' )" -gt 0 ] ; then

                debuglog "openssl ocsp supports the -header option"

                # the -header option was first accepting key and value separated by space. The newer versions are using key=value
                KEYVALUE=""
                if ${OPENSSL} ocsp -help 2>&1 | grep header | grep -q 'key=value' ; then
                    debuglog "${OPENSSL} ocsp -header requires 'key=value'"
                    KEYVALUE=1
                else
                    debuglog "${OPENSSL} ocsp -header requires 'key value'"
                fi

                # http_proxy is sometimes lower- and sometimes uppercase. Programs usually check both
                # shellcheck disable=SC2154
                if [ -n "${http_proxy}" ] ; then
                    HTTP_PROXY="${http_proxy}"
                fi

                if [ -n "${HTTP_PROXY:-}" ] ; then
                    OCSP_PROXY_ARGUMENT="$( echo "${HTTP_PROXY}" | sed 's/.*:\/\///' | sed 's/\/$//' )"

                    if [ -n "${KEYVALUE}" ] ; then
                        debuglog "executing ${OPENSSL} ocsp -timeout \"${TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT} -host \"${OCSP_PROXY_ARGUMENT}\" -path ${OCSP_URI} -header HOST=${OCSP_HOST}"
                        OCSP_RESP="$(${OPENSSL} ocsp -timeout "${TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -host "${OCSP_PROXY_ARGUMENT}" -path "${OCSP_URI}" -header HOST="${OCSP_HOST}" 2>&1 )"
                    else
                        debuglog "executing ${OPENSSL} ocsp -timeout \"${TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT} -host \"${OCSP_PROXY_ARGUMENT}\" -path ${OCSP_URI} -header HOST ${OCSP_HOST}"
                        OCSP_RESP="$(${OPENSSL} ocsp -timeout "${TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -host "${OCSP_PROXY_ARGUMENT}" -path "${OCSP_URI}" -header HOST "${OCSP_HOST}" 2>&1 )"
                    fi

                else

                    if [ -n "${KEYVALUE}" ] ; then
                        debuglog "executing ${OPENSSL} ocsp -timeout \"${TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT}  -url ${OCSP_URI} ${OCSP_HEADER} -header HOST=${OCSP_HOST}"
                        OCSP_RESP="$(${OPENSSL} ocsp -timeout "${TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -url "${OCSP_URI}" -header "HOST=${OCSP_HOST}" 2>&1 )"
                    else
                        debuglog "executing ${OPENSSL} ocsp -timeout \"${TIMEOUT}\" -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT_ELEMENT}  -url ${OCSP_URI} ${OCSP_HEADER} -header HOST ${OCSP_HOST}"
                        OCSP_RESP="$(${OPENSSL} ocsp -timeout "${TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -url "${OCSP_URI}" -header HOST "${OCSP_HOST}" 2>&1 )"
                    fi

                fi

                debuglog "$(echo "${OCSP_RESP}" | sed 's/^/OCSP: response = /')"

                if [ -n "${OCSP_IGNORE_TIMEOUT}" ] && echo "${OCSP_RESP}" | grep -qi "timeout on connect" ; then

                    debuglog 'OCSP: Timeout on connect'

                elif echo "${OCSP_RESP}" | grep -qi "revoked" ; then

                    debuglog 'OCSP: revoked'

                    prepend_critical_message "certificate element ${el_number} is revoked (OCSP)"

                elif ! echo "${OCSP_RESP}" | grep -qi "good" ; then

                    debuglog "OCSP: not good. HTTP_PROXY = ${HTTP_PROXY}"

                    if [ -n "${HTTP_PROXY:-}" ] ; then

                        debuglog "executing ${OPENSSL} ocsp -timeout \"${TIMEOUT}\" -no_nonce -issuer \"${ISSUER_CERT}\" -cert \"${CERT_ELEMENT}]\" -host \"${HTTP_PROXY#*://}\" -path \"${OCSP_URI}\" \"${OCSP_HEADER}\" 2>&1"

                        if [ -n "${OCSP_HEADER}" ] ; then
                            OCSP_RESP="$(${OPENSSL} ocsp -timeout "${TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -host "${HTTP_PROXY#*://}" -path "${OCSP_URI}" "${OCSP_HEADER}" 2>&1 )"
                        else
                            OCSP_RESP="$(${OPENSSL} ocsp -timeout "${TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -host "${HTTP_PROXY#*://}" -path "${OCSP_URI}" 2>&1 )"
                        fi

                    else

                        debuglog "executing ${OPENSSL} ocsp -timeout \"${TIMEOUT}\" -no_nonce -issuer \"${ISSUER_CERT}\" -cert \"${CERT_ELEMENT}\" -url \"${OCSP_URI}\" \"${OCSP_HEADER}\" 2>&1"

                        if [ -n "${OCSP_HEADER}" ] ; then
                            OCSP_RESP="$(${OPENSSL} ocsp -timeout "${TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -url "${OCSP_URI}" "${OCSP_HEADER}" 2>&1 )"
                        else
                            OCSP_RESP="$(${OPENSSL} ocsp -timeout "${TIMEOUT}" -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT_ELEMENT}" -url "${OCSP_URI}" 2>&1 )"
                        fi

                    fi

                    verboselog "OCSP Error: ${OCSP_RESP}"

                    prepend_critical_message "OCSP error (-v for details)"

                fi

            else

                verboselog "openssl ocsp does not support the -header option: disabling OCSP checks"

            fi

        else

                verboselog "no OCSP host found: disabling OCSP checks"

        fi

    fi

}


################################################################################
# Checks cert end date validity
# Params
#   $1 cert
#   $2 element number
# Returns number of days
check_cert_end_date() {
    el_number=1
    if [ -n "$2" ]; then
        el_number=$2
    fi

    debuglog "Checking expiration date of element ${el_number}"

    # shellcheck disable=SC2086  
    ELEM_END_DATE=$(echo "${1}" | "${OPENSSL}" "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -noout "${OPENSSL_ENDDATE_OPTION}" | sed -e "s/.*=//")
    debuglog "Validity date on cert element ${el_number} is ${ELEM_END_DATE}"

    HOURS_UNTIL=$(hours_until "${ELEM_END_DATE}")
    ELEM_DAYS_VALID=$(( HOURS_UNTIL / 24 ))
    if [ -z "${DAYS_VALID}" ] || [ "${ELEM_DAYS_VALID}" -lt "${DAYS_VALID}" ]; then
        DAYS_VALID="${ELEM_DAYS_VALID}"
    fi

    add_performance_data "days_chain_elem${el_number}=${ELEM_DAYS_VALID};${WARNING_DAYS};${CRITICAL_DAYS};;"

    if [ "${OPENSSL_COMMAND}" = "x509" ]; then
        # x509 certificates (default)
        # We always check expired certificates
        debuglog "executing: ${OPENSSL} x509 -noout -checkend 0 on cert element ${el_number}"
        if ! echo "${1}" | ${OPENSSL} x509 -noout -checkend 0 > /dev/null ; then
            prepend_critical_message "${OPENSSL_COMMAND} certificate element ${el_number} is expired (was valid until ${ELEM_END_DATE})"
            return 2
        fi

        if [ -n "${CRITICAL_DAYS}" ] ; then

            debuglog "executing: ${OPENSSL} x509 -noout -checkend $(( CRITICAL_DAYS * 86400 )) on cert element ${el_number}"

            if ! echo "${1}" | ${OPENSSL} x509 -noout -checkend $(( CRITICAL_DAYS * 86400 )) > /dev/null ; then
                prepend_critical_message "${OPENSSL_COMMAND} certificate element ${el_number} will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}"
                return 2
            fi

        fi

        if [ -n "${WARNING_DAYS}" ] ; then

	    debuglog "executing: ${OPENSSL} x509 -noout -checkend $(( WARNING_DAYS * 86400 )) on cert element ${el_number}"

            if ! echo "$1" | ${OPENSSL} x509 -noout -checkend $(( WARNING_DAYS * 86400 )) > /dev/null ; then
                append_warning_message "${OPENSSL_COMMAND} certificate element ${el_number} will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}"
                return 1
            fi

        fi
        if [ -n "${NOT_VALID_LONGER_THAN}" ] ; then
            debuglog "checking if the certificate is valid longer than ${NOT_VALID_LONGER_THAN} days"
            debuglog "  valid for ${DAYS_VALID} days"
            if [ "${DAYS_VALID}" -gt "${NOT_VALID_LONGER_THAN}" ] ; then
                debuglog "Certificate expires in ${DAYS_VALID} days which is more than ${NOT_VALID_LONGER_THAN} days"
                prepend_critical_message "Certificate expires in ${DAYS_VALID} days which is more than ${NOT_VALID_LONGER_THAN} days"
                return 2
            fi
        fi
    elif [ "${OPENSSL_COMMAND}" = "crl" ]; then
        # CRL certificates

        # We always check expired certificates
        if [ "${ELEM_DAYS_VALID}" -lt 1 ] ; then
            prepend_critical_message "${OPENSSL_COMMAND} certificate element ${el_number} is expired (was valid until ${ELEM_END_DATE})"
            return 2
        fi

        if [ -n "${CRITICAL_DAYS}" ] ; then
            if [ "${ELEM_DAYS_VALID}" -lt "${CRITICAL_DAYS}" ] ; then
                prepend_critical_message "${OPENSSL_COMMAND} certificate element ${el_number} will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}"
                return 2
            fi

        fi

        if [ -n "${WARNING_DAYS}" ] ; then
            if [ "${ELEM_DAYS_VALID}" -lt "${WARNING_DAYS}" ] ; then
                append_warning_message "${OPENSSL_COMMAND} certificate element ${el_number} will expire in ${ELEM_DAYS_VALID} day(s) on ${ELEM_END_DATE}"
                return 1
            fi

        fi
    fi
}


################################################################################
# Converts SSL Labs grades to a numeric value
#   (see https://www.ssllabs.com/downloads/SSL_Server_Rating_Guide.pdf)
# Params
#   $1 program name
# Sets NUMERIC_SSL_LAB_GRADE
convert_ssl_lab_grade() {

    GRADE="$1"

    unset NUMERIC_SSL_LAB_GRADE

    case "${GRADE}" in
        'A+'|'a+')
            # Value not in documentation
            NUMERIC_SSL_LAB_GRADE=85
            shift
            ;;
        A|a)
            NUMERIC_SSL_LAB_GRADE=80
            shift
            ;;
        'A-'|'a-')
            # Value not in documentation
            NUMERIC_SSL_LAB_GRADE=75
            shift
            ;;
        B|b)
            NUMERIC_SSL_LAB_GRADE=65
            shift
            ;;
        C|c)
            NUMERIC_SSL_LAB_GRADE=50
            shift
            ;;
        D|d)
            NUMERIC_SSL_LAB_GRADE=35
            shift
            ;;
        E|e)
            NUMERIC_SSL_LAB_GRADE=20
            shift
            ;;
        F|f)
            NUMERIC_SSL_LAB_GRADE=0
            shift
            ;;
        T|t)
            # No trust: value not in documentation
            NUMERIC_SSL_LAB_GRADE=0
            shift
            ;;
        M|m)
            # Certificate name mismatch: value not in documentation
            NUMERIC_SSL_LAB_GRADE=0
            shift
            ;;
        *)
            unknown "Cannot convert SSL Lab grade ${GRADE}"
            ;;
    esac

}

################################################################################
# Tries to fetch the certificate

fetch_certificate() {

    RET=0

    # IPv6 addresses need brackets in a URI
    if [ "${HOST}" != "${HOST#*[0-9].[0-9]}" ]; then
       debuglog "${HOST} is an IPv4 address"
    elif [ "${HOST}" != "${HOST#*:[0-9a-fA-F]}" ]; then
       debuglog "${HOST} is an IPv6 address"
       if [ -z "${HOST##*\[*}" ] ; then
           debuglog "${HOST} is already specified with brackets"
       else
           debuglog "adding brackets to ${HOST}"
           HOST="[${HOST}]"
       fi
    else
        debuglog "${HOST} is not an IP address"
    fi

    if [ -n "${REQUIRE_OCSP_STAPLING}" ] ; then
        STATUS='-status'
    fi

    if [ -n "${DEBUG}" ] ; then
        IGN_EOF='-ign_eof'
    fi

    # Check if a protocol was specified (if not HTTP switch to TLS)
    if [ -n "${PROTOCOL}" ] && [ "${PROTOCOL}" != 'http' ] && [ "${PROTOCOL}" != 'https' ] && [ "${PROTOCOL}" != 'h2' ] ; then

        case "${PROTOCOL}" in
            pop3|ftp)
                exec_with_timeout "${TIMEOUT}" "printf 'QUIT\\n' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf ${IGN_EOF} -starttls ${PROTOCOL} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            pop3s|ftps)
                exec_with_timeout "${TIMEOUT}" "printf 'QUIT\\n' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf ${IGN_EOF} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            smtp)
                exec_with_timeout "${TIMEOUT}" "printf 'QUIT\\n' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf ${IGN_EOF} -starttls ${PROTOCOL} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} ${S_CLIENT_NAME} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            smtps)
                exec_with_timeout "${TIMEOUT}" "printf 'QUIT\\n' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf ${IGN_EOF} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE}  ${S_CLIENT_NAME} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            irc|ldap)
                exec_with_timeout "${TIMEOUT}" "echo | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            ircs|ldaps)
                exec_with_timeout "${TIMEOUT}" "echo | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            imap)
                exec_with_timeout "${TIMEOUT}" "printf 'A01 LOGOUT\\n' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf ${IGN_EOF} -starttls ${PROTOCOL} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            imaps)
                exec_with_timeout "${TIMEOUT}" "printf 'A01 LOGOUT\\n' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf ${IGN_EOF} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            postgres)
                exec_with_timeout "${TIMEOUT}" "printf 'X\0\0\0\4' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            sieve)
                exec_with_timeout "${TIMEOUT}" "echo 'LOGOUT' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            xmpp|xmpp-server)
                exec_with_timeout "${TIMEOUT}" "echo 'Q' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -connect ${HOST}:${XMPPPORT} ${XMPPHOST} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
	    mysql)
                exec_with_timeout "${TIMEOUT}" "echo | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            *)
                unknown "Error: unsupported protocol ${PROTOCOL}"
                ;;
        esac

    elif [ -n "${FILE}" ] ; then

        if [ "${HOST}" = "localhost" ] ; then
            exec_with_timeout "${TIMEOUT}" "/bin/cat '${FILE}' 2> ${ERROR} 1> ${CERT}"
            RET=$?
        else
            unknown "Error: option 'file' works with -H localhost only"
        fi

    else

          if [ "${PROTOCOL}" = 'h2' ] ; then
              ALPN='-alpn h2'
          fi

        exec_with_timeout "${TIMEOUT}" "printf '${HTTP_REQUEST}' | ${OPENSSL} s_client ${INETPROTO} ${CLIENT} ${CLIENTPASS} -crlf ${IGN_EOF} ${ALPN} -connect ${HOST}:${PORT} ${SERVERNAME} ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT} -showcerts -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} ${STATUS} ${DANE} 2> ${ERROR} 1> ${CERT}"
        RET=$?

    fi

    if [ -n "${DEBUG}" ] ; then
        debuglog "storing a copy of the retrieved certificate in ${HOST}.crt"
        cp "${CERT}" "${HOST}.crt"

        debuglog "Return value of the command = ${RET}"

        debuglog "storing a copy of the retrieved certificate in ${TMPDIR}/${HOST}-${PORT}.crt"
        cp "${CERT}" "${TMPDIR}/${HOST}-${PORT}.crt"

        debuglog "storing a copy of the OpenSSL errors in ${TMPDIR}/${HOST}-${PORT}.error"
        cp "${ERROR}" "${TMPDIR}/${HOST}-${PORT}.error"

    fi

    if [ "${RET}" -ne 0 ] ; then

        debuglog "$(sed 's/^/SSL error: /' "${ERROR}")"

        # s_client could verify the server certificate because the server requires a client certificate
        if ascii_grep '^Acceptable client certificate CA names' "${CERT}" ; then

            verboselog "The server requires a client certificate"

        elif ascii_grep 'nodename\ nor\ servname\ provided,\ or\ not\ known' "${ERROR}" ; then

            ERROR="${HOST} is invalid"
            prepend_critical_message "${ERROR}"
            critical "${SHORTNAME} CRITICAL: ${ERROR}"


        elif ascii_grep 'Connection\ refused' "${ERROR}" ; then

            ERROR='Connection refused'
            prepend_critical_message "${ERROR}"
            critical "${SHORTNAME} CRITICAL: ${ERROR}"

	elif ascii_grep 'dh\ key\ too\ small' "${ERROR}" ; then

	    prepend_critical_message 'DH with a key too small'

	elif ascii_grep 'alert\ handshake\ failure' "${ERROR}" ; then

	    prepend_critical_message 'Handshake failure'

        else

            # Try to clean up the error message
            #     Remove the 'verify and depth' lines
            #     Take the 1st line (seems OK with the use cases I tested)
            ERROR_MESSAGE=$(
                grep -v '^depth' "${ERROR}" \
                    | grep -v '^verify' \
                    | head -n 1
                 )
            prepend_critical_message "SSL error: ${ERROR_MESSAGE}"

        fi

    else

        if ascii_grep usage "${ERROR}" && [ "${PROTOCOL}" = "ldap" ] ; then
            unknown "it seems that OpenSSL -starttls does not support yet LDAP"
        fi

    fi

}

################################################################################
# Adds metric to performance data
# Params
#   $1 performance data in nagios plugin format,
#      see https://nagios-plugins.org/doc/guidelines.html#AEN200
add_performance_data() {
    if [ -z "${PERFORMANCE_DATA}" ]; then
        PERFORMANCE_DATA="|${1}"
    else
        PERFORMANCE_DATA="${PERFORMANCE_DATA} $1"
    fi
}

################################################################################
# Prepares sed-style command for variable replacement
# Params
#   $1 variable name (e.g. SHORTNAME)
#   $2 variable value (e.g. SSL_CERT)
var_for_sed() {
    echo "s|%$1%|$( echo "$2" | sed -e 's#|#\\\\|#g' )|g"
}

################################################################################
# Performs a grep removing the NULL characters first
#
# As the POSIX grep does not have the -a option, we remove the NULL characters
# first to avoid the error Binary file matches
#
# Params
#  $1 pattern
#  $2 file
#
ascii_grep() {
    tr -d '\000' < "$2" | grep -q "$1"
}

################################################################################
# Checks if there is an option argument (should not begin with -)
#
# Params
#  $1 name of the option (e.g., '-w,--waring') to be used in the error message
#  $2 next command line parameter
check_option_argument() {

    if [ -z "$2" ] || [ "${2%${2#?}}"x = '-x' ] ; then
        unknown "'${1}' requires an argument"
    fi

}

################################################################################
# Main
################################################################################
main() {

    # Default values
    DEBUG=""
    OPENSSL=""
    FILE_BIN=""
    CURL_BIN=""
    CURL_PROXY=""
    CURL_USER_AGENT=""
    CUSTOM_HTTP_HEADER=""
    DIG_BIN=""
    NMAP_BIN=""
    IGNORE_SSL_LABS_CACHE=""
    PORT=""
    XMPPPORT="5222"
    XMPPHOST=""
    SNI=""
    TIMEOUT="120"
    VERBOSE=""
    FORCE_PERL_DATE=""
    REQUIRE_SAN=""
    REQUIRE_OCSP_STAPLING=""
    OCSP="1" # enabled by default
    OCSP_IGNORE_TIMEOUT=""
    FORMAT=""
    HTTP_METHOD="HEAD"
    RSA=""
    ECDSA=""
    DANE=""
    DISALLOWED_PROTOCOLS=""
    WARNING_DAYS=20
    CRITICAL_DAYS=15
    ELEMENT=0
    SKIP_ELEMENT=0
    NO_PROXY=""
    PROXY=""
    CRL=""

    # after 2020-09-01 we could set the default to 398 days because of Apple
    # https://support.apple.com/en-us/HT211025
    NOT_VALID_LONGER_THAN=""
    FIRST_ELEMENT_ONLY=""

    # Set the default temp dir if not set
    if [ -z "${TMPDIR}" ] ; then
        TMPDIR="/tmp"
    fi

    ################################################################################
    # Process command line options
    #
    # We do not use getopts since it is unable to process long options and it is
    # Bash specific.

    COMMAND_LINE_ARGUMENTS=$*

    while true; do

        case "$1" in
            ########################################
            # Options without arguments
            -A|--noauth)
                NOAUTH=1
                shift
                ;;
            --altnames)
                ALTNAMES=1
                shift
                ;;
	    --crl)
		CRL=1
		shift
		;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            -h|--help|-\?)
                usage
                ;;
            --first-element-only)
                FIRST_ELEMENT_ONLY=1
                shift
                ;;
            --force-perl-date)
                FORCE_PERL_DATE=1
                shift
                ;;
            --http-use-get)
                HTTP_METHOD="GET"
                shift
                ;;
            --ignore-exp)
                NOEXP=1
                shift
                ;;
            --ignore-sig-alg)
                NOSIGALG=1
                shift
                ;;
            --ignore-ssl-labs-cache)
                IGNORE_SSL_LABS_CACHE="&startNew=on"
                shift
                ;;
	    --no-proxy)
		NO_PROXY=1
		shift
		;;
            --no-ssl2|--no_ssl2) # we keep the old variant for compatibility
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_ssl2"
                shift
                ;;
            --no-ssl3|--no_ssl3) # we keep the old variant for compatibility
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_ssl3"
                shift
                ;;
            --no-tls1|--no_tls1) # we keep the old variant for compatibility
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1"
                shift
                ;;
            --no-tls1_1|--no_tls1_1) # we keep the old variant for compatibility
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1_1"
                shift
                ;;
            --no-tls1_2|--no_tls1_2) # we keep the old variant for compatibility
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1_2"
                shift
                ;;
            --no-tls1_3|--no_tls1_3) # we keep the old variant for compatibility
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1_3"
                shift
                ;;
            -N|--host-cn)
                COMMON_NAME="__HOST__"
                shift
                ;;
            -s|--selfsigned)
                SELFSIGNED=1
                shift
                ;;
            --rsa)
                RSA=1
                shift
                ;;
            --require-no-ssl2)
                DISALLOWED_PROTOCOLS="${DISALLOWED_PROTOCOLS} SSLv2"
                shift
                ;;
            --require-no-ssl3)
                DISALLOWED_PROTOCOLS="${DISALLOWED_PROTOCOLS} SSLv3"
                shift
                ;;
            --require-no-tls1)
                DISALLOWED_PROTOCOLS="${DISALLOWED_PROTOCOLS} TLSv1.0"
                shift
                ;;
            --require-no-tls1_1)
                DISALLOWED_PROTOCOLS="${DISALLOWED_PROTOCOLS} TLSv1.1"
                shift
                ;;
            --require-ocsp-stapling)
                REQUIRE_OCSP_STAPLING=1
                shift
                ;;
            --require-san)
                REQUIRE_SAN=1
                shift
                ;;
            --ecdsa)
                ECDSA=1
                shift
                ;;
            --ssl2)
                SSL_VERSION="-ssl2"
                shift
                ;;
            --ssl3)
                SSL_VERSION="-ssl3"
                shift
                ;;
            --tls1)
                SSL_VERSION="-tls1"
                shift
                ;;
            --tls1_1)
                SSL_VERSION="-tls1_1"
                shift
                ;;
            --tls1_2)
                SSL_VERSION="-tls1_2"
                shift
                ;;
            --tls1_3)
                SSL_VERSION="-tls1_3"
                shift
                ;;
            --ocsp)
                # deprecated
                shift
                ;;
            --ignore-ocsp)
                OCSP=""
                shift
                ;;
            --ignore-ocsp-timeout)
                OCSP_IGNORE_TIMEOUT=1
                shift
                ;;
            --terse)
                TERSE=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -V|--version)
                echo "check_ssl_cert version ${VERSION}"
                exit "${STATUS_UNKNOWN}"
                ;;
            -4)
                INETPROTO="-4"
                shift
                ;;
            -6)
                INETPROTO="-6"
                shift
                ;;


            ########################################
            # Options with one argument

            -c|--critical)
                check_option_argument '-c,--critical' "$2"
                CRITICAL_DAYS="$2"
                shift 2
                ;;
            --curl-bin)
                check_option_argument '--curl-bin' "$2"
                CURL_BIN="$2"
                shift 2
                ;;
            --curl-user-agent)
                check_option_argument '--curl-user-agent' "$2"
                CURL_USER_AGENT="$2"
                shift 2
                ;;
            --custom-http-header)
                check_option_argument '--custom-http-header' "$2"
                CUSTOM_HTTP_HEADER="$2"
                shift 2
                ;;
            # Deprecated option: used to be as --warning
            --days)
                check_option_argument '--days' "$2"
                WARNING_DAYS="$2"
                shift 2
                ;;
            --dig-bin)
                check_option_argument '--dig-bin' "$2"
                DIG_BIN="$2"
                shift 2
                ;;
            --nmap-bin)
                check_option_argument '--nmap-bin' "$2"
                NMAP_BIN="$2"
                ;;
            -e|--email)
                check_option_argument 'e|--email' "$2"
                ADDR="$2"
                shift 2
                ;;
            -f|--file)
                check_option_argument ' -f|--file' "$2"
                FILE="$2"
                shift 2
                ;;
            --file-bin)
                check_option_argument '--file-bin' "$2"
                FILE_BIN="$2"
                shift 2
                ;;
             --format)
                check_option_argument '--format' "$2"
                FORMAT="$2"
                shift 2
                ;;
            -H|--host)
                check_option_argument '-H|--host' "$2"
                HOST="$2"
                shift 2
                ;;
            -i|--issuer)
                check_option_argument '-i|--issuer' "$2"
                ISSUER="$2"
                shift 2
                ;;
            --issuer-cert-cache)
                check_option_argument '--issuer-cert-cache' "$2"
                ISSUER_CERT_CACHE="$2"
                shift 2
                ;;
            -L|--check-ssl-labs)
                check_option_argument '-L|--check-ssl-labs' "$2"
                SSL_LAB_CRIT_ASSESSMENT="$2"
                shift 2
                ;;
            --check-ssl-labs-warn)
                check_option_argument '--check-ssl-labs-warn' "$2"
                SSL_LAB_WARN_ASSESTMENT="$2"
                shift 2
                ;;
            --serial)
                check_option_argument '--serial' "$2"
                SERIAL_LOCK="$2"
                shift 2
                ;;
            --element)
                check_option_argument '--element' "$2"
                ELEMENT="$2"
                shift 2
                ;;
            --skip-element)
                check_option_argument '--skip-element' "$2"
                SKIP_ELEMENT="$2"
                shift 2
                ;;
            --fingerprint)
                check_option_argument '--fingerprint' "$2"
                FINGERPRINT_LOCK="$2"
                shift 2
                ;;
            --long-output)
                check_option_argument '--long-output' "$2"
                LONG_OUTPUT_ATTR="$2"
                shift 2
                ;;
            -n|--cn)
                check_option_argument ' -n|--cn' "$2"
                if [ -n "${COMMON_NAME}" ]; then
                    COMMON_NAME="${COMMON_NAME} ${2}"
                else
                    COMMON_NAME="${2}"
                fi
                shift 2
                ;;
            --not-issued-by)
                check_option_argument '--not-issued-by' "$2"
                NOT_ISSUED_BY="$2"
                shift 2
                ;;
            --not-valid-longer-than)
                check_option_argument '--not-valid-longer-than' "$2"
                NOT_VALID_LONGER_THAN=$2
                shift 2
                ;;
            --ocsp-critical)
                check_option_argument '--ocsp-critical' "$2"
                OCSP_CRITICAL="$2"
                shift 2
                ;;
            --ocsp-warning)
                check_option_argument '--ocsp-warning' "$2"
                OCSP_WARNING="$2"
                shift 2
                ;;
            -o|--org)
                check_option_argument '-o|--org' "$2"
                ORGANIZATION="$2"
                shift 2
                ;;
            --openssl)
                check_option_argument '--openssl' "$2"
                OPENSSL="$2"
                shift 2
                ;;
            -p|--port)
                check_option_argument '-p|--port' "$2"
                PORT="$2"
                XMPPPORT="$2"
                shift 2
                ;;
            -P|--protocol)
                check_option_argument '-P|--protocol' "$2"
                PROTOCOL="$2"
                shift 2
                ;;
            --proxy)
                check_option_argument '--proxy' "$2"
		PROXY="$2"
                export http_proxy="$2"
                shift 2
                ;;
            -r|--rootcert)
                check_option_argument '-r|--rootcert' "$2"
                ROOT_CA="$2"
                shift 2
                ;;
            --rootcert-dir)
                check_option_argument '--rootcert-dir' "$2"
                ROOT_CA_DIR="$2"
                shift 2
                ;;
            --rootcert-file)
                check_option_argument '--rootcert-file' "$2"
                ROOT_CA_FILE="$2"
                shift 2
                ;;
            -C|--clientcert)
                check_option_argument '-C|--clientcert' "$2"
                CLIENT_CERT="$2"
                shift 2
                ;;
            -K|--clientkey)
                check_option_argument '-K|--clientkey' "$2"
                CLIENT_KEY="$2"
                shift 2
                ;;
            --clientpass)
                if [ $# -gt 1 ]; then
                    CLIENT_PASS="$2"
                    shift 2
                else
                    unknown "--clientpass requires an argument"
                fi
                ;;
            --sni)
                check_option_argument '--sni' "$2"
                SNI="$2"
                shift 2
                ;;
            -S|--ssl)
                check_option_argument '' "$2"
                if [ "$2" = "2" ] || [ "$2" = "3" ] ; then
                    SSL_VERSION="-ssl${2}"
                    shift 2
                else
                    unknown "invalid argument for --ssl"
                fi
                ;;
            -t|--timeout)
                check_option_argument '-t|--timeout' "$2"
                TIMEOUT="$2"
                shift 2
                ;;
            --temp)
                check_option_argument '--temp' "$2"
                TMPDIR="$2"
                shift 2
                ;;
            -w|--warning)
                check_option_argument '-w|--warning' "$2"
                WARNING_DAYS="$2"
                shift 2
                ;;
            --xmpphost)
                check_option_argument '--xmpphost' "$2"
                XMPPHOST="$2"
                shift 2
                ;;

            ##############################
            # Variable number of arguments
            --dane)

                if [ -n "${DANE}" ]; then
                    unknown "--dane can be specified only once"
                fi

                # check the second parameter if it exist
                if [ $# -gt 1 ] ; then

                    if [ "${2%${2#?}}"x = '-x' ] ; then
                        DANE=1
                        shift
                    else
                        DANE=$2
                        shift 2
                    fi

                else

                        DANE=1
                        shift

                fi

                ;;
            ########################################
            # Special
            --)
                shift
                break
                ;;
            -*)
                unknown "invalid option: ${1}"
                ;;
            *)
                if [ -n "$1" ] ; then
                    unknown "invalid option: ${1}"
                fi
                break
                ;;
        esac

    done

    ################################################################################
    # Default ports
    if [ -z "${PORT}" ]; then

        if [ -z "${PROTOCOL}" ]; then

            # default is HTTPS
            PORT='443'

        else

            case "${PROTOCOL}" in
            smtp)
                PORT=25
                ;;
            smtps)
                PORT=465
                ;;
            pop3)
                PORT=110
                ;;
            ftp|ftps)
                PORT=21
                ;;
            pop3s)
                PORT=995
                ;;
            irc|ircs)
                PORT=6667
                ;;
            ldap)
                PORT=389
                ;;
            ldaps)
                PORT=636
                ;;
            imap)
                PORT=143
                ;;
            imaps)
                PORT=993
                ;;
            postgres)
                PORT=5432
                ;;
            sieve)
                PORT=4190
                ;;
            http)
                PORT=80
                ;;
            https|h2)
                PORT=443
                ;;
	    mysql)
		PORT=3306
		;;
            *)
                unknown "Error: unsupported protocol ${PROTOCOL}"
                ;;
            esac


        fi
    fi

    debuglog "Command line arguments: ${COMMAND_LINE_ARGUMENTS}"

    ################################################################################
    # Set COMMON_NAME to hostname if -N was given as argument.
    # COMMON_NAME may be a space separated list of hostnames.
    case ${COMMON_NAME} in
        *__HOST__*) COMMON_NAME=$(echo "${COMMON_NAME}" | sed "s/__HOST__/${HOST}/") ;;
        *) ;;
    esac

    ################################################################################
    # Sanity checks

    ###############
    # Check options
    if [ -z "${HOST}" ] ; then
        usage "No host specified"
    fi

    if [ -n "${ALTNAMES}" ] && [ -z "${COMMON_NAME}" ] ; then
        unknown "--altnames requires a common name to match (--cn or --host-cn)"
    fi

    if [ -n "${ROOT_CA}" ] ; then

        if [ ! -r "${ROOT_CA}" ] ; then
            unknown "Cannot read root certificate ${ROOT_CA}"
        fi

        if [ -d "${ROOT_CA}" ] ; then
            ROOT_CA="-CApath ${ROOT_CA}"
        elif [ -f "${ROOT_CA}" ] ; then
            ROOT_CA="-CAfile ${ROOT_CA}"
        else
            unknown "Root certificate of unknown type $(file "${ROOT_CA}" 2> /dev/null)"
        fi

    fi

    if [ -n "${ROOT_CA_DIR}" ] ; then

        if [ ! -d "${ROOT_CA_DIR}" ] ; then
            unknown "${ROOT_CA_DIR} is not a directory";
        fi

        if [ ! -r "${ROOT_CA_DIR}" ] ; then
            unknown "Cannot read root directory ${ROOT_CA_DIR}"
        fi

        ROOT_CA_DIR="-CApath ${ROOT_CA_DIR}"
    fi

    if [ -n "${ROOT_CA_FILE}" ] ; then

        if [ ! -r "${ROOT_CA_FILE}" ] ; then
            unknown "Cannot read root certificate ${ROOT_CA_FILE}"
        fi

    fi

    if [ -n "${ROOT_CA_DIR}" ] || [ -n "${ROOT_CA_FILE}" ]; then
	if [ -n "${ROOT_CA_FILE}" ] ; then
            ROOT_CA="${ROOT_CA_DIR} -CAfile ${ROOT_CA_FILE}"
	else
            ROOT_CA="${ROOT_CA_DIR}"
	fi
    fi

    if [ -n "${CLIENT_CERT}" ] ; then

        if [ ! -r "${CLIENT_CERT}" ] ; then
            unknown "Cannot read client certificate ${CLIENT_CERT}"
        fi

    fi

    if [ -n "${CLIENT_KEY}" ] ; then

        if [ ! -r "${CLIENT_KEY}" ] ; then
            unknown "Cannot read client certificate key ${CLIENT_KEY}"
        fi

    fi

    if [ -n "${FILE}" ] ; then
	if [ ! -r "${FILE}" ] ; then
	    unknown "Cannot read file ${FILE}"
	fi
    fi
    
    if [ -n "${CRITICAL_DAYS}" ] ; then

        debuglog "-c specified: ${CRITICAL_DAYS}"

        if ! echo "${CRITICAL_DAYS}" | grep -q '^[0-9][0-9]*$' ; then
            unknown "invalid number of days ${CRITICAL_DAYS}"
        fi

    fi

    if [ -n "${WARNING_DAYS}" ] ; then

        if ! echo "${WARNING_DAYS}" | grep -q '^[0-9][0-9]*$' ; then
            unknown "invalid number of days ${WARNING_DAYS}"
        fi

    fi

    if [ -n "${CRITICAL_DAYS}" ] && [ -n "${WARNING_DAYS}" ] ; then

        if [ "${WARNING_DAYS}" -le "${CRITICAL_DAYS}" ] ; then
            unknown "--warning (${WARNING_DAYS}) is less than or equal to --critical (${CRITICAL_DAYS})"
        fi

    fi

    if [ -n "${NOT_VALID_LONGER_THAN}" ] ; then

        debuglog "--not-valid-longer-than specified: ${NOT_VALID_LONGER_THAN}"

        if ! echo "${NOT_VALID_LONGER_THAN}" | grep -q '^[0-9][0-9]*$' ; then
            unknown "invalid number of days ${NOT_VALID_LONGER_THAN}"
        fi

    fi

    if [ -n "${CRL}" ] && [ -z "${ROOT_CA_FILE}" ] ; then
	
	unknown "To be able to check CRL we need the Root Cert. Please specify it with the --rootcert-file option"

    fi

    if [ -n "${TMPDIR}" ] ; then

        if [ ! -d "${TMPDIR}" ] ; then
            unknown "${TMPDIR} is not a directory";
        fi

        if [ ! -w "${TMPDIR}" ] ; then
            unknown "${TMPDIR} is not writable";
        fi

    fi

    if [ -n "${OPENSSL}" ] ; then

        if [ ! -x "${OPENSSL}" ] ; then
            unknown "${OPENSSL} is not an executable"
        fi

    fi

    if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ] ; then
        convert_ssl_lab_grade "${SSL_LAB_CRIT_ASSESSMENT}"
        SSL_LAB_CRIT_ASSESSMENT_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"
    fi

    if [ -n "${SSL_LAB_WARN_ASSESTMENT}" ] ; then
        convert_ssl_lab_grade "${SSL_LAB_WARN_ASSESTMENT}"
        SSL_LAB_WARN_ASSESTMENT_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"
        if [ "${SSL_LAB_WARN_ASSESTMENT_NUMERIC}" -lt "${SSL_LAB_CRIT_ASSESSMENT_NUMERIC}" ]; then
            unknown  '--check-ssl-labs-warn must be greater than -L|--check-ssl-labs'
        fi
    fi

    debuglog "ROOT_CA = ${ROOT_CA}"

    # Signature algorithms
    if [ -n "${RSA}" ] && [ -n "${ECDSA}" ] ; then
        unknown 'both --rsa and --ecdsa specified: cannot force both ciphers at the same time'
    fi
    if [ -n "${ECDSA}" ] ; then
        # see https://github.com/matteocorti/check_ssl_cert/issues/164#issuecomment-540623344
        SSL_AU="-sigalgs 'ECDSA+SHA1:ECDSA+SHA224:ECDSA+SHA384:ECDSA+SHA256:ECDSA+SHA512'"
    fi
    if [ -n "${RSA}" ] ; then
        if echo "${SSL_VERSION_DISABLED}" | grep -q -- '-no_tls1_3' ||
            [ "${SSL_VERSION}" = '-tls1' ] ||
            [ "${SSL_VERSION}" = '-tls1_1' ] ||
            [ "${SSL_VERSION}" = '-tls1_2' ] ; then
                # see https://github.com/matteocorti/check_ssl_cert/issues/164#issuecomment-540623344
                # see https://github.com/matteocorti/check_ssl_cert/issues/167
                 SSL_AU="-sigalgs 'RSA+SHA512:RSA+SHA256:RSA+SHA384:RSA+SHA224:RSA+SHA1'"
        else
            # see https://github.com/matteocorti/check_ssl_cert/issues/164#issuecomment-540623344
              SSL_AU="-sigalgs 'RSA-PSS+SHA512:RSA-PSS+SHA384:RSA-PSS+SHA256:RSA+SHA512:RSA+SHA256:RSA+SHA384:RSA+SHA224:RSA+SHA1'"
        fi
    fi

    #######################
    # Check needed programs

    # OpenSSL
    if [ -z "${OPENSSL}" ] ; then
       OPENSSL='openssl'
    fi
    check_required_prog "${OPENSSL}"
    OPENSSL=${PROG}

    # file
    if [ -z "${FILE_BIN}" ] ; then
        FILE_BIN='file'
    fi
    check_required_prog "${FILE_BIN}"
    FILE_BIN=${PROG}

    debuglog "file version: $( "${FILE_BIN}" --version 2>&1 )"

    # cURL
    if [ -z "${CURL_BIN}" ] ; then
        if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ] || [ -n "${OCSP}" ] || [ -n "${CRL}" ] ; then
            if [ -n "${DEBUG}" ] ; then
                debuglog "cURL binary needed. SSL Labs = ${SSL_LAB_CRIT_ASSESSMENT}, OCSP = ${OCSP}, CURL = ${CRL}"
                debuglog "cURL binary not specified"
            fi

            check_required_prog curl
            CURL_BIN=${PROG}

            debuglog "cURL available: ${CURL_BIN}"
	    debuglog "$( ${CURL_BIN} --version )"

        else
            debuglog "cURL binary not needed. SSL Labs = ${SSL_LAB_CRIT_ASSESSMENT}, OCSP = ${OCSP}"
        fi
    else
        # we check if the provided binary actually works
        check_required_prog "${CURL_BIN}"
    fi

    # nmap
    if [ -z "${NMAP_BIN}" ] ; then
        if [ -n "${DISALLOWED_PROTOCOLS}" ] ; then
            debuglog "nmap binary needed. DISALLOWED_PROTOCOLS = ${DISALLOWED_PROTOCOLS}"
            debuglog "nmap binary not specified"

            check_required_prog nmap
            NMAP_BIN=${PROG}

            debuglog "nmap available: ${NMAP_BIN}"
        else
            debuglog "nmap binary not needed. No disallowed protocols"
        fi
    else
        # we check if the provided binary actually works
        check_required_prog "${NMAP_BIN}"
    fi

    # Expect (optional)
    EXPECT="$(command -v expect 2> /dev/null)"
    test -x "${EXPECT}" || EXPECT=""
    if [ -z "${EXPECT}" ] ; then
        verboselog "expect not available"
    else
        verboselog "expect available (${EXPECT})"
    fi

    # Timeout (optional)
    TIMEOUT_BIN="$(command -v timeout 2> /dev/null)"
    test -x "${TIMEOUT_BIN}" || TIMEOUT_BIN=""
    if [ -z "${TIMEOUT_BIN}" ] ; then
        verboselog "timeout not available"
    else
        verboselog "timeout available (${TIMEOUT_BIN})"
    fi

    if [ -z "${TIMEOUT_BIN}" ] && [ -z "${EXPECT}" ] ; then
        verboselog "disabling timeouts"
    fi

    PERL="$(command -v perl 2> /dev/null)"

    if [ -n "${PERL}" ] ; then
        debuglog "perl available: ${PERL}"
    fi

    DATEBIN="$(command -v date 2> /dev/null)"

    if [ -n "${DATEBIN}" ] ; then
        debuglog "date available: ${DATEBIN}"
    fi

    DATETYPE=""

    if ! "${DATEBIN}" +%s >/dev/null 2>&1  ;  then

        # Perl with Date::Parse (optional)
        test -x "${PERL}" || PERL=""
        if [ -z "${PERL}" ] ; then
            verboselog "Perl not found: disabling date computations"
        fi

        if ! ${PERL} -e "use Date::Parse;" > /dev/null 2>&1 ; then

            verboselog "Perl module Date::Parse not installed: disabling date computations"

            PERL=""

        else

            verboselog "Perl module Date::Parse installed: enabling date computations"

            DATETYPE="PERL"

        fi

    else

        if "${DATEBIN}" --version >/dev/null 2>&1 ; then
            DATETYPE="GNU"
        else
            DATETYPE="BSD"
        fi

        verboselog "found ${DATETYPE} date with timestamp support: enabling date computations"

    fi

    if [ -n "${FORCE_PERL_DATE}" ] ; then
        DATETYPE="PERL"
    fi

    if [ -n "${DEBUG}" ] ; then
        debuglog "check_ssl_cert version: ${VERSION}"
        debuglog "OpenSSL binary: ${OPENSSL}"
        debuglog "OpenSSL version: $( ${OPENSSL} version )"

        OPENSSL_DIR="$( ${OPENSSL} version -d | sed -E 's/OPENSSLDIR: "([^"]*)"/\1/' )"

        debuglog "OpenSSL configuration directory: ${OPENSSL_DIR}"

        DEFAULT_CA=0
        if [ -f "${OPENSSL_DIR}"/cert.pem ] ; then
            DEFAULT_CA="$( grep -c BEGIN "${OPENSSL_DIR}"/cert.pem )"
        elif [ -f "${OPENSSL_DIR}"/certs ] ; then
            DEFAULT_CA="$( grep -c BEGIN "${OPENSSL_DIR}"/certs )"
        fi
        debuglog "${DEFAULT_CA} root certificates installed by default"

         debuglog " System info: $( uname -a )"
         debuglog "Date computation: ${DATETYPE}"
    fi

    ################################################################################
    # Check if openssl s_client supports the -servername option
    #
    #   openssl s_client now has a -help option, so we can use that.
    #   Some older versions support -servername, but not -help
    #   => We supply an invalid command line option to get the help
    #      on standard error for these intermediate versions.
    #
    SERVERNAME=
    if ${OPENSSL} s_client -help 2>&1 | grep -q -- -servername || ${OPENSSL} s_client not_a_real_option 2>&1 | grep -q -- -servername; then

        if [ -n "${SNI}" ]; then
            SERVERNAME="-servername ${SNI}"
        else
            SERVERNAME="-servername ${HOST}"
        fi

        debuglog "'${OPENSSL} s_client' supports '-servername': using ${SERVERNAME}"

    else

        verboselog "'${OPENSSL} s_client' does not support '-servername': disabling virtual server support"

    fi

    if [ -n "${PROXY}" ] && [ -n "${NO_PROXY}" ] ; then
	unknown "Only one of --proxy or --no_proxy can be specfied"
    fi

    ################################################################################
    # If --no-proxy was specified unset the http_proxy variables
    if [ -n "${NO_PROXY}" ] ; then
	debuglog "Disabling the proxy"
	unset http_proxy
	unset https_proxy
	unset HTTP_PROXY
	unset HTTPS_PROXY
    fi
    
    ################################################################################
    # Check if openssl s_client supports the -proxy option
    #
    SCLIENT_PROXY=
    SCLIENT_PROXY_ARGUMENT=
    CURL_PROXY=
    CURL_PROXY_ARGUMENT=
    if [ -n "${http_proxy}" ] || [ -n "${HTTP_PROXY}" ] ; then

	debuglog "Proxy settings (before):"
	debuglog "  http_proxy  = ${http_proxy}"
	debuglog "  https_proxy = ${https_proxy}"
	debuglog "  HTTP_PROXY  = ${HTTP_PROXY}"
	debuglog "  HTTPS_PROXY = ${HTTPS_PROXY}"

	if [ -n "${http_proxy}" ] ; then
            HTTP_PROXY="${http_proxy}"
        fi

	if [ -z "${https_proxy}" ] ; then
	    # try to set https_proxy
	    https_proxy="${http_proxy}"
	fi

	if [ -z "${HTTPS_PROXY}" ] ; then
	    # try to set HTTPS_proxy
	    HTTPS_PROXY="${HTTP_PROXY}"
	fi

	if ${CURL_BIN} --manual | grep -q -- --proxy ; then
	    debuglog "Adding --proxy ${HTTP_PROXY} to the cURL options"
	    CURL_PROXY="--proxy"
	    CURL_PROXY_ARGUMENT="${HTTP_PROXY}"
	fi
	
	if ${OPENSSL} s_client -help 2>&1 | grep -q -- -proxy || ${OPENSSL} s_client not_a_real_option 2>&1 | grep -q -- -proxy; then
	    SCLIENT_PROXY="-proxy"
	    SCLIENT_PROXY_ARGUMENT="$( echo "${HTTP_PROXY}" | sed 's/.*:\/\///' | sed 's/\/$//' )"

	    debuglog "Adding -proxy ${SCLIENT_PROXY_ARGUMENT} to the s_client options"

	else
	    
            verboselog "'${OPENSSL} s_client' does not support '-proxy': HTTP_PROXY could be ignored"	    

	fi

	debuglog "Proxy settings (after):"
	debuglog "  http_proxy  = ${http_proxy}"
	debuglog "  https_proxy = ${https_proxy}"
	debuglog "  HTTP_PROXY  = ${HTTP_PROXY}"
	debuglog "  HTTPS_PROXY = ${HTTPS_PROXY}"
	debuglog "  s_client    = ${SCLIENT_PROXY} ${SCLIENT_PROXY_ARGUMENT}"
	debuglog "  cURL        = ${CURL_PROXY} ${CURL_PROXY_ARGUMENT}"

    fi    
    
    ################################################################################
    # Check if openssl s_client supports the -name option
    #
    S_CLIENT_NAME=
    if ${OPENSSL} s_client -help 2>&1 | grep -q -- -name || ${OPENSSL} s_client not_a_real_option 2>&1 | grep -q -- -name; then

        CURRENT_HOSTNAME=$( hostname )
        S_CLIENT_NAME="-name ${CURRENT_HOSTNAME}"

        debuglog "'${OPENSSL} s_client' supports '-name': using ${CURRENT_HOSTNAME}"

    else

        verboselog "'${OPENSSL} s_client' does not support '-name'"

    fi

    ################################################################################
    # Check if openssl s_client supports the -xmpphost option
    #
    if ${OPENSSL} s_client -help 2>&1 | grep -q -- -xmpphost ; then
        XMPPHOST="-xmpphost ${XMPPHOST:-${HOST}}"
        debuglog "'${OPENSSL} s_client' supports '-xmpphost': using ${XMPPHOST}"
    else
        if [ -n "${XMPPHOST}" ] ; then
            unknown " s_client' does not support '-xmpphost'"
        fi
        XMPPHOST=
        verboselog "'${OPENSSL} s_client' does not support '-xmpphost': disabling 'to' attribute"
    fi

    ################################################################################
    # check if openssl s_client supports the SSL TLS version
    if [ -n "${SSL_VERSION}" ] ; then
        if ! "${OPENSSL}" s_client -help 2>&1 | grep -q -- "${SSL_VERSION}" ; then
            unknown "OpenSSL does not support the ${SSL_VERSION} version"
        fi
    fi

    ################################################################################
    # --inetproto validation
    if [ -n "${INETPROTO}" ] ; then

        # validate the arguments
        if [ "${INETPROTO}" != "-4" ] && [ "${INETPROTO}" != "-6" ] ; then
            VERSION=$(echo "${INETPROTO}" | awk  '{ string=substr($0, 2); print string; }' )
            unknown "Invalid argument '${VERSION}': the value must be 4 or 6"
        fi

        # Check if openssl s_client supports the -4 or -6 option
        if ! "${OPENSSL}" s_client -help 2>&1 | grep -q -- "${INETPROTO}" ; then
            unknown "OpenSSL does not support the ${INETPROTO} option"
        fi

        # Check if cURL is needed and if it supports the -4 and -6 options
        if [ -z "${CURL_BIN}" ] ; then
            if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ] || [ -n "${OCSP}" ] ; then
                if ! "${CURL_BIN}" --manual | grep -q -- -6 && [ -n "${INETPROTO}" ] ; then
                    unknown "cURL does not support the ${INETPROTO} option"
                fi
            fi
        fi

        # check if IPv6 is available locally
        if [ -n "${INETPROTO}" ] && [ "${INETPROTO}" -eq "-6" ] && ! ifconfig -a | grep -q inet6 ; then
            unknown "cannot connect using IPv6 as no local interface has  IPv6 configured"
        fi

        # nmap does not have a -4 switch
        NMAP_INETPROTO=''
        if [ -n "${INETPROTO}" ] && [ "${INETPROTO}" = '-6' ] ; then
            NMAP_INETPROTO='-6'
        fi


    fi

    ################################################################################
    # Check if s_client supports the no_ssl options
    for S_CLIENT_OPTION in ${SSL_VERSION_DISABLED} ; do
	require_s_client_option "${S_CLIENT_OPTION}"
    done

    ################################################################################
    # define the HTTP request string
    if [ -n "${SNI}" ]; then
        HOST_HEADER="${SNI}"
    else
        HOST_HEADER="${HOST}"
    fi

    # add newline if custom HTTP header is defined
    if [ -n "${CUSTOM_HTTP_HEADER}" ]; then
        CUSTOM_HTTP_HEADER="${CUSTOM_HTTP_HEADER}\\n"
    fi

    HTTP_REQUEST="${HTTP_METHOD} / HTTP/1.1\\nHost: ${HOST_HEADER}\\nUser-Agent: check_ssl_cert/${VERSION}\\n${CUSTOM_HTTP_HEADER}Connection: close\\n\\n"

    ##############################################################################
    # Check for disallowed protocols
    if [ -n "${DISALLOWED_PROTOCOLS}" ] ; then

        # check if the host has an IPv6 address only (as nmap is not able to resolve without the -6 switch
        if ${NMAP_BIN} "${HOST}" 2>&1 | grep -q 'Failed to resolve' ; then
            debuglog 'nmap is not able to resolve the host name. Trying with -6 to force IPv6 for an IPv6-only host'

            NMAP_INETPROTO='-6'
        fi

        debuglog "Executing ${NMAP_BIN} -Pn -p \"${PORT}\" \"${NMAP_INETPROTO}\" --script ssl-enum-ciphers \"${HOST}\" 2>&1 | grep '^|'"

        OFFERED_PROTOCOLS=$( ${NMAP_BIN} -Pn -p "${PORT}" "${NMAP_INETPROTO}" --script ssl-enum-ciphers "${HOST}" 2>&1 | grep '^|' )

        debuglog "offered cyphers and protocols:"
        debuglog "${OFFERED_PROTOCOLS}" | sed 's/^|/[DBG] /'

        for protocol in ${DISALLOWED_PROTOCOLS} ; do
            debuglog "Checking if '${protocol}' is offered"
            if echo "${OFFERED_PROTOCOLS}" | grep -v 'No supported ciphers found' | grep -q "${protocol}" ; then
                debuglog "'${protocol}' is offered"
                prepend_critical_message "${protocol} is offered"
            fi

        done

    fi

    ##############################################################################
    # DANE
    if [ -n "${DANE}" ] ; then
        debuglog 'checking DANE'
        if [ -z "${DIG_BIN}" ] ; then
            DIG_BIN='dig'
        fi
        check_required_prog "${DIG_BIN}"
        DIG_BIN=${PROG}
        # check if OpenSSL supports -dane_tlsa_rrdata
        if ${OPENSSL} s_client -help 2>&1 | grep -q -- -dane_tlsa_rrdata || ${OPENSSL} s_client not_a_real_option 2>&1 | grep -q -- -dane_tlsa_rrdata; then
            DIG_RESULT=$( "${DIG_BIN}" +short TLSA "_${PORT}._tcp.${HOST}" |while read -r L; do echo " -dane_tlsa_rrdata '${L}' "; done )
            debuglog "Checking DANE (${DANE})"
            debuglog "$(printf '%s\n' "${DIG_BIN} +short TLSA _${PORT}._tcp.${HOST} =")"
            debuglog "${DIG_RESULT}"

            case ${DANE} in
            1)
                DANE=$( echo "${DIG_RESULT}" | tr -d '\n')
                ;;
            211)
                DANE=$( echo "${DIG_RESULT}" | grep '2 1 1' | tr -d '\n')
                ;;
            301)
                DANE=$( echo "${DIG_RESULT}" | grep '3 0 1' | tr -d '\n')
                ;;
            311)
                DANE=$( echo "${DIG_RESULT}" | grep '3 1 1' | tr -d '\n')
                ;;
            302)
                DANE=$( echo "${DIG_RESULT}" | grep '3 0 2' | tr -d '\n')
                ;;
            *)
                unknown "Internal error: unknown DANE check type ${DANE}"
            esac
            debuglog "${#DANE} DANE ="
            debuglog "${DANE}"

            if [ ${#DANE} -lt 5 ]; then
                prepend_critical_message "No matching TLSA records found at _${PORT}._tcp.${HOST}"
                critical "${SHORTNAME} CRITICAL: No matching TLSA records found at _${PORT}._tcp.${HOST}"
            fi
            DANE="${DANE} -dane_tlsa_domain ${HOST} "
            debuglog "DBG] DANE = ${DANE}"
        else
            unknown 'OpenSSL s_client does not support DNS-based Authentication of Named Entities'
        fi
    fi
    ################################################################################
    # Fetch the X.509 certificate

    # Temporary storage for the certificate and the errors
    create_temporary_file; CERT=${TEMPFILE}
    create_temporary_file; ERROR=${TEMPFILE}

    create_temporary_file; CRL_TMP_DER=${TEMPFILE}
    create_temporary_file; CRL_TMP_PEM=${TEMPFILE}
    create_temporary_file; CRL_TMP_CHAIN=${TEMPFILE}
    
    if [ -n "${OCSP}" ] ; then

        create_temporary_file; ISSUER_CERT_TMP=${TEMPFILE}
        create_temporary_file; ISSUER_CERT_TMP2=${TEMPFILE}

    fi

    if [ -n "${REQUIRE_OCSP_STAPLING}" ] ; then
        create_temporary_file; OCSP_RESPONSE_TMP=${TEMPFILE}
    fi

    verboselog "downloading certificate to ${TMPDIR}"

    CLIENT=""
    if [ -n "${CLIENT_CERT}" ] ; then
        CLIENT="-cert ${CLIENT_CERT}"
    fi
    if [ -n "${CLIENT_KEY}" ] ; then
        CLIENT="${CLIENT} -key ${CLIENT_KEY}"
    fi

    CLIENTPASS=""
    if [ -n "${CLIENT_PASS}" ] ; then
        CLIENTPASS="-pass pass:${CLIENT_PASS}"
    fi

    # Cleanup before program termination
    # Using named signals to be POSIX compliant
    # shellcheck disable=SC2086
    trap_with_arg cleanup ${SIGNALS}

    fetch_certificate

    if ascii_grep 'sslv3\ alert\ unexpected\ message' "${ERROR}" ; then

        if [ -n "${SERVERNAME}" ] ; then

            # Some OpenSSL versions have problems with the -servername option
            # We try without
            verboselog "'${OPENSSL} s_client' returned an error: trying without '-servername'"

            SERVERNAME=""
            fetch_certificate

        fi

        if ascii_grep 'sslv3\ alert\ unexpected\ message' "${ERROR}" ; then

            prepend_critical_message "cannot fetch certificate: OpenSSL got an unexpected message"

        fi

    fi

    if ascii_grep "BEGIN X509 CRL" "${CERT}" ; then
        # we are dealing with a CRL file
        OPENSSL_COMMAND="crl"
        OPENSSL_PARAMS="-nameopt utf8,oneline,-esc_msb"
        OPENSSL_ENDDATE_OPTION="-nextupdate"
    else
        # look if we are dealing with a regular certificate file (x509)
        if ! ascii_grep "CERTIFICATE" "${CERT}" ; then
            if [ -n "${FILE}" ] ; then

                if [ -r "${FILE}" ] ; then

                    if "${OPENSSL}" crl -in "${CERT}" -inform DER | grep -q "BEGIN X509 CRL" ; then
                        debuglog "File is DER encoded CRL"

                        OPENSSL_COMMAND="crl"
                        OPENSSL_PARAMS="-inform DER -nameopt utf8,oneline,-esc_msb"
                        OPENSSL_ENDDATE_OPTION="-nextupdate"
                    else
                        prepend_critical_message "'${FILE}' is not a valid certificate file"
                    fi

                else

                    prepend_critical_message "'${FILE}' is not readable"

                fi

            else
                # See
                # http://stackoverflow.com/questions/1251999/sed-how-can-i-replace-a-newline-n
                #
                # - create a branch label via :a
                # - the N command appends a newline and and the next line of the input
                #   file to the pattern space
                # - if we are before the last line, branch to the created label $!ba
                #   ($! means not to do it on the last line (as there should be one final newline))
                # - finally the substitution replaces every newline with a space on
                #   the pattern space
                ERROR_MESSAGE="$(sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/; /g' "${ERROR}")"
                verboselog "Error: ${ERROR_MESSAGE}"
                prepend_critical_message "No certificate returned"
                critical "${CRITICAL_MSG}"
            fi
        else
            # parameters for regular x509 certificates
            OPENSSL_COMMAND="x509"
            OPENSSL_PARAMS="-nameopt utf8,oneline,-esc_msb"
            OPENSSL_ENDDATE_OPTION="-enddate"
        fi

    fi

    verboselog "parsing the ${OPENSSL_COMMAND} certificate file"

    ################################################################################
    # Parse the X.509 certificate or crl
    # shellcheck disable=SC2086
    DATE="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" "${OPENSSL_ENDDATE_OPTION}" -noout | sed -e "s/^notAfter=//" -e "s/^nextUpdate=//")"

    if [ "${OPENSSL_COMMAND}" = "crl" ]; then
        CN=""
        SUBJECT=""
        SERIAL=0
        OCSP_URI=""
        VALID_ATTRIBUTES=",lastupdate,nextupdate,issuer,"
        # shellcheck disable=SC2086
        ISSUERS="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -issuer -noout)"
    else
        # we need to remove everything before 'CN = ', to remove an eventual email supplied with / and additional elements (after ', ')
        # shellcheck disable=SC2086
	if ${OPENSSL} x509 -in "${CERT}" -subject -noout ${OPENSSL_PARAMS} | grep -q 'CN' ; then	   
            CN="$(${OPENSSL} x509 -in "${CERT}" -subject -noout ${OPENSSL_PARAMS} |
            sed -e "s/^.*[[:space:]]*CN[[:space:]]=[[:space:]]//"  -e "s/\\/[[:alpha:]][[:alpha:]]*=.*\$//" -e "s/,.*//" )"
	else
	    CN='CN unavailable'
	    if [ -z "${ALTNAMES}" ] ; then
		verboselog "Certificate without common name (CN), enabling altername names"
		ALTNAMES=1		
	    fi
	fi

        # shellcheck disable=SC2086
        SUBJECT="$(${OPENSSL} x509 -in "${CERT}" -subject -noout ${OPENSSL_PARAMS})"

        SERIAL="$(${OPENSSL} x509 -in "${CERT}" -serial -noout  | sed -e "s/^serial=//")"

        FINGERPRINT="$(${OPENSSL} x509 -in "${CERT}" -fingerprint -sha1 -noout  | sed -e "s/^SHA1 Fingerprint=//")"

        # TO DO: we just take the first result: a loop over all the hosts should
        # shellcheck disable=SC2086
        OCSP_URI="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -ocsp_uri -noout | head -n 1)"

        # count the certificates in the chain
        NUM_CERTIFICATES=$(grep -c -- "-BEGIN CERTIFICATE-" "${CERT}")

        # start with first certificate
        debuglog "Skipping ${SKIP_ELEMENT} element of the chain"
        CERT_IN_CHAIN=$(( SKIP_ELEMENT + 1 ))
	
        # shellcheck disable=SC2086
        while [ "${CERT_IN_CHAIN}" -le "${NUM_CERTIFICATES}" ]; do
            if [ -n "${ISSUERS}" ]; then
                ISSUERS="${ISSUERS}\\n"
            fi
            # shellcheck disable=SC2086
            ISSUERS="${ISSUERS}$(sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' "${CERT}" | \
                               awk -v n="${CERT_IN_CHAIN}" '/-BEGIN CERTIFICATE-/{l++} (l==n) {print}' | \
                               ${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -issuer -noout)"

            CERT_IN_CHAIN=$(( CERT_IN_CHAIN + 1 ))
            if ! [ "${ELEMENT}" -eq 0 ] && [ $(( CERT_IN_CHAIN - ELEMENT )) -lt 0 ]; then
                break
            fi
        done
    fi

    debuglog 'ISSUERS = '
    debuglog "${ISSUERS}"    
    
    # Handle properly openssl x509 -issuer -noout output format differences:
    # OpenSSL 1.1.0: issuer=C = XY, ST = Alpha, L = Bravo, O = Charlie, CN = Charlie SSL CA
    # OpenSSL 1.0.2: issuer= /C=XY/ST=Alpha/L=Bravo/O=Charlie/CN=Charlie SSL CA 3
    # shellcheck disable=SC2086
    ISSUERS=$(echo "${ISSUERS}" | sed 's/\\n/\n/g' | sed -E -e "s/^issuer=( \/)?//" | awk  '{gsub(", ","\n")};1' | grep -E "^(O|CN) ?= ?")

    debuglog 'ISSUERS = '
    debuglog "${ISSUERS}"

    # we just consider the first HTTP(S) URI
    # TODO check SC2016
    # shellcheck disable=SC2086,SC2016

    ISSUER_URI="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -text -noout | grep "CA Issuers" | grep -i "http" | head -n 1 | sed -e "s/^.*CA Issuers - URI://" | tr -d '"!|;$(){}<>`&')"

    # Check OCSP stapling
    if [ -n "${REQUIRE_OCSP_STAPLING}" ] ; then

        verboselog "checking OCSP stapling"

        grep -A 17 'OCSP response:' "${CERT}" > "${OCSP_RESPONSE_TMP}"

        debuglog "${OCSP_RESPONSE_TMP}"

        if ! ascii_grep 'Next Update' "${OCSP_RESPONSE_TMP}" ; then
            prepend_critical_message "OCSP stapling not enabled"
        else
            verboselog "  OCSP stapling enabled"
            NEXT_UPDATE=$(grep -o 'Next Update: .*$' "${OCSP_RESPONSE_TMP}" | cut -b14-)



            OCSP_EXPIRES_IN_HOURS=$(hours_until "${NEXT_UPDATE}")
            verboselog "  OCSP stapling expires in ${OCSP_EXPIRES_IN_HOURS} hours"
            if [ -n "${OCSP_CRITICAL}" ] && [ "${OCSP_CRITICAL}" -ge "${OCSP_EXPIRES_IN_HOURS}" ] ; then
                prepend_critical_message "${OPENSSL_COMMAND} OCSP stapling will expire in ${OCSP_EXPIRES_IN_HOURS} hour(s) on ${NEXT_UPDATE}"
            elif [ -n "${OCSP_WARNING}" ] && [ "${OCSP_WARNING}" -ge "${OCSP_EXPIRES_IN_HOURS}" ] ; then
                append_warning_message "${OPENSSL_COMMAND} OCSP stapling will expire in ${OCSP_EXPIRES_IN_HOURS} hour(s) on ${NEXT_UPDATE}"
            fi
        fi

    fi

    # shellcheck disable=SC2086
    SIGNATURE_ALGORITHM="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -text -noout | grep 'Signature Algorithm' | head -n 1)"

    if [ -n "${DEBUG}" ] ; then
        debuglog "${SUBJECT}"
        debuglog "CN         = ${CN}"
        # shellcheck disable=SC2162
        echo "${ISSUERS}" | while read LINE; do
            debuglog "CA         = ${LINE}"
        done
        debuglog "SERIAL     = ${SERIAL}"
        debuglog "FINGERPRINT= ${FINGERPRINT}"
        debuglog "OCSP_URI   = ${OCSP_URI}"
        debuglog "ISSUER_URI = ${ISSUER_URI}"
        debuglog "${SIGNATURE_ALGORITHM}"
    fi

    if echo "${SIGNATURE_ALGORITHM}" | grep -q "sha1" ; then

        if [ -n "${NOSIGALG}" ] ; then

            verboselog "${OPENSSL_COMMAND} Certificate is signed with SHA-1"

        else

            prepend_critical_message "${OPENSSL_COMMAND} Certificate is signed with SHA-1"

        fi

    fi

    if echo "${SIGNATURE_ALGORITHM}" | grep -qi "md5" ; then

        if [ -n "${NOSIGALG}" ] ; then

            verboselog "${OPENSSL_COMMAND} Certificate is signed with MD5"

        else

            prepend_critical_message "${OPENSSL_COMMAND} Certificate is signed with MD5"

        fi

    fi

    ################################################################################
    # Generate the long output
    if [ -n "${LONG_OUTPUT_ATTR}" ] ; then

        check_attr() {
            ATTR="$1"
            if ! echo "${VALID_ATTRIBUTES}" | grep -q ",${ATTR}," ; then
                unknown "Invalid certificate attribute: ${ATTR}"
            else
                # shellcheck disable=SC2086
                value="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -noout -nameopt utf8,oneline,-esc_msb  -"${ATTR}" | sed -e "s/.*=//")"
                LONG_OUTPUT="${LONG_OUTPUT}\\n${ATTR}: ${value}"
            fi

        }

        # Split on comma
        if [ "${LONG_OUTPUT_ATTR}" = "all" ] ; then
            LONG_OUTPUT_ATTR="${VALID_ATTRIBUTES}"
        fi
        attributes=$( echo "${LONG_OUTPUT_ATTR}" | tr ',' "\\n" )
        for attribute in ${attributes} ; do
            check_attr "${attribute}"
        done

        LONG_OUTPUT="$(echo "${LONG_OUTPUT}" | sed 's/\\n/\n/g')"

    fi

    ################################################################################
    # Check the presence of a subjectAlternativeName (required for Chrome)

    # shellcheck disable=SC2086
    SUBJECT_ALTERNATIVE_NAME=$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -text |
           grep --after-context=1 "509v3 Subject Alternative Name:" |
           tail -n 1 |
           sed -e "s/DNS://g" |
           sed -e "s/,//g" |
           sed -e "s/^\\ *//"
        )
    debuglog "subjectAlternativeName = ${SUBJECT_ALTERNATIVE_NAME}"
    if [ -n "${REQUIRE_SAN}" ] && [ -z "${SUBJECT_ALTERNATIVE_NAME}" ] && [ "${OPENSSL_COMMAND}" != "crl" ] ; then
        prepend_critical_message "The certificate for this site does not contain a Subject Alternative Name extension containing a domain name or IP address."
    fi

    ################################################################################
    # Check the CN
    if [ -n "${COMMON_NAME}" ] ; then

        ok=""

        debuglog "check CN: ${CN}"
        debuglog "COMMON_NAME = ${COMMON_NAME}"

        # Common name is case insensitive: using grep for comparison (and not 'case' with 'shopt -s nocasematch' as not defined in POSIX

        if echo "${CN}" | grep -q -i "^\\*\\." ; then

            # Or the literal with the wildcard
            debuglog "checking if the common name matches ^$(echo "${CN}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$"
            if echo "${COMMON_NAME}" | grep -q -i "^$(echo "${CN}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$" ; then
                debuglog "the common name ${COMMON_NAME} matches ^$(echo "${CN}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$"
                ok="true"
            fi

            # Or if both are exactly the same
            debuglog "checking if the common name matches ^${CN}\$"

            if echo "${COMMON_NAME}" | grep -q -i "^${CN}\$" ; then
                debuglog "the common name ${COMMON_NAME} matches ^${CN}\$"
                ok="true"
            fi

        else

            if echo "${COMMON_NAME}" | grep -q -i "^${CN}$" ; then
                ok="true"
            fi

        fi

        # Check alternate names
        if [ -n "${ALTNAMES}" ] && [ -z "${ok}" ]; then

            for cn in ${COMMON_NAME} ; do

                ok=""

                debuglog '==============================='
                debuglog "checking altnames against ${cn}"

                for alt_name in ${SUBJECT_ALTERNATIVE_NAME} ; do

                    debuglog "check Altname: ${alt_name}"

                    if echo "${alt_name}" | grep -q -i "^\\*\\." ; then

                        # Match the domain
                        debuglog "the altname ${alt_name} begins with a '*'"
                        debuglog "checking if the common name matches ^$(echo "${alt_name}" | cut -c 3-)\$"

                        if echo "${cn}" | grep -q -i "^$(echo "${alt_name}" | cut -c 3-)\$" ; then
                            debuglog "the common name ${cn} matches ^$( echo "${alt_name}" | cut -c 3- )\$"
                            ok="true"

                        fi

                        # Or the literal with the wildcard
                        debuglog "checking if the common name matches ^$(echo "${alt_name}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$"

                        if echo "${cn}" | grep -q -i "^$(echo "${alt_name}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$" ; then
                            debuglog "the common name ${cn} matches ^$(echo "${alt_name}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$"
                            ok="true"
                        fi

                        # Or if both are exactly the same
                        debuglog "checking if the common name matches ^${alt_name}\$"

                        if echo "${cn}" | grep -q -i "^${alt_name}\$" ; then
                            debuglog "the common name ${cn} matches ^${alt_name}\$"
                            ok="true"
                        fi

                    else

                        if echo "${cn}" | grep -q -i "^${alt_name}$" ; then
                            ok="true"
                        fi

                    fi

                    if [ -n "${ok}" ] ; then
                        break;
                    fi

                done

                if [ -z "${ok}" ] ; then
                    fail="${cn}"
                    break;
                fi

            done

        fi

        if [ -n "${fail}" ] ; then
            prepend_critical_message "invalid CN ('$(echo "${CN}" | sed "s/|/ PIPE /g")' does not match '${fail}')"
        else
            if [ -z "${ok}" ] ; then
                prepend_critical_message "invalid CN ('$(echo "${CN}" | sed "s/|/ PIPE /g")' does not match '${COMMON_NAME}')"
            fi
        fi

        debuglog " CN check finished"

    fi

    ################################################################################
    # Check the issuer
    if [ -n "${ISSUER}" ] ; then

        debuglog "check ISSUER: ${ISSUER}"

        ok=""
        CA_ISSUER_MATCHED=$(echo "${ISSUERS}" | grep -E "^(O|CN) ?= ?${ISSUER}\$" | sed -E -e "s/^(O|CN) ?= ?//" | head -n1)

        debuglog "   issuer matched = ${CA_ISSUER_MATCHED}"

        if [ -n "${CA_ISSUER_MATCHED}" ]; then
            ok="true"
        else
            # this looks ugly but preserves spaces in CA name
            prepend_critical_message "invalid CA ('$(echo "${ISSUER}" | sed "s/|/ PIPE /g")' does not match '$(echo "${ISSUERS}" | sed -E -e "s/^(O|CN) ?= ?//" | tr '\n' '|' | sed "s/|\$//g" | sed "s/|/\\' or \\'/g")')"
        fi

    fi

    ################################################################################
    # Check if not issued by
    if [ -n "${NOT_ISSUED_BY}" ] ; then

        debuglog "check NOT_ISSUED_BY: ${NOT_ISSUED_BY}"

	debuglog "  executing echo \"${ISSUERS}\" | sed -E -e \"s/^(O|CN) ?= ?//\" | grep -E \"^${NOT_ISSUED_BY}\$\" | head -n1"
	
        ok=""
        CA_ISSUER_MATCHED=$(echo "${ISSUERS}" | sed -E -e "s/^(O|CN) ?= ?//" | grep -E "^${NOT_ISSUED_BY}\$" | head -n1)

        debuglog "   issuer matched = ${CA_ISSUER_MATCHED}"

        if [ -n "${CA_ISSUER_MATCHED}" ]; then
            # this looks ugly but preserves spaces in CA name
            prepend_critical_message "invalid CA ('$(echo "${NOT_ISSUED_BY}" | sed "s/|/ PIPE /g")' matches '$(echo "${ISSUERS}" | sed -E -e "s/^(O|CN) ?= ?//" | tr '\n' '|' | sed "s/|\$//g" | sed "s/|/\\' or \\'/g")')"
        else
            ok="true"
	    CA_ISSUER_MATCHED="$(echo "${ISSUERS}" | grep -E "^CN ?= ?" | sed -E -e "s/^CN ?= ?//" | head -n1)"
        fi

    else

        CA_ISSUER_MATCHED="$(echo "${ISSUERS}" | grep -E "^CN ?= ?" | sed -E -e "s/^CN ?= ?//" | head -n1)"

    fi

    ################################################################################
    # Check the serial number
    if [ -n "${SERIAL_LOCK}" ] ; then

        ok=""

        if echo "${SERIAL}" | grep -q "^${SERIAL_LOCK}\$" ; then
            ok="true"
        fi

        if [ -z "${ok}" ] ; then
            prepend_critical_message "invalid serial number ('$(echo "${SERIAL_LOCK}" | sed "s/|/ PIPE /g")' does not match '${SERIAL}')"
        fi

    fi
    ################################################################################
    # Check the Fingerprint
    if [ -n "${FINGERPRINT_LOCK}" ] ; then

        ok=""

        if echo "${FINGERPRINT}" | grep -q -E "^${FINGERPRINT_LOCK}\$" ; then
            ok="true"
        fi

        if [ -z "${ok}" ] ; then
            prepend_critical_message "invalid SHA1 Fingerprint ('$(echo "${FINGERPRINT_LOCK}" | sed "s/|/ PIPE /g")' does not match '${FINGERPRINT}')"
        fi

    fi

    ################################################################################
    # Check the validity
    if [ -z "${NOEXP}" ] ; then

        debuglog "Checking expiration date"
        if [ -n "${FIRST_ELEMENT_ONLY}" ] || [ "${OPENSSL_COMMAND}" = "crl" ]; then
            check_cert_end_date "$(cat "${CERT}")"
        else
            # count the certificates in the chain
            NUM_CERTIFICATES=$(grep -c -- "-BEGIN CERTIFICATE-" "${CERT}")
            debuglog "Number of certificates in CA chain: $((NUM_CERTIFICATES))"
            debuglog "Skipping ${SKIP_ELEMENT} element of the chain"

            CERT_IN_CHAIN=$(( SKIP_ELEMENT + 1 ))
            while [ "${CERT_IN_CHAIN}" -le "${NUM_CERTIFICATES}" ]; do
                elem_number=$((CERT_IN_CHAIN))
                chain_element=$(sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' "${CERT}" | \
                                    awk -v n="${CERT_IN_CHAIN}" '/-BEGIN CERTIFICATE-/{l++} (l==n) {print}')

		debuglog '------------------------------------------------------------------------------'
                check_cert_end_date "${chain_element}" "${elem_number}"

		debuglog '------------------------------------------------------------------------------'
		check_ocsp "${chain_element}" "${elem_number}"

		if [ -n "${CRL}" ] ; then
		    debuglog '------------------------------------------------------------------------------'
		    check_crl "${chain_element}" "${elem_number}"
		fi

                CERT_IN_CHAIN=$(( CERT_IN_CHAIN + 1 ))
                if ! [ "${ELEMENT}" -eq 0 ] && [ $(( CERT_IN_CHAIN - ELEMENT )) -lt 0 ]; then
                    break
                fi
            done
        fi

    fi

    debuglog '------------------------------------------------------------------------------'

    ################################################################################
    # Check SSL Labs
    if [ -n "${SSL_LAB_CRIT_ASSESSMENT}" ] ; then

        verboselog "Checking SSL Labs assessment"

        while true; do

	    debuglog "http_proxy  = ${http_proxy}"
	    debuglog "HTTPS_PROXY = ${HTTPS_PROXY}"
            debuglog "executing ${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST}${IGNORE_SSL_LABS_CACHE}\""

            if [ -n "${SNI}" ] ; then
                JSON="$(${CURL_BIN} "${CURL_PROXY}" "${CURL_PROXY_ARGUMENT}" "${INETPROTO}" --silent "https://api.ssllabs.com/api/v2/analyze?host=${SNI}${IGNORE_SSL_LABS_CACHE}")"
                CURL_RETURN_CODE=$?
            else
                JSON="$(${CURL_BIN} "${CURL_PROXY}" "${CURL_PROXY_ARGUMENT}" "${INETPROTO}" --silent "https://api.ssllabs.com/api/v2/analyze?host=${HOST}${IGNORE_SSL_LABS_CACHE}")"
                CURL_RETURN_CODE=$?
            fi

            if [ "${CURL_RETURN_CODE}" -ne 0 ] ; then

                debuglog "curl returned ${CURL_RETURN_CODE}: ${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST}${IGNORE_SSL_LABS_CACHE}\""

                unknown "Error checking SSL Labs: curl returned ${CURL_RETURN_CODE}, see 'man curl' for details"

            fi

            JSON="$(printf '%s' "${JSON}" | tr '\n' ' ' )"

            debuglog "Checking SSL Labs: ${CURL_BIN} ${CURL_PROXY} ${CURL_PROXY_ARGUMENT} ${INETPROTO} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST}\""
            debuglog "SSL Labs JSON: ${JSON}"

            # We clear the cache only on the first run
            IGNORE_SSL_LABS_CACHE=""

	    if echo "${JSON}" | grep -q 'Running\ at\ full\ capacity.\ Please\ try\ again\ later' ; then
		verboselog 'SSL Labs running at full capacity'
	    else

		SSL_LABS_HOST_STATUS=$(echo "${JSON}" \
					   | sed 's/.*"status":[ ]*"\([^"]*\)".*/\1/')

		debuglog "SSL Labs status: ${SSL_LABS_HOST_STATUS}"

		case "${SSL_LABS_HOST_STATUS}" in
                    'ERROR')
			SSL_LABS_STATUS_MESSAGE=$(echo "${JSON}" \
						      | sed 's/.*"statusMessage":[ ]*"\([^"]*\)".*/\1/')
			prepend_critical_message "Error checking SSL Labs: ${SSL_LABS_STATUS_MESSAGE}"
			;;
                    'READY')
			if ! echo "${JSON}" | grep -q "grade" ; then

                            # Something went wrong
                            SSL_LABS_STATUS_MESSAGE=$(echo "${JSON}" \
							  | sed 's/.*"statusMessage":[ ]*"\([^"]*\)".*/\1/')
                            prepend_critical_message "SSL Labs error: ${SSL_LABS_STATUS_MESSAGE}"

			else

                            SSL_LABS_HOST_GRADE=$(echo "${JSON}" \
						      | sed 's/.*"grade":[ ]*"\([^"]*\)".*/\1/')

                            debuglog "SSL Labs grade: ${SSL_LABS_HOST_GRADE}"

                            verboselog "SSL Labs grade: ${SSL_LABS_HOST_GRADE}"

                            convert_ssl_lab_grade "${SSL_LABS_HOST_GRADE}"
                            SSL_LABS_HOST_GRADE_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"

                            add_performance_data "ssllabs=${SSL_LABS_HOST_GRADE_NUMERIC}%;;${SSL_LAB_CRIT_ASSESSMENT_NUMERIC}"

                            # Check the grade
                            if [ "${SSL_LABS_HOST_GRADE_NUMERIC}" -lt "${SSL_LAB_CRIT_ASSESSMENT_NUMERIC}" ] ; then
				prepend_critical_message "SSL Labs grade is ${SSL_LABS_HOST_GRADE} (instead of ${SSL_LAB_CRIT_ASSESSMENT})"
                            elif [ -n "${SSL_LAB_WARN_ASSESTMENT_NUMERIC}" ]; then
				if [ "${SSL_LABS_HOST_GRADE_NUMERIC}" -lt "${SSL_LAB_WARN_ASSESTMENT_NUMERIC}" ] ; then
                                    append_warning_message "SSL Labs grade is ${SSL_LABS_HOST_GRADE} (instead of ${SSL_LAB_WARN_ASSESTMENT})"
				fi
                            fi

                            debuglog "SSL Labs grade (converted): ${SSL_LABS_HOST_GRADE_NUMERIC}"

                            # We have a result: exit
                            break

			fi
			;;
                    'IN_PROGRESS')
			# Data not yet available: warn and continue
			verboselog "Warning: no cached data by SSL Labs, check initiated"
			;;
                    'DNS')
			verboselog "SSL Labs cannot resolve the domain name"
			;;
                    *)
			# Try to extract a message
			SSL_LABS_ERROR_MESSAGE=$(echo "${JSON}" \
						     | sed 's/.*"message":[ ]*"\([^"]*\)".*/\1/')

			if [ -z "${SSL_LABS_ERROR_MESSAGE}" ] ; then
                            SSL_LABS_ERROR_MESSAGE="${JSON}"
			fi

			prepend_critical_message "Cannot check status on SSL Labs: ${SSL_LABS_ERROR_MESSAGE}"
		esac

	    fi

            WAIT_TIME=60
            verboselog "Waiting ${WAIT_TIME} seconds"

            sleep "${WAIT_TIME}"

        done

    fi

    ################################################################################
    # Check the organization
    if [ -n "${ORGANIZATION}" ] ; then

        ORG=$(${OPENSSL} x509 -in "${CERT}" -subject -noout | sed -e "s/.*\\/O=//" -e "s/\\/.*//")

        if ! echo "${ORG}" | grep -q -E "^${ORGANIZATION}" ; then
            prepend_critical_message "invalid organization ('$(echo "${ORGANIZATION}" | sed "s/|/ PIPE /g")' does not match '${ORG}')"
        fi

    fi

    ################################################################################
    # Check the organization
    if [ -n "${ADDR}" ] ; then

        EMAIL=$(${OPENSSL} x509 -in "${CERT}" -email -noout)

        verboselog "checking email (${ADDR}): ${EMAIL}"

        if [ -z "${EMAIL}" ] ; then

            debuglog "no email in certificate"

            prepend_critical_message "the certificate does not contain an email address"

        else

            if ! echo "${EMAIL}" | grep -q -E "^${ADDR}" ; then
                prepend_critical_message "invalid email ('$(echo "${ADDR}" | sed "s/|/ PIPE /g")' does not match ${EMAIL})"
            fi

        fi

    fi

    ################################################################################
    # Check if the certificate was verified
    if [ -z "${NOAUTH}" ] && ascii_grep '^verify\ error:' "${ERROR}" ; then

        if ascii_grep '^verify\ error:num=[0-9][0-9]*:self\ signed\ certificate' "${ERROR}" ; then

            if [ -z "${SELFSIGNED}" ] ; then
                prepend_critical_message "Cannot verify certificate, self signed certificate"
            else
                SELFSIGNEDCERT="self signed "
            fi

        elif ascii_grep '^verify\ error:num=[0-9][0-9]*:certificate\ has\ expired' "${ERROR}" ; then

            debuglog 'Cannot verify since the certificate has expired.'

        else

            debuglog "$(sed 's/^/Error: /' "${ERROR}")"

            # Process errors
            details=$( grep  '^verify\ error:' "${ERROR}" | sed 's/verify\ error:num=[0-9]*://' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/, /g' )
            prepend_critical_message "Cannot verify certificate: ${details}"

        fi

    fi

    # if errors exist at this point return
    if [ "${CRITICAL_MSG}" != "" ] ; then
        critical "${CRITICAL_MSG}"
    fi

    if [ "${WARNING_MSG}" != "" ] ; then
        warning "${WARNING_MSG}"
    fi

    ################################################################################
    # If we get this far, assume all is well. :)

    # If --altnames was specified or if the certificate is wildcard,
    # then we show the specified CN in addition to the certificate CN
    CHECKEDNAMES=""
    if [ -n "${ALTNAMES}" ] && [ -n "${COMMON_NAME}" ] && [ "${CN}" != "${COMMON_NAME}" ]; then
        CHECKEDNAMES="(${COMMON_NAME}) "
    elif [ -n "${COMMON_NAME}" ] && echo "${CN}" | grep -q -i "^\\*\\." ; then
        CHECKEDNAMES="(${COMMON_NAME}) "
    fi

    if [ -n "${DAYS_VALID}" ] ; then
        # nicer formatting
        if [ "${DAYS_VALID}" -gt 1 ] ; then
            DAYS_VALID=" (expires in ${DAYS_VALID} days)"
        elif [ "${DAYS_VALID}" -eq 1 ] ; then
            DAYS_VALID=" (expires tomorrow)"
        elif [ "${DAYS_VALID}" -eq 0 ] ; then
            DAYS_VALID=" (expires today)"
        elif [ "${DAYS_VALID}" -eq -1 ] ; then
            DAYS_VALID=" (expired yesterday)"
        else
            DAYS_VALID=" (expired ${DAYS_VALID} days ago)"
        fi
    fi

    if [ -n "${OCSP_EXPIRES_IN_HOURS}" ] ; then
        # nicer formatting
        if [ "${OCSP_EXPIRES_IN_HOURS}" -gt 1 ] ; then
            OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expires in ${OCSP_EXPIRES_IN_HOURS} hours)"
        elif [ "${OCSP_EXPIRES_IN_HOURS}" -eq 1 ] ; then
            OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expires in one hour)"
        elif [ "${OCSP_EXPIRES_IN_HOURS}" -eq 0 ] ; then
            OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expires now)"
        elif [ "${OCSP_EXPIRES_IN_HOURS}" -eq -1 ] ; then
            OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expired one hour ago)"
        else
            OCSP_EXPIRES_IN_HOURS=" (OCSP stapling expired ${OCSP_EXPIRES_IN_HOURS} hours ago)"
        fi
    fi

    if [ -n "${SSL_LABS_HOST_GRADE}" ] ; then
        SSL_LABS_HOST_GRADE=", SSL Labs grade: ${SSL_LABS_HOST_GRADE}"
    fi

    if [ -z "${CN}" ]; then
        DISPLAY_CN=""
    else
        DISPLAY_CN="'${CN}' "
    fi

    if [ -z "${FORMAT}" ]; then
        if [ -n "${TERSE}" ]; then
            FORMAT="%SHORTNAME% OK %CN% %DAYS_VALID%"
        else
            FORMAT="%SHORTNAME% OK - %OPENSSL_COMMAND% %SELFSIGNEDCERT%certificate %DISPLAY_CN%%CHECKEDNAMES%from '%CA_ISSUER_MATCHED%' valid until %DATE%%DAYS_VALID%%OCSP_EXPIRES_IN_HOURS%%SSL_LABS_HOST_GRADE%"
        fi
    fi

    if [ -n "${TERSE}" ]; then
        EXTRA_OUTPUT="${PERFORMANCE_DATA}"
    else
        EXTRA_OUTPUT="${LONG_OUTPUT}${PERFORMANCE_DATA}"
    fi

    debuglog "output parameters: CA_ISSUER_MATCHED     = ${CA_ISSUER_MATCHED}"
    debuglog "output parameters: CHECKEDNAMES          = ${CHECKEDNAMES}"
    debuglog "output parameters: CN                    = ${CN}"
    debuglog "output parameters: DATE                  = ${DATE}"
    debuglog "output parameters: DAYS_VALID            = ${DAYS_VALID}"
    debuglog "output parameters: DYSPLAY_CN            = ${DISPLAY_CN}"
    debuglog "output parameters: OPENSSL_COMMAND       = ${OPENSSL_COMMAND}"
    debuglog "output parameters: SELFSIGNEDCERT        = ${SELFSIGNEDCERT}"
    debuglog "output parameters: SHORTNAME             = ${SHORTNAME}"
    debuglog "output parameters: OCSP_EXPIRES_IN_HOURS = ${OCSP_EXPIRES_IN_HOURS}"
    debuglog "output parameters: SSL_LABS_HOST_GRADE   = ${SSL_LABS_HOST_GRADE}"

    echo "${FORMAT}${EXTRA_OUTPUT}" | sed \
        -e "$( var_for_sed CA_ISSUER_MATCHED "${CA_ISSUER_MATCHED}" )" \
        -e "$( var_for_sed CHECKEDNAMES "${CHECKEDNAMES}" )" \
        -e "$( var_for_sed CN "${CN}" )" \
        -e "$( var_for_sed DATE "${DATE}" )" \
        -e "$( var_for_sed DAYS_VALID "${DAYS_VALID}" )" \
        -e "$( var_for_sed DISPLAY_CN "${DISPLAY_CN}" )" \
        -e "$( var_for_sed OPENSSL_COMMAND "${OPENSSL_COMMAND}" )" \
        -e "$( var_for_sed SELFSIGNEDCERT "${SELFSIGNEDCERT}" )" \
        -e "$( var_for_sed SHORTNAME "${SHORTNAME}" )" \
        -e "$( var_for_sed OCSP_EXPIRES_IN_HOURS "${OCSP_EXPIRES_IN_HOURS}" )" \
        -e "$( var_for_sed SSL_LABS_HOST_GRADE "${SSL_LABS_HOST_GRADE}" )"

    remove_temporary_files

    exit "${STATUS_OK}"

}

# Defined externally
# shellcheck disable=SC2154
if [ -z "${SOURCE_ONLY}" ]; then
    main "${@}"
fi
