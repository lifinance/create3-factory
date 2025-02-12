#!/bin/bash

# load env variables
source .env

deploy() {
	NETWORK=$1

	# get deployer address
	DEPLOYER_ADDRESS=$(cast wallet address "$PRIVATE_KEY")
	echo "You are deploying from address: $DEPLOYER_ADDRESS (should be 0x11F11121DF7256C40339393b0FB045321022ce44 for 0x123 diamond address)"

	# get balance in given network
	RPC_KEY="RPC_URL_$(tr '[:lower:]' '[:upper:]' <<<"$NETWORK")"
	BALANCE=$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "${!RPC_KEY}")

	# return formatted balance
	echo "Deployer Wallet balance: $(echo "scale=10;$BALANCE / 1000000000000000000" | bc)"

	RAW_RETURN_DATA=$(forge script script/Deploy.s.sol -f $NETWORK -vvvv --json --legacy --broadcast --skip-simulation --gas-limit 2000000)
	RETURN_CODE=$?
	RETURN_DATA=$(echo $RAW_RETURN_DATA | jq -r '.returns' 2>/dev/null)
	echo ""
	echo ""

	if [[ $RETURN_CODE -ne 0 ]]; then
		echo "❌ Error: deployment was not successful"
		exit 1
	fi

	factory=$(echo $RETURN_DATA | jq -r '.factory.value')

	saveContract $NETWORK CREATE3Factory $factory

	echo "✅ Successfully deployed to address $factory"
}

saveContract() {
	NETWORK=$1
	CONTRACT=$2
	ADDRESS=$3

	ADDRESSES_FILE=./deployments/$NETWORK.json

	# create an empty json if it does not exist
	if [[ ! -e $ADDRESSES_FILE ]]; then
		echo "{}" >"$ADDRESSES_FILE"
	fi
	result=$(cat "$ADDRESSES_FILE" | jq -r ". + {\"$CONTRACT\": \"$ADDRESS\"}")
	printf %s "$result" >"$ADDRESSES_FILE"
}

deploy $1
