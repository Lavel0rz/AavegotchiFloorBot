// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract DuelGame is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    uint256 public hp1 = 150;
    uint256 public hp2 = 150;
    uint256 public round = 0;
    uint256 public maxRounds = 10;
    string public gotchi1_name;
    string public gotchi2_name;
    uint256[] public random_numbers;
    uint256[] public random_directions;

       struct Round {
        uint256 attacker_trait;
        uint256 defender_trait;
        uint256 attacker_damage;
        uint256 random_number;
        uint256 random_direction;
        string attacker_name;
        string defender_name;
    }

    struct Duel {
        uint256 id;
        uint256 maxRounds;
        string gotchi1_name;
        string gotchi2_name;
        uint256[] random_numbers;
        uint256[] random_directions;
        Round[] rounds;
    }

    mapping(uint256 => Duel) public duels;
    uint256 public totalDuels = 0;

    function createDuel(string memory _gotchi1_name, string memory _gotchi2_name, uint256 _maxRounds) public returns (uint256) {
        totalDuels++;
        uint256[] memory emptyNumbers;
        uint256[] memory emptyDirections;
        Round[] memory emptyRounds;
        Duel memory newDuel = Duel(totalDuels, _maxRounds, _gotchi1_name, _gotchi2_name, emptyNumbers, emptyDirections, emptyRounds);
        duels[totalDuels] = newDuel;
        return totalDuels;
    }

     function addRound(uint256 _duelId, uint256 _attacker_trait, uint256 _defender_trait, uint256 _attacker_damage, uint256 _random_number, uint256 _random_direction, string memory _attacker_name, string memory _defender_name) public {
        Duel storage duel = duels[_duelId];
        require(duel.random_numbers.length > 0, "Random numbers not added yet.");
        require(duel.rounds.length < duel.maxRounds, "Maximum rounds reached.");
        Round memory newRound = Round(_attacker_trait, _defender_trait, _attacker_damage, _random_number, _random_direction, _attacker_name, _defender_name);
        duel.rounds.push(newRound);
    }

    function getRound(uint256 _duelId, uint256 _roundNumber) public view returns (Round memory) {
        Duel storage duel = duels[_duelId];
        require(_roundNumber > 0 && _roundNumber <= duel.rounds.length, "Invalid round number.");
        return duel.rounds[_roundNumber - 1];
    }

    event Winner(string winner, uint256 hp1, uint256 hp2);

    constructor(address vrfCoordinator, address link, bytes32 _keyHash, uint256 _fee) VRFConsumerBase(vrfCoordinator, link) {
        keyHash = _keyHash;
        fee = _fee;
    }

    function setGotchiNames(string memory _gotchi1_name, string memory _gotchi2_name) public {
        gotchi1_name = _gotchi1_name;
        gotchi2_name = _gotchi2_name;
    }

    function requestRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK to make the request.");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        // Convert the randomResult into an array of 100 numbers between 0 and 5
        for (uint256 i = 0; i < 100; i++) {
            uint256 randomNumber = uint256(keccak256(abi.encode(randomResult, i))) % 6;
            random_numbers.push(randomNumber);
        }
        // Convert the randomResult into an array of 100 numbers between 0 and 1
        for (uint256 i = 0; i < 100; i++) {
            uint256 randomDirection = uint256(keccak256(abi.encode(randomResult, i + 100))) % 2;
            random_directions.push(randomDirection);
        }
    }

    function duel(uint256[] memory gotchi1_traits, uint256[] memory gotchi2_traits) public {
    require(random_numbers.length == 100 && random_directions.length == 100, "Random numbers not generated yet.");
    require(round < maxRounds, "Maximum rounds reached.");
    round++;
    uint256 direction = random_directions[round-1];
    uint256 trait_index = uint256(keccak256(abi.encode(randomResult, round + 200))) % 6;
    uint256[] memory attacker_traits;
    uint256[] memory defender_traits;
    string memory attacker_name;
    string memory defender_name;

    if (direction == 0) {
        if (gotchi1_traits[trait_index] < gotchi2_traits[trait_index]) {
            attacker_traits = gotchi1_traits;
            defender_traits = gotchi2_traits;
            attacker_name = gotchi1_name;
            defender_name = gotchi2_name;
        } else {
            attacker_traits = gotchi2_traits;
            defender_traits = gotchi1_traits;
            attacker_name = gotchi2_name;
            defender_name = gotchi1_name;
        }
    } else {
        if (gotchi1_traits[trait_index] > gotchi2_traits[trait_index]) {
            attacker_traits = gotchi1_traits;
            defender_traits = gotchi2_traits;
            attacker_name = gotchi1_name;
            defender_name = gotchi2_name;
        } else {
            attacker_traits = gotchi2_traits;
            defender_traits = gotchi1_traits;
            attacker_name = gotchi2_name;
            defender_name = gotchi1_name;
        }
    }

    uint256 damage = random_numbers[round-1] * attacker_traits[trait_index];
    hp2 = hp2 > damage ? hp2 - damage : 0;

    emit Winner(hp2 == 0 ? attacker_name : defender_name, hp1, hp2);
}
}



