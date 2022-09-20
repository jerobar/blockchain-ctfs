/**
 * Forge
 * 
 * You've been contacted by a team developing an ERC1155 contract written 
 * entirely in Yul. They would like some assistance with their new "forging" 
 * feature, which will allow users to forge two or more tokens of the same id 
 * into the coveted '42' token. Right away, you notice something seems a little 
 * off...
 * 
 * Starting with a single token id '1', your goal is to forge a '42' token.
 */
object "Forge" {

    /**
     * Constructor
     * 
     * Stores the caller as contract owner and deploys the contract.
     */
    code {
        // Store the contract owner in slot 0
        sstore(0, caller())

        // Deploy the contract
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }

    object "runtime" {

        code {
            /**
             * Storage slots
             */
            // 0: address `owner`
            function ownerSlot() -> slot { slot := 0 }

            // 1: mapping uint256 `tokenID` => (address `account` => uint256 `balance`)
            function balancesSlot() -> slot { slot := 1 }

            /**
             * Dispatcher
             * 
             * Dispatches to relevant function based on calldata's function 
             * selector (the first 4 bytes of keccak256(functionSignature)).
             */
            switch functionSelector()
            // balanceOf(address,uint256)
            case 0x00fdd58e {
                returnUint(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
            }
            // mint(address,uint256,uint256,bytes)
            case 0x731133e9 {
                mint(
                    decodeAsAddress(0), 
                    decodeAsUint(1), 
                    decodeAsUint(2), 
                    0 // Dev: ignore `data`
                )
            }
            // trade(uint256,uint256)
            case 0xe20be69a {
                trade(decodeAsUint(0), decodeAsUint(1))
            }
            // forge(uint256[])
            case 0x1019bdb6 {
                // forge(decodeAsTokenIdsToForge(0))
                forge(decodeAsForgingIdsArray(0))
            }
            default {
                revert(0, 0)
            }

            /**
             * Calldata decoding functions
             */
            function functionSelector() -> selector {
                selector := shr(0xE0, calldataload(0))
            }

            function decodeAsAddress(cdOffset) -> value {
                let uintAtOffset := decodeAsUint(cdOffset)

                // Revert if not valid address
                if iszero(iszero(and(uintAtOffset, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
                    revert(0, 0)
                }

                value := uintAtOffset
            }

            function decodeAsUint(cdOffset) -> value {
                let cdPosition := add(4, mul(cdOffset, 0x20))

                // Revert if position not in calldata
                if lt(calldatasize(), add(cdPosition, 0x20)) {
                    revert(0, 0)
                }

                value := calldataload(cdPosition)
            }

            function decodeAsForgingIdsArray(offset) -> arrayLengthPointer {
                // Get position and length of array from calldata
                let offsetOfArrayPosition := add(4, mul(offset, 0x20))
                let offsetOfArray := calldataload(offsetOfArrayPosition)
                let arrayLengthPosition := add(4, offsetOfArray)
                let arrayLength := calldataload(arrayLengthPosition)

                // Load free memory pointer (0x80)
                let freeMemoryPointer := mload(0x40)

                // Store array length at free memory pointer
                let arrayLengthPointer_ := freeMemoryPointer
                mstore(arrayLengthPointer_, arrayLength)
                incrementFreeMemoryPointer(freeMemoryPointer, 0x20)

                // For each token id
                for { let i := 1 } lt(i, add(arrayLength, 1)) { i := add(i, 1) }
                {
                    freeMemoryPointer := mload(0x40)

                    let position := add(arrayLengthPosition, mul(i, 0x20))
                    let id := calldataload(position)
                    
                    if tokenIdIsValid(id) {
                        let accountBalanceKey := getAccountBalanceKey(caller(), id)
                        let accountBalance := sload(accountBalanceKey)

                        // Revert if user attempting to forge more than their token balance
                        if iszero(accountBalance) {
                            revert(0, 0)
                        }

                        // Decrement user's balance for this id
                        sstore(accountBalanceKey, sub(accountBalance, 1))
                    }

                    // Store token id in memory
                    mstore(freeMemoryPointer, id)
                    incrementFreeMemoryPointer(freeMemoryPointer, 0x20)
                }

                arrayLengthPointer := arrayLengthPointer_
            }

            /**
             * Calldata encoding functions
             */
            function returnUint(value) {
                mstore(0x00, value)

                return(0x00, 0x20)
            }

            /**
             * Callable functions
             */
            function balanceOf(account, id) -> accountBalance {
                let balanceKey := getAccountBalanceKey(account, id)

                accountBalance := sload(balanceKey)
            }

            function _mint(to, id, amount) {
                let accountBalanceKey := getAccountBalanceKey(to, id)
                let accountBalance := sload(accountBalanceKey)

                sstore(accountBalanceKey, add(accountBalance, amount))
            }

            function mint(to, id, amount, data) {
                // Revert if caller not owner
                if iszero(eq(caller(), sload(ownerSlot()))) {
                    revert(0, 0)
                }

                _mint(to, id, amount)
            }

            function trade(idToTrade, idToTradeFor) {
                if eq(idToTradeFor, 42) {
                    revert(0, 0)
                }

                let idToTradeBalanceKey := getAccountBalanceKey(caller(), idToTrade)
                let idToTradeBalance := sload(idToTradeBalanceKey)

                if iszero(idToTradeBalance) {
                    revert(0, 0)
                }

                let idToTradeForBalanceKey := getAccountBalanceKey(caller(), idToTradeFor)
                let idToTradeForBalance := sload(idToTradeForBalanceKey)

                sstore(idToTradeBalanceKey, sub(idToTradeBalance, 1))
                sstore(idToTradeForBalanceKey, add(idToTradeForBalance, 1))
            }

            function forge(tokenIdsArrayLengthPointer) {
                let freeMemoryPointer := mload(0x40)
                let tokenIdsArrayLength := mload(tokenIdsArrayLengthPointer)

                let matchesFound := 0

                // For all but the last token id's
                for { let i := 1 } lt(i, tokenIdsArrayLength) { i := add(i, 1) }
                {
                    let tokenIdOnePointer := add(tokenIdsArrayLengthPointer, mul(i, 0x20))
                    let tokenIdOne := mload(tokenIdOnePointer)

                    if tokenIdIsValid(tokenIdOne) {
                        // Check for match in subsequent token id's
                        for { let n := add(i, 1) } lt(n, add(tokenIdsArrayLength, 1)) { n := add(n, 1) } 
                        {
                            let tokenIdTwoPointer := add(tokenIdsArrayLengthPointer, mul(n, 0x20))
                            let tokenIdTwo := mload(tokenIdTwoPointer)

                            if eq(tokenIdOne, tokenIdTwo) {
                                matchesFound := 1
                            }
                        }
                    }
                }

                if matchesFound {
                    _mint(caller(), 42, 1)
                }
            }

            /**
             * Storage access functions
             */
            function getAccountBalanceKey(account, tokenId) -> balanceKey {
                // Balances: mapping uint256 `tokenID` => (address `account` => uint256 `balance`)
                
                // Hash `tokenId` and `sBalancesSlot()`
                let hashOfIdandBalancesSlot := keccakHashTwoValues(tokenId, balancesSlot())

                // `balanceKey` = keccak256(`account`, keccak256(`tokenId`, `sBalancesSlot()`))
                balanceKey := keccakHashTwoValues(account, hashOfIdandBalancesSlot)
            }

            /**
             * Utility functions
             */
            function incrementFreeMemoryPointer(currentValue, incrementBy) {
                mstore(0x40, add(currentValue, incrementBy))
            }

            function keccakHashTwoValues(valueOne, valueTwo) -> keccakHash {
                let temporaryScratchSpace := add(mload(0x40), 0x60)

                // Store words `valueOne` and `valueTwo` in memory
                mstore(temporaryScratchSpace, valueOne)
                mstore(add(temporaryScratchSpace, 0x20), valueTwo)

                // Store hash of `valueOne` and `valueTwo` in memory
                mstore(temporaryScratchSpace, keccak256(temporaryScratchSpace, 0x40))

                keccakHash := mload(temporaryScratchSpace)
            }

            function tokenIdIsValid(id) -> isValid {
                // Token id's begin at 1
                isValid := gt(id, 0)
            }
        }
    }
}
