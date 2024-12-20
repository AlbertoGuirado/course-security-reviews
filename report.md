
# Table of Contents

- [Table of Contents](#table-of-contents)
- [Summary](#summary)
	- [Files Summary](#files-summary)
	- [Files Details](#files-details)
	- [Issue Summary](#issue-summary)
- [Medium Issues](#medium-issues)
	- [M-1: Centralization Risk for trusted owners](#m-1-centralization-risk-for-trusted-owners)
- [Low Issues](#low-issues)
	- [L-1: `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`](#l-1-abiencodepacked-should-not-be-used-with-dynamic-types-when-passing-the-result-to-a-hash-function-such-as-keccak256)
	- [L-2: Solidity pragma should be specific, not wide](#l-2-solidity-pragma-should-be-specific-not-wide)
- [NC Issues](#nc-issues)
	- [NC-1: Missing checks for `address(0)` when assigning values to address state variables](#nc-1-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
	- [NC-2: Functions not used internally could be marked external](#nc-2-functions-not-used-internally-could-be-marked-external)
	- [NC-3: Constants should be defined and used instead of literals](#nc-3-constants-should-be-defined-and-used-instead-of-literals)
	- [NC-4: Event is missing `indexed` fields](#nc-4-event-is-missing-indexed-fields)


# Summary

## Files Summary

| Key | Value |
| --- | --- |
| .sol Files | 2 |
| Total nSLOC | 0 |


## Files Details

| Filepath | nSLOC |
| --- | --- |
| **Total** | **0** |


## Issue Summary

| Category | No. of Issues |
| --- | --- |
| Critical | 0 |
| High | 0 |
| Medium | 1 |
| Low | 2 |
| NC | 4 |


# Medium Issues

## M-1: Centralization Risk for trusted owners

Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

- Found in src/PuppyRaffle.sol [Line: 18](src\PuppyRaffle.sol#L18)

	```solidity
	contract PuppyRaffle is ERC721, Ownable {
	```

- Found in src/PuppyRaffle.sol [Line: 241](src\PuppyRaffle.sol#L241)

	```solidity
	    /// audi Need a if to check if newFeeAddress is null = address(0)
	```



# Low Issues

## L-1: `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`

Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). Unless there is a compelling reason, `abi.encode` should be preferred. If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead.

- Found in src/PuppyRaffle.sol [Line: 273](src\PuppyRaffle.sol#L273)

	```solidity
	        string memory imageURI = rarityToUri[rarity];
	```

- Found in src/PuppyRaffle.sol [Line: 277](src\PuppyRaffle.sol#L277)

	```solidity
	            abi.encodePacked(
	```



## L-2: Solidity pragma should be specific, not wide

Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.0;`, use `pragma solidity 0.8.0;`

- Found in src/PuppyRaffle.sol [Line: 2](src\PuppyRaffle.sol#L2)

	```solidity
	pragma solidity ^0.7.6;
	```



# NC Issues

## NC-1: Missing checks for `address(0)` when assigning values to address state variables

Assigning values to address state variables without checking for `address(0)`.

- Found in src/PuppyRaffle.sol [Line: 66](src\PuppyRaffle.sol#L66)

	```solidity
	        feeAddress = _feeAddress;
	```

- Found in src/PuppyRaffle.sol [Line: 205](src\PuppyRaffle.sol#L205)

	```solidity
	        raffleStartTime = block.timestamp; // e resetting the raffle start time
	```

- Found in src/PuppyRaffle.sol [Line: 241](src\PuppyRaffle.sol#L241)

	```solidity
	    /// audi Need a if to check if newFeeAddress is null = address(0)
	```



## NC-2: Functions not used internally could be marked external



- Found in script/DeployPuppyRaffle.sol [Line: 12](script\DeployPuppyRaffle.sol#L12)

	```solidity
	    function run() public {
	```

- Found in src/PuppyRaffle.sol [Line: 83](src\PuppyRaffle.sol#L83)

	```solidity
	    function enterRaffle(address[] memory newPlayers) public payable {
	```

- Found in src/PuppyRaffle.sol [Line: 105](src\PuppyRaffle.sol#L105)

	```solidity
	    function refund(uint256 playerIndex) public {
	```

- Found in src/PuppyRaffle.sol [Line: 264](src\PuppyRaffle.sol#L264)

	```solidity
	        return "data:application/json;base64,";
	```



## NC-3: Constants should be defined and used instead of literals



- Found in script/DeployPuppyRaffle.sol [Line: 17](script\DeployPuppyRaffle.sol#L17)

	```solidity
	            1e18,
	```

- Found in src/PuppyRaffle.sol [Line: 94](src\PuppyRaffle.sol#L94)

	```solidity
	        for (uint256 i = 0; i < players.length - 1; i++) {
	```

- Found in src/PuppyRaffle.sol [Line: 95](src\PuppyRaffle.sol#L95)

	```solidity
	            for (uint256 j = i + 1; j < players.length; j++) {
	```

- Found in src/PuppyRaffle.sol [Line: 152](src\PuppyRaffle.sol#L152)

	```solidity
	        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
	```

- Found in src/PuppyRaffle.sol [Line: 169](src\PuppyRaffle.sol#L169)

	```solidity
	        uint256 prizePool = (totalAmountCollected * 80) / 100;
	```

- Found in src/PuppyRaffle.sol [Line: 170](src\PuppyRaffle.sol#L170)

	```solidity
	        uint256 fee = (totalAmountCollected * 20) / 100;
	```

- Found in src/PuppyRaffle.sol [Line: 195](src\PuppyRaffle.sol#L195)

	```solidity
	        uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
	```



## NC-4: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

- Found in src/PuppyRaffle.sol [Line: 55](src\PuppyRaffle.sol#L55)

	```solidity
	    event RaffleEnter(address[] newPlayers);
	```

- Found in src/PuppyRaffle.sol [Line: 56](src\PuppyRaffle.sol#L56)

	```solidity
	    event RaffleRefunded(address player);
	```

- Found in src/PuppyRaffle.sol [Line: 57](src\PuppyRaffle.sol#L57)

	```solidity
	    event FeeAddressChanged(address newFeeAddress);
	```



