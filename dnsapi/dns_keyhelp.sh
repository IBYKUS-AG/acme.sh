#!/bin/bash
#
# This is the keyhelp dns api script for acme.sh
# Reference for the api:
#     https://app.swaggerhub.com/apis-docs/keyhelp/api/2.4
#
# Author: benklett (benjamin<dot>klettbach<at>ibykus<dot>de)
# Created: 2022-12-09
#
# Usage:
#     export KH_Host="keyhelp.hostname.com"
#     export KH_ApiKey="api-key"
#     acme.sh --issue --dns dns_keyhelp -d example.com

# Add txt record for validation.
# Usage: dns_keyhelp_add fulldomain txtvalue
dns_keyhelp_add() {
  fulldomain=$1
  txtvalue=$2
  _info "Using keyhelp"

  # Get Keyhelp URL and ApiKey from config or environment an log them
  KH_Host="${KH_Host:-$(_readaccountconf_mutable KH_Host)}"
  KH_ApiKey="${KH_ApiKey:-$(_readaccountconf_mutable KH_ApiKey)}"
  _debug KH_Host "$KH_Host"
  _debug KH_ApiKey "$KH_ApiKey"
  if [ -z "$KH_Host" ] || [ -z "$KH_ApiKey" ]; then
    KH_Host=""
    KH_ApiKey=""
    _err "You don't specify the keyhelp host and api key yet."
    _err "Please create your key and try again."
    return 1
  fi

  # Save the KeyHelp URL and ApiKey
  _saveaccountconf_mutable KH_Host "$KH_Host"
  _saveaccountconf_mutable KH_ApiKey "$KH_ApiKey"

  # Set Keyhelp Api URL
  _kh_url="https://$KH_Host/api/v2"

  # Set Header
  export _H1="Accept: application/json"
  export _H2="X-API-Key: $KH_ApiKey"

  # Get the TLD
  _domain_rev=$(echo "$fulldomain" | rev)
  _domain="$(echo "$_domain_rev" | cut -d. -f2 | rev).$(echo "$_domain_rev" | cut -d. -f1 | rev)"
  _debug _domain "$_domain"

  # Get the subdomain
  _sub_domain=${fulldomain/."$_domain"/}
  _debug _sub_domain "$_sub_domain"

  # Get domain id
  _domain_json="$(_get "$_kh_url/domains/name/$_domain")"
  if ! _contains "$_domain_json" "$_domain"; then
    _err "Domain not found in keyhelp instance."
    return 1
  fi
  _domain_id="$(_get "$_kh_url/domains/name/$_domain" | grep '"id":' | cut -d'"' -f3 | tr -d " :,")"
  _debug _domain_id "$_domain_id"

  # Prepare dns reponse
  _dns_response="$(_get "$_kh_url/dns/$_domain_id" | grep -v '"is_custom_dns"' | grep -v '"is_dns_disabled"' | grep -v '"dkim_txt_record"' | sed -e s/]/,\{\"host\":\""$_sub_domain"\",\"ttl\":\"30\",\"type\":\"TXT\",\"value\":\""$txtvalue"\"\}]/ | tr -d '\r\n')"
  _debug _dns_response "$_dns_response"

  error=$(_post "$_dns_response" "$_kh_url/dns/$_domain_id" "" "PUT" "application/json" | grep '"id"')
  ret=$?

  # PUT the new dns config
  if [ $ret -ne 0 ]; then
    _debug error "$error"
    _err "Update of dns was not successful"
    return 1
  fi

  return 0
}

# Remove the txt record after validation.
# Usage: dns_keyhelp_rm fulldomain txtvalue
dns_keyhelp_rm() {
  fulldomain=$1
  txtvalue=$2

  # Get Keyhelp URL and ApiKey from config or environment an log them
  KH_Host="${KH_Host:-$(_readaccountconf_mutable KH_Host)}"
  KH_ApiKey="${KH_ApiKey:-$(_readaccountconf_mutable KH_ApiKey)}"
  _debug KH_Host "$KH_Host"
  _debug KH_ApiKey "$KH_ApiKey"
  if [ -z "$KH_Host" ] || [ -z "$KH_ApiKey" ]; then
    KH_Host=""
    KH_ApiKey=""
    _err "You don't specify the keyhelp host and api key yet."
    _err "Please create your key and try again."
    return 1
  fi

  # Save the KeyHelp URL and ApiKey
  _saveaccountconf_mutable KH_Host "$KH_Host"
  _saveaccountconf_mutable KH_ApiKey "$KH_ApiKey"

  # Set Keyhelp Api URL
  _kh_url="https://$KH_Host/api/v2"

  # Set Header
  export _H1="Accept: application/json"
  export _H2="X-API-Key: $KH_ApiKey"

  # Get the TLD
  _domain_rev=$(echo "$fulldomain" | rev)
  _domain="$(echo "$_domain_rev" | cut -d. -f2 | rev).$(echo "$_domain_rev" | cut -d. -f1 | rev)"
  _debug _domain "$_domain"

  # Get the subdomain
  _sub_domain=${fulldomain/."$_domain"/}
  _debug _sub_domain "$_sub_domain"

  # Get domain id
  _domain_json="$(_get "$_kh_url/domains/name/$_domain")"
  if ! _contains "$_domain_json" "$_domain"; then
    _err "Domain not found in keyhelp instance."
    return 1
  fi
  _domain_id="$(_get "$_kh_url/domains/name/$_domain" | grep '"id":' | cut -d'"' -f3 | tr -d " :,")"
  _debug _domain_id "$_domain_id"

  # Prepare dns reponse
  _dns_response="$(_get "$_kh_url/dns/$_domain_id" | grep -v '"is_custom_dns"' | grep -v '"is_dns_disabled"' | grep -v '"dkim_txt_record"' | tr -d '\r\n' | sed -e 's/, *{[a-zA-Z0-9":,. _\-]*"'"$txtvalue"'"[a-zA-Z0-9":,. _\-]*}//g')"
  _debug _dns_response "$_dns_response"

  error=$(_post "$_dns_response" "$_kh_url/dns/$_domain_id" "" "PUT" "application/json" | grep '"id"')
  ret=$?

  # PUT the new dns config
  if [ $ret -ne 0 ]; then
    _debug error "$error"
    _err "Update of dns was not successful"
    return 1
  fi

  _debug fulldomain "$fulldomain"
  _debug txtvalue "$txtvalue"

  return 0
}

# -*- mode: sh; tab-width: 2; indent-tabs-mode: s; coding: utf-8 -*-
