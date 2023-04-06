pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";

interface IAavegotchiDiamond {
    function ownerOf(uint256 _tokenId) external view returns (address);
    function getAavegotchi(uint256 _tokenId) external view returns (string memory, uint256, uint8[6] memory);
}

contract AavegotchiBattle is VRFConsumerBase {
    bytes32 private keyHash;
    uint256 private fee;
    IERC20 public alchemicaToken;
    bytes32[] public openDuels;

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

    struct Duel {
        address player1;
        address player2;
        uint256 aavegotchi1TokenId;
        uint256 aavegotchi2TokenId;
        uint8[6] aavegotchi1Traits;
        uint8[6] aavegotchi2Traits;
        uint256 stake;
        bool active;
        bytes32 requestId;
    }

    mapping(bytes32 => Duel) public duels;

    IAavegotchiDiamond public aavegotchiContract;

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee,
        address _alchemicaToken,
        address _aavegotchiContract
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) public {
        keyHash = _keyHash;
        fee = _fee;
        alchemicaToken = IERC20(_alchemicaToken);
        aavegotchiContract = IAavegotchiDiamond(_aavegotchiContract);
    }

    function createDuel(uint256 _aavegotchiTokenId, uint256 _stake) public returns (bytes32) {
        require(IERC721(aavegotchiContract).ownerOf(_aavegotchiTokenId) == msg.sender, "Only the owner of the Aavegotchi can create a duel");
        bytes32 requestId = requestRandomness(keyHash, fee);

        duels[requestId] = Duel({
            player1: msg.sender,
            player2: address(0),
            aavegotchi1TokenId: _aavegotchiTokenId,
            aavegotchi2TokenId: 0,
            aavegotchi1Traits: getAavegotchiTraits(_aavegotchiTokenId),
            aavegotchi2Traits: [0, 0, 0, 0, 0, 0],
            stake: _stake,
            active: false,
            requestId: requestId
        });

        openDuels.push(requestId);

        return requestId;
    }

    function joinDuel(bytes32 _requestId, uint256 _aavegotchiTokenId) public {
        require(duels[_requestId].player1 != address(0), "Duel not found");
        require(duels[_requestId].player2 == address(0), "Duel already has two players");
        require(duels[_requestId].stake > 0, "Stake amount must be greater than zero");
        require(IERC721(aavegotchiContract).ownerOf(_aavegotchiTokenId) == msg.sender, "Only the owner of the Aavegotchi can join the duel");

        duels[_requestId].player2 = msg.sender;
        duels[_requestId].aavegotchi2TokenId = _aavegotchiTokenId;
        duels[_requestId].aavegotchi2Traits = getAavegotchiTraits(_aavegotchiTokenId);
        duels[_requestId].active = true;

        // Remove requestId from openDuels array
        for (uint256 i = 0; i < openDuels.length; i++) {
            if (openDuels[i] == _requestId) {
                openDuels[i] = openDuels[openDuels.length - 1];
                openDuels.pop();
                break;
            }
        }
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(duels[requestId].player1 != address(0) && duels[requestId].player2 != address(0), "Duel not found or not active");

        (uint8 winner, uint256[2] memory totalDamage) = simulateDuel(
            duels[requestId].aavegotchi1Traits,
            duels[requestId].aavegotchi2Traits,
            randomness
        );

        if (winner == 1) {
            alchemicaToken.transfer(duels[requestId].player1, duels[requestId].stake * 2);
        } else {
            alchemicaToken.transfer(duels[requestId].player2, duels[requestId].stake * 2);
        }

        delete duels[requestId];
    }

    function getOpenDuelsCount() public view returns (uint256) {
        return openDuels.length;
    }

    function getOpenDuelRequestId(uint256 index) public view returns (bytes32) {
        require(index < openDuels.length, "Index out of bounds");
        return openDuels[index];
    }

    function simulateDuel(
        uint8[6] memory traits1,
        uint8[6] memory traits2,
        uint256 randomness
    ) public returns (uint8, uint256[2] memory) {
        uint256 hp1 = 100
        uint256 hp2 = 100;
        uint8 currentRound = 1;
        uint8 randomTraitIndex = uint8(randomness % 6);
        uint8 direction = uint8(randomness % 2);
        uint8 attackerTrait;
        uint8 defenderTrait;
        uint8 currentDamage;

        while (hp1 > 0 && hp2 > 0 && currentRound <= 10) {
            if (direction == 0) {
                attackerTrait = traits1[randomTraitIndex];
                defenderTrait = traits2[randomTraitIndex];
            } else {
                attackerTrait = traits2[randomTraitIndex];
                defenderTrait = traits1[randomTraitIndex];
            }

            currentDamage = calculateDamage(attackerTrait, defenderTrait);
            if (direction == 0) {
                hp2 = (hp2 >= currentDamage) ? hp2 - currentDamage : 0;
            } else {
                hp1 = (hp1 >= currentDamage) ? hp1 - currentDamage : 0;
            }

            emit RoundCompleted(requestId, currentRound, randomTraitIndex, direction, attackerTrait, defenderTrait, currentDamage, hp1, hp2);

            // Next round
            randomTraitIndex = uint8(uint256(keccak256(abi.encode(randomTraitIndex, direction, randomness, currentRound))));
            direction = uint8(uint256(keccak256(abi.encode(direction, randomness, currentRound))));
            currentRound++;
        }

        if (hp1 > 0) {
            return (1, [100 - hp1, 100 - hp2]);
        } else {
            return (2, [100 - hp2, 100 - hp1]);
        }
    }

    function calculateDamage(uint8 attackerTrait, uint8 defenderTrait) internal pure returns (uint8) {
        if (attackerTrait == defenderTrait) {
            return 10;
        } else if ((attackerTrait == 1 && defenderTrait == 3) || (attackerTrait == 2 && defenderTrait == 1) || (attackerTrait == 3 && defenderTrait == 2)) {
            return 20;
        } else {
            return 5;
        }
    }

    function getAavegotchiTraits(uint256 _tokenId) internal view returns (uint8[6] memory) {
        (, , uint8[6] memory traits) = aavegotchiContract.getAavegotchi(_tokenId);
        return traits;
    }
}
}

