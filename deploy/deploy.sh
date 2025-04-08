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
	
	echo "" 
	echo "@DEV: You may run into an error about verification (missing Etherscan key for chainId ... or other errors)." 
	echo "      If you cannot fix it, remove the --verify flag and verify the contract manually afterwards. This needs to be fixed."
	echo "" 
	# Ticket for this issue:  https://lifi.atlassian.net/browse/LF-12359

	RAW_RETURN_DATA=$(forge script script/Deploy.s.sol -f $NETWORK -vvvv --json --legacy --broadcast --skip-simulation --gas-limit 2000000)
	RETURN_CODE=$?
	echo "RAW_RETURN_DATA: $RAW_RETURN_DATA"
	CLEAN_RETURN_DATA=$(echo $RAW_RETURN_DATA | sed 's/^.*{\"logs/{\"logs/')
	echo "RAW_RETURN_DATA: $RAW_RETURN_DATA"
	RETURN_DATA=$(echo $CLEAN_RETURN_DATA | jq -r '.returns' 2>/dev/null)
	echo ""
	echo "RETURN_DATA: $RETURN_DATA"
	echo ""

	if [[ $RETURN_CODE -ne 0 ]]; then
		echo "❌ Error: deployment was not successful"
		exit 1
	fi

	FACTORY_ADDRESS=$(echo $RETURN_DATA | jq -r '.factory.value')
	echo "✅ Successfully deployed to address $FACTORY_ADDRESS"

	# verify contract
	API_KEY="$(tr '[:lower:]' '[:upper:]' <<<$NETWORK)_API_KEY"
	API_KEY="${!API_KEY}"
	echo ""
	# not working as intended, we need to fix this
	# echo "Trying to verify contract now with API key: $API_KEY"
	# forge verify-contract "$FACTORY_ADDRESS" src/CREATE3Factory.sol:CREATE3Factory --watch --etherscan-api-key "$API_KEY" --chain "$NETWORK"
	echo ""

	echo ""
	echo "Creating deploy log"
	saveContract $NETWORK CREATE3Factory $FACTORY_ADDRESS

	echo "✅ Deployment successfully completed"
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
