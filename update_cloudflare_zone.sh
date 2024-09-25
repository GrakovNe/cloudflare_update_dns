
#!/bin/bash


if ! command -v jq &> /dev/null
then
    echo "jq could not be found, please install it."
    exit 1
fi

PUBLIC_IP=$(curl -s https://services.home-assistant.io/whoami/v1/ip)
if [ -z "$PUBLIC_IP" ]; then
    echo "Failed to retrieve public IP address."
    exit 1
fi

declare -A DOMAINS

source config.cfg

if [ -z "$TOKEN" ]; then
    echo "TOKEN is not set in config.cfg"
    exit 1
fi
if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo "DOMAINS is not set or empty in config.cfg"
    exit 1
fi

for DOMAIN in "${!DOMAINS[@]}"
do
    ZONE_NAME="${DOMAINS[$DOMAIN]}"
    echo "Processing domain: $DOMAIN with zone: $ZONE_NAME"

    # Получение Zone ID
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

    if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "null" ]; then
        echo "Failed to get Zone ID for $ZONE_NAME"
        continue
    fi

    echo "Zone ID for $ZONE_NAME is $ZONE_ID"

    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$DOMAIN" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

    if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" == "null" ]; then
        echo "Failed to get Record ID for $DOMAIN"
        continue
    fi

    echo "Record ID for $DOMAIN is $RECORD_ID"

    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$PUBLIC_IP\",\"ttl\":1,\"proxied\":false}")

    SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')

    if [ "$SUCCESS" == "true" ]; then
        echo "Successfully updated DNS record for $DOMAIN to $PUBLIC_IP"
    else
        echo "Failed to update DNS record for $DOMAIN"
        echo "Response: $UPDATE_RESPONSE"
    fi

done
