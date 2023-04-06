pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
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
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        keyHash = _keyHash;
        fee = _fee;
        alchemicaToken = IERC20(_alchemicaToken);
        aavegotchiContract = IAavegotchiDiamond(_aavegotchiContract);
    }

    function createDuel(uint256 _aavegotchiTokenId, uint256 _stake) public returns (bytes32) {
        require(IERC721(aavegotchiContract).ownerOf(_aavegotchiTokenId) == msg.sender, "Only the owner of the Aavegotchi can create a duel");
        bytes32 requestId = requestRandomness(keyHash, fee);

        Duel storage newDuel = duels[requestId];
        newDuel.player1 = msg.sender;
        newDuel.aavegotchi1TokenId = _aavegotchiTokenId;
        newDuel.aavegotchi1Traits = getAavegotchiTraits(_aavegotchiTokenId);
        newDuel.stake = _stake;
        newDuel.active = false;
        newDuel.requestId = requestId;

        openDuels.push(requestId);

        return requestId;
    }
    function joinDuel(bytes32 _requestId, uint256 _aavegotchiTokenId) public {
    Duel storage duel = duels[_requestId];
    require(duel.player1 != address(0), "Duel not found");
    require(duel.player2 == address(0), "Duel already has two players");
    require(duel.stake > 0, "Stake amount must be greater than zero");
    require(IERC721(aavegotchiContract).ownerOf(_aavegotchiTokenId) == msg.sender, "Only the owner of the Aavegotchi can join the duel");
    require(alchemicaToken.balanceOf(msg.sender) >= duel.stake, "Insufficient Alchemica balance");

    // Calculate the fee amounts
    uint256 devFee = duel.stake / 40; // 2.5%
    uint256 burnFee = duel.stake / 40; // 2.5%
    uint256 totalFee = devFee + burnFee;

    // Transfer the fee amounts to the dev and burn addresses
    alchemicaToken.transfer(devAddress, devFee);
    alchemicaToken.transfer(burnAddress, burnFee);

    // Transfer the remaining stake to the contract
    alchemicaToken.transferFrom(msg.sender, address(this), duel.stake - totalFee);

    duel.player2 = msg.sender;
    duel.aavegotchi2TokenId = _aavegotchiTokenId;
    duel.aavegotchi2Traits = getAavegotchiTraits(_aavegotchiTokenId);
    duel.active = true;

    // Remove requestId from openDuels array
    for (uint256 i = 0; i < openDuels.length; i++) {
        if (openDuels[i] == _requestId) {
            openDuels[i] = openDuels[openDuels.length - 1];
            openDuels.pop();
            break;
        }
    }

    bytes32 requestId = duels[_requestId].requestId;
    require(requestId != 0, "Invalid request ID");
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK to fulfill randomness request");
    require(duel.active, "Duel is not active");
    require(!duel.resolved, "Duel has already been resolved");

    uint256 randomSeed = uint256(keccak256(abi.encodePacked(requestId, block.number, block.timestamp)));

    bytes32 _requestId = requestRandomness(keyHash, fee, randomSeed);
    requestIdToDuelId[_requestId] = _requestId;

    emit RequestedRandomness(_requestId);
}

function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
    Duel storage duel = duels[requestId];
    require(duel.player1 != address(0) && duel.player2 != address(0), "Duel not found or not active");

    // Fix: use a local variable to store the winner
    uint8 winner;

    (winner, duel.totalDamage) = simulateDuel(
        duel.aavegotchi1Traits,
        duel.aavegotchi2Traits,
        randomness
    );

    if (winner == 1) {
        alchemicaToken.transfer(duel.player1, duel.stake * 2);
    } else {
        alchemicaToken.transfer(duel.player2, duel.stake * 2);
    }

    emit RoundCompleted(
        requestId,
        duel.currentRound,
        duel.randomTraitIndex,
        duel.direction,
        duel.attackerTrait,
        duel.defenderTrait,
        duel.currentDamage,
        duel.hp1,
        duel.hp2
    );

    delete duels[requestId];
}

function simulateDuel(
    uint8[6] memory traits1,
    uint8[6] memory traits2,
    uint256 randomness
) public pure returns (uint8, uint256[2] memory) {
    uint256 hp1 = 100;
    uint256 hp2 = 100;
    uint8 currentRound = 1;
    uint8 attackerTrait;
    uint8 defenderTrait;
    uint8 currentDamage;
    uint256[2] memory totalDamage;

    while (hp1 > 0 && hp2 > 0 && currentRound <= 10) {
        uint8 randomTraitIndex = uint8(randomness % 6);
        randomness = uint256(keccak256(abi.encode(randomness)));

        uint8 direction = uint8(randomness % 2);
        randomness = uint256(keccak256(abi.encode(randomness)));

        if (direction == 0) {
            if (traits1[randomTraitIndex] < traits2[randomTraitIndex]) {
                attackerTrait = traits1[randomTraitIndex];
                defenderTrait = traits2[randomTraitIndex];
            } else {
                attackerTrait = traits2[randomTraitIndex];
                defenderTrait = traits1[randomTraitIndex];
            }
        } else {
            if (traits1[randomTraitIndex] > traits2[randomTraitIndex]) {
                attackerTrait = traits1[randomTraitIndex];
                defenderTrait = traits2[randomTraitIndex];
            } else {
                attackerTrait = traits2[randomTraitIndex];
                defenderTrait = traits1[randomTraitIndex];
            }
        }

        currentDamage = calculateDamage(attackerTrait, defenderTrait);

        if (direction == 0) {
            hp2 = (hp2 >= currentDamage) ? hp2 - currentDamage : 0;
        } else {
            hp1 = (hp1 >= currentDamage) ? hp1 - currentDamage : 0;
        }

        totalDamage[direction] += currentDamage;

        // Next round
        currentRound++;
    }

    if (hp1 > hp2) {
        return (1, totalDamage);
    } else {
        return (2, totalDamage);
    }
}

function calculateDamage(uint8 attackerTrait, uint8 defenderTrait) internal pure returns (uint8) {
                return abs(int(attackerTrait) - int(defenderTrait));
            }

function cancelDuel(bytes32 _requestId) public {
    Duel storage duel = duels[_requestId];
    require(duel.player1 == msg.sender, "Only the creator of the duel can cancel it");
    require(!duel.active, "Duel is already active");

    alchemicaToken.transfer(duel.player1, duel.stake);

    // Remove requestId from openDuels array
    for (uint256 i = 0; i < openDuels.length; i++) {
        if (openDuels[i] == _requestId) {
            openDuels[i] = openDuels[openDuels.length - 1];
            openDuels.pop();
            break;
        }
    }

    delete duels[_requestId];
}

function abs(int x) internal pure returns (uint8) {
    return x >= 0 ? uint8(x) : uint8(-x);
}

    function getAavegotchiTraits(uint256 _tokenId) internal view returns (uint8[6] memory) {
        (, , uint8[6] memory traits) = aavegotchiContract.getAavegotchi(_tokenId);
        return traits;
    }
}
}


