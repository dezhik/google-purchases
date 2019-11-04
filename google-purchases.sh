#!/bin/bash
SCRIPT_VERSION=0.1.0
GOOGLE_API_BASE_URI="https://www.googleapis.com/androidpublisher/v3/applications/"
GOOGLE_API_OAUTH_URI="https://accounts.google.com/o/oauth2/token"
README_MSG="See https://github.com/dezhik/google-purchases/blob/master/README.md for more details."

COMMAND="$1"
shift

IS_PRODUCT=$(echo "${COMMAND}" | grep -Eo "^products" )

if [[ "${COMMAND}" != "products.get" && ${COMMAND} != "products.acknowledge" && ${COMMAND} != "subscriptions.get" ]]; then
	echo "\"${COMMAND}\" is not a supported command in v. ${SCRIPT_VERSION}"
	echo "Usage: google-api-util command [-options]"
	echo "where command in:"
	echo "   products.get"
	echo "   products.acknowledge"
	echo "   subscriptions.get"
	
	echo "Version ${SCRIPT_VERSION}."
	echo ${README_MSG}
	exit 1
fi

while getopts a:c:p:t:s: option
do
case "${option}"
in
a) ACCESS_TOKEN=${OPTARG};;
c) CONF_FILE=${OPTARG};;
p) PACKAGE=${OPTARG};;
t) PURCHASE_TOKEN=${OPTARG};;
s) SKU=${OPTARG};;
esac
done

if [[ ! -z "$CONF_FILE" ]]; then
	if [ -f "$CONF_FILE" ]; then
		while read LINE; do 
			case "${LINE%=*}"
			in
			access_token|ACCESS_TOKEN) ACCESS_TOKEN=${LINE##*=};;
			client_id|CLIENT_ID) CLIENT_ID=${LINE##*=};;
			client_secret|CLIENT_SECRET) CLIENT_SECRET=${LINE##*=};;
			refresh_token|REFRESH_TOKEN) REFRESH_TOKEN=${LINE##*=};;
			package|PACKAGE) PACKAGE=${LINE##*=};;
			product_ids|PRODUCT_IDS) PRODUCT_IDS=${LINE##*=};;
			subscription_ids|SUBSCRIPTION_IDS) SUBSCRIPTION_IDS=${LINE##*=};;
			esac
		done < $CONF_FILE
	else
		echo "Config file \"$CONF_FILE\" does not exist."
	fi
fi

if [[ -z "$PACKAGE" ]]; then
	echo "Please specify package with -p option or inside config file passed in arguments"
	exit 1
fi

if [[ -z "$SKU" && -z "${PRODUCT_IDS}" ]]; then
	echo "Please specify productId with -s option or inside config file passed in arguments"
	exit 1
fi

if [[ -z "$PURCHASE_TOKEN" ]]; then
	echo "Please specify purchase token with -t option"
	exit 1
fi	

if [[ -z "$ACCESS_TOKEN" ]]; then
	echo "Access token haven't been passed (-a option), trying to obtain it via OAUTH with credentials from \"${CONF_FILE}\" config"
	if [[ -z "$CLIENT_ID" || -z "${CLIENT_SECRET}" || -z "${REFRESH_TOKEN}" ]]; then
		echo "Access token is not passed or can't be obtained, please use -a or -c option"
		exit 1
	fi

	OAUTH_RESP=$(curl -s -X POST -d "grant_type=refresh_token&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}" ${GOOGLE_API_OAUTH_URI})
	ACCESS_TOKEN=$(echo "${OAUTH_RESP}" | grep -Eo "\"access_token\"\:\s*\"[A-Za-z0-9+=\/_.-]*" | grep -Eo "[A-Za-z0-9+=\/_.-]*$")
	
	if [[ -z "$ACCESS_TOKEN" ]]; then
		echo "${OAUTH_RESP}"
		echo "Access token is not passed or can't be obtained, please provide token with -a option or check config file \"${CONF_FILE}\" params"
		exit 1
	fi
fi

function invokeRequest() {
	if [[ "${COMMAND}" == "products.get" ]]; then
		INVOKE_RESULT=$(curl -s "${GOOGLE_API_BASE_URI}${PACKAGE}/purchases/products/${SKU}/tokens/${PURCHASE_TOKEN}?access_token=${ACCESS_TOKEN}")
	elif [[ "${COMMAND}" == "products.acknowledge" ]]; then
		INVOKE_RESULT=$(curl -s  -X POST -d "access_token=${ACCESS_TOKEN}" "${GOOGLE_API_BASE_URI}${PACKAGE}/purchases/products/${SKU}/tokens/${PURCHASE_TOKEN}:acknowledge")
	elif [[ "${COMMAND}" == "subscriptions.get" ]]; then
		INVOKE_RESULT=$(curl -s "${GOOGLE_API_BASE_URI}${PACKAGE}/purchases/subscriptions/${SKU}/tokens/token?access_token=${ACCESS_TOKEN}&token=${PURCHASE_TOKEN}")
	fi
}

#"message": "The purchase token does not match the product ID."
if [[ -z "$SKU" ]]; then
	
	if [[ -z ${IS_PRODUCT} ]]; then
		echo "Subscription ID haven't been passed in arguments via -s option."
		if [[ -z "${SUBSCRIPTION_IDS}" ]]; then
			echo "Provide subscription Id via option -s or through subscription_ids=... in config file"
			echo ${README_MSG}
			exit 1
		fi
		echo "Iterating over ${SUBSCRIPTION_IDS}"
		POSSIBLE_IDS=$(echo "$SUBSCRIPTION_IDS" | tr ',' '\n')
	else
		echo "Product ID haven't been passed in arguments via -s option."
		if [[ -z "${PRODUCT_IDS}" ]]; then
			echo "Provide product id via option -s or through product_ids=... in config file"
			echo ${README_MSG}
			exit 1
		fi
		echo "Iterating over ${PRODUCT_IDS}"
		POSSIBLE_IDS=$(echo "$PRODUCT_IDS" | tr ',' '\n')
	fi

  	for SKU in $POSSIBLE_IDS; do
  		invokeRequest
  		
  		# check for "code": 400
  		if [[ ! -z $(echo "${INVOKE_RESULT}" | grep -Eo "The purchase token does not match the product ID." ) ]]; then
  			echo "$SKU — doesn't match product purchase token"
  			continue
  		fi
  		if [[ ! -z $(echo "${INVOKE_RESULT}" | grep -Eo "The subscription purchase token does not match the subscription ID." ) ]]; then
  			echo "$SKU — doesn't match subscription purchase token"
  			continue
  		fi
		
		echo
		echo "result for $SKU"
		echo "$INVOKE_RESULT"
		exit 0
  	done

  	echo "Not found"
else
	invokeRequest
	echo "$INVOKE_RESULT"
fi
