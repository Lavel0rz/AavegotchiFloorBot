pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract AavegotchiBattle is VRFConsumerBase {
    bytes32 private keyHash;
    uint256 private fee;
    IERC20 public alchemicaToken;

    event RoundCompleted(
        bytes32 indexed requestId,
        uint8 round,
        uint8 indexed randomTraitIndex,
        uint8 indexed direction,
        uint8 attackerTrait,
        uint8 defenderTrait,
        uint8 currentDamage,
        uint256 hp1,
        uint256 hp2
    );

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

        (uint8 winner, uint8[6] memory damage) = simulateDuel(
            duels[requestId].aavegotchi1.traits,
            duels[requestId].aavegotchi2.traits,
            randomness
        );

        if (winner == 1) {
            alchemicaToken.transfer(duels[requestId].player1, duels[requestId].stake * 2);
        } else {
            alchemicaToken.transfer(duels[requestId].player2, duels[requestId].stake * 2);
        }

        delete duels[requestId];
    }

    function simulateDuel(
        uint8[6] memory traits1,
        uint8[6] memory traits2,
        uint256 randomness
    ) public returns (uint8, uint8[6] memory) {
        uint256 hp1 = 100;
        uint256 hp2 = 100;
        uint8[6] memory damage = [0, 0, 0, 0, 0, 0];

        for (uint8 round = 0; round < 6; round++) {
            uint8 randomTraitIndex = uint8((randomness % 6) + round) % 6;
            uint8 direction = uint8(((randomness >> (round * 8)) % 2) * 2 - 1);

            uint8 attackerTrait;
            uint8 defenderTrait;

            if (direction == 1) {
                attackerTrait = traits1[randomTraitIndex];
                defenderTrait = traits2[randomTraitIndex];
            } else {
                attackerTrait = traits2[randomTraitIndex];
                defenderTrait = traits1[randomTraitIndex];
            }

            uint8 currentDamage = attackerTrait > defenderTrait ? attackerTrait - defenderTrait : 0;

            if (direction == 1) {
                hp2 -= currentDamage;
            } else {
                hp1 -= currentDamage;
            }

            damage[randomTraitIndex] += currentDamage;

            emit RoundCompleted(
                requestId,
                round,
                randomTraitIndex,
                direction,
                attackerTrait,
                defenderTrait,
                currentDamage,
                hp1,
                hp2
            );

            if (hp1 == 0 || hp2 == 0) {
                break;
            }
        }

        return (hp1 > hp2 ? 1 : 2, damage);
    }
}
