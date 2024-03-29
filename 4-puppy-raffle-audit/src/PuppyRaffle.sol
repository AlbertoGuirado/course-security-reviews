// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
// report-written use a floating pragma is bad
// report-written outdated 0.7 version 
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Base64} from "lib/base64/base64.sol";
/// @title PuppyRaffle
/// @author PuppyLoveDAO
/// @notice This project is to enter a raffle to win a cute dog NFT. The protocol should do the following:
/// 1. Call the `enterRaffle` function with the following parameters:
///    1. `address[] participants`: A list of addresses that enter. You can use this to enter yourself multiple times, or yourself and a group of your friends.
/// 2. Duplicate addresses are not allowed
/// 3. Users are allowed to get a refund of their ticket & `value` if they call the `refund` function
/// 4. Every X seconds, the raffle will be able to draw a winner and be minted a random puppy
/// 5. The owner of the protocol will set a feeAddress to take a cut of the `value`, and the rest of the funds will be sent to the winner of the puppy.
contract PuppyRaffle is ERC721, Ownable {
    using Address for address payable;

    uint256 public immutable entranceFee;

    address[] public players;
    // report-witten this should be immutable
    uint256 public raffleDuration;
    uint256 public raffleStartTime;
    address public previousWinner;

    // We do some storage packing to save gas
    address public feeAddress;
    uint64 public totalFees = 0;

    // mappings to keep track of token traits
    mapping(uint256 => uint256) public tokenIdToRarity;
    mapping(uint256 => string) public rarityToUri;
    mapping(uint256 => string) public rarityToName;

    // Stats for the common puppy (pug)
    // report should be constant
    string private commonImageUri = "ipfs://QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";
    uint256 public constant COMMON_RARITY = 70;
    string private constant COMMON = "common";

    // Stats for the rare puppy (st. bernard)
    string private rareImageUri = "ipfs://QmUPjADFGEKmfohdTaNcWhp7VGk26h5jXDA7v3VtTnTLcW";
    uint256 public constant RARE_RARITY = 25;
    string private constant RARE = "rare";

    // Stats for the legendary puppy (shiba inu)
    string private legendaryImageUri = "ipfs://QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU";
    uint256 public constant LEGENDARY_RARITY = 5;
    string private constant LEGENDARY = "legendary";

    // Events
    event RaffleEnter(address[] newPlayers);
    event RaffleRefunded(address player);
    event FeeAddressChanged(address newFeeAddress);

    /// @param _entranceFee the cost in wei to enter the raffle
    /// @param _feeAddress the address to send the fees to
    /// @param _raffleDuration the duration in seconds of the raffle
    constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration) ERC721("Puppy Raffle", "PR") {
        entranceFee = _entranceFee;
        // report-written check for zero address! (address(0))
        // input validation 
        feeAddress = _feeAddress;
        raffleDuration = _raffleDuration;
        raffleStartTime = block.timestamp;

        rarityToUri[COMMON_RARITY] = commonImageUri;
        rarityToUri[RARE_RARITY] = rareImageUri;
        rarityToUri[LEGENDARY_RARITY] = legendaryImageUri;

        rarityToName[COMMON_RARITY] = COMMON;
        rarityToName[RARE_RARITY] = RARE;
        rarityToName[LEGENDARY_RARITY] = LEGENDARY;
    }

    /// @notice this is how players enter the raffle
    /// @notice they have to pay the entrance fee * the number of players
    /// @notice duplicate entrants are not allowed
    /// @param newPlayers the list of players to enter the raffle
    function enterRaffle(address[] memory newPlayers) public payable {
        // q(-) were custom reverts a thing in 0.7.6 of solidity
        // q what if it's 0?
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            // q(178) resets the players array?
            players.push(newPlayers[i]);
        }

        // Check for duplicates
        // report-written cast the players.lenght into a uint256 playetsLenght = players.lenght
        for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
        // followup if it's an empty array, we still emit an event?
        emit RaffleEnter(newPlayers);
    }

    /// @param playerIndex the index of the player to refund. You can find it externally by calling `getActivePlayerIndex`
    /// @dev This function will allow there to be blank spots in the array
    function refund(uint256 playerIndex) public {
        //  MEV (skipped)
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        payable(msg.sender).sendValue(entranceFee);
        // report-written Reentrancy attack vector -> uploading a variable after the 
        players[playerIndex] = address(0);

        // !! QUE HACEN LOS EVENTS
        // written -low.
        //If an event can be manipulated
        // An event is missing
        // An avent is wrong
        emit RaffleRefunded(playerAddress);
    }

    /// @notice a way to get the index in the array
    /// @param player the address of a player in the raffle
    /// @return the index of the player in the array, if they are not active, it returns 0
    // IMPACT: MEDIUM/LOW
    // LIKELIHOOD: LOW/HIGH
    // Severity: MED/LOW
    function getActivePlayerIndex(address player) external view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return i;
            }
        }
        // q(-) what if the player is at the index 0
        // report-written if the player is at the index 0, it'll return 0 and a player might think they are not active
        return 0;
    }

    /// @notice this function will select a winner and mint a puppy
    /// @notice there must be at least 4 players, and the duration has occurred
    /// @notice the previous winner is stored in the previousWinner variable
    /// @dev we use a hash of on-chain data to generate the random numbers
    /// @dev we reset the active players array after the winner is selected
    /// @dev we send 80% of the funds to the winner, the other 20% goes to the feeAddress
    /// audi Control access: anyone can call
    function selectWinner() external {
        // q(-) does this follow CEI? -> NO
        // report-written
        // q(-) are the duration & start time being set correctly
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
        // report-written
        // fixes: chainlink VRF, Commit Reveal Scheme
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        
        // report-skipped why not just do address(this).balance
        uint256 totalAmountCollected = players.length * entranceFee;
        // q(-) is the 80% correct?
        // maybe precision loss

        // report-written magic numbers -> not good have numbers like that
        // uint256 public constant PRIZE_POOL_PERCENTAGE = 80;
        // uint256 public constant FEE_PERCENTAJE = 20;
        // uint256 public constant POOL_PRECISION = 100;
        //0, 1, 
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
        // e this is the total fees the onwer should be able to collect
        // report-written overflow
        // fixes : Newer version or use bigger uints
        
        //18.446....
        // Convertimos 20e18: 20.000000000000000000
        // a uint64: 1.553255926290448384
        // report-written unsafe cast of uint256 to uint64
        //impact: HIGH
        //LILELIHOOD: MEDIUM
        totalFees = totalFees + uint64(fee); // the cast is weird

        // e when we mint a new puppy NFT, we use the totalSupply as the tokenId 
        // q(191 safeMint) where do we increment the tokenId/totalSupply
        uint256 tokenId = totalSupply();
        


        // We use a different RNG calculate from the winnerIndex to determine rarity
        // written randomness

        // q(?) if our transaction picks a winner and we don't like it... revert?
        // q(?) gas war... 
        // written people can revert the TX till they win
        uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
        if (rarity <= COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity <= COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }

        delete players; //e resetting the players array
        raffleStartTime = block.timestamp; // e resetting the raffle start time
        previousWinner = winner; //vanity, doesn't matter much

        // q(-) can we reenter somewhere? -- NO
        // q(-) what if the winner is a smart contract with a fallback that will fail?
        // report-written the winner wouldn't get the money if theur fallbacl was messed up!
        // IMPACT: MEDIUM
        // LIKELIHOOD: LOW

        (bool success,) = winner.call{value: prizePool}("");
        require(success, "PuppyRaffle: Failed to send prize pool to winner");
        _safeMint(winner, tokenId); 
    }

    /// @notice this function will withdraw the fees to the feeAddress
    /// audi More: When the raffle ends, the onwer can get the 20% of the total amount
    /// audi Control access: Anyone can call but it gonna sent it to feeAddress  
    /// audi Can minimize the gas deleting the variable `feesToWithdraw`
    function withdrawFees() external {
        //.... ?
        // q(-) if the protocol has players somenec can't withdray fees?
        // report-skipped is it dificult to withdraw fees if their are players (MEV)
        // written mishandling ETH!!
        require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;

        // q(-) what if the winner is a smart contract with a fallback that will fail? - it'd fail
        // To ignore a value in slither -> arbitrary-send-eth
        // slither-disable-next-line arbitrary-send-eth
        (bool success,) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
     }

    /// @notice only the owner of the contract can change the feeAddress
    /// @param newFeeAddress the new address to send fees to
    /// report-written Need a if to check if newFeeAddress is null = address(0)
    function changeFeeAddress(address newFeeAddress) external onlyOwner {
        feeAddress = newFeeAddress;
        // skipped missing events?
        emit FeeAddressChanged(newFeeAddress);
    }

    /// @notice this function will return true if the msg.sender is an active player
    // @audit this isnt used anywhere?
    // IMPACT: None
    // LIKELIHOOD: None
    // .. But waste of gas
    function _isActivePlayer() internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }

    /// @notice this could be a constant variable
    function _baseURI() internal pure returns (string memory) {
        return "data:application/json;base64,";
    }

    /// @notice this function will return the URI for the token
    /// @param tokenId the Id of the NFT
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "PuppyRaffle: URI query for nonexistent token");

        uint256 rarity = tokenIdToRarity[tokenId];
        string memory imageURI = rarityToUri[rarity];
        string memory rareName = rarityToName[rarity];

        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name(),
                            '", "description":"An adorable puppy!", ',
                            '"attributes": [{"trait_type": "rarity", "value": ',
                            rareName,
                            '}], "image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }
}
