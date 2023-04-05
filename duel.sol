pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract AavegotchiBattle is VRFConsumerBase {
    bytes32 private keyHash;
    uint256 private fee;
    IERC20 public alchemicaToken;


    struct Aavegotchi {
        uint256 id;
        string name;
        uint8[6] traits;
    }

    struct Duel {
        address player1;
        address player2;
        Aavegotchi aavegotchi1;
        Aavegotchi aavegotchi2;
        uint256 stake;
        bool active;
        bytes32 requestId;
    }

    mapping(address => Aavegotchi) public aavegotchis;
    mapping(bytes32 => Duel) public duels;

   constructor(
    address _vrfCoordinator,
    address _linkToken,
    bytes32 _keyHash,
    uint256 _fee,
    address _alchemicaToken
) VRFConsumerBase(_vrfCoordinator, _linkToken) public {
    keyHash = _keyHash;
    fee = _fee;
    alchemicaToken = IERC20(_alchemicaToken);
}


    function createAavegotchi(uint256 id, string memory name, uint8[6] memory traits) public {
        aavegotchis[msg.sender] = Aavegotchi(id, name, traits);
    }

    function createDuel(uint256 stake) public returns (bytes32) {
        require(aavegotchis[msg.sender].id != 0, "Aavegotchi not found for the player");

        bytes32 requestId = requestRandomness(keyHash, fee);
        duels[requestId] = Duel(msg.sender, address(0), aavegotchis[msg.sender], Aavegotchi(0, "", [uint8(0), 0, 0, 0, 0, 0]), stake, false, requestId);
        return requestId;
    }

    function joinDuel(bytes32 requestId, uint256 stake) public {
        require(duels[requestId].player1 != address(0), "Duel not found");
        require(duels[requestId].player2 == address(0), "Duel already has two players");
        require(duels[requestId].stake == stake, "Stake amount does not match");
        require(aavegotchis[msg.sender].id != 0, "Aavegotchi not found for the player");

        duels[requestId].player2 = msg.sender;
        duels[requestId].aavegotchi2 = aavegotchis[msg.sender];
        duels[requestId].active = true;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(duels[requestId].player1 != address(0) && duels[requestId].player2 != address(0), "Duel not found or not active");

        // Use the randomness to simulate the duel and determine the winner
        (uint8 winner, uint8[6] memory damage) = simulateDuel(duels[requestId].aavegotchi1.traits, duels[requestId].aavegotchi2.traits, randomness);

        // Distribute the stake to the winner
        if (winner == 1) {
    // Player 1 wins
    alchemicaToken.transferFrom(duels[requestId].player2, duels[requestId].player1, duels[requestId].stake);
} else if (winner == 2) {
    // Player 2 wins
    alchemicaToken.transferFrom(duels[requestId].player1, duels[requestId].player2, duels[requestId].stake);
} else {
    // Tie - return the staked tokens to both players
}

        // Remove the duel from the mapping
        delete duels[requestId];
    }
    function simulateDuel(uint8[6] memory traits1, uint8[6] memory traits2, uint256 randomness) private pure returns (uint8, uint8[6] memory) {
    uint8[6] memory damage;
    uint8[6] memory totalDamage;
    uint8 winner = 0;
    uint256 hp1 = 150;
    uint256 hp2 = 150;

    // Use the randomness value to generate random numbers
    uint256 seed = randomness;

    for (uint8 i = 0; i < 100 && hp1 > 0 && hp2 > 0; i++) {
        uint256 randomValue = uint256(keccak256(abi.encodePacked(seed, i)));
        uint8 randomTraitIndex = uint8(randomValue % 6);

        uint256 randomDirectionValue = uint256(keccak256(abi.encodePacked(seed, i + 100)));
        uint8 direction = uint8(randomDirectionValue % 2);

        uint8 attackerTrait = direction == 0 ? traits1[randomTraitIndex] : traits2[randomTraitIndex];
        uint8 defenderTrait = direction == 0 ? traits2[randomTraitIndex] : traits1[randomTraitIndex];

        uint8 currentDamage = attackerTrait > defenderTrait ? attackerTrait - defenderTrait : defenderTrait - attackerTrait;
        damage[randomTraitIndex] += currentDamage;

        if (direction == 0) {
            hp2 -= currentDamage;
        } else {
            hp1 -= currentDamage;
        }
    }

    if (hp1 > 0 && hp2 > 0) {
        winner = 0; // Tie
    } else if (hp1 > 0) {
        winner = 1; // Gotchi1 wins
    } else {
        winner = 2; // Gotchi2 wins
    }

    totalDamage = damage;

    return (winner, totalDamage);
}
}
