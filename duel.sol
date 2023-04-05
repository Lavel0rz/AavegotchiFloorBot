pragma solidity ^0.8.0;

contract GotchiDuel {
    // Define a struct to store the values of a Gotchi's traits
    struct GotchiTraits {
        uint8[6] values;
    }

    // Define an enum to represent the different types of traits
    enum Trait {NRG, AGG, SPK, BRN, EYES, EYEC}

    // Define a constant for the maximum HP of a Gotchi
    uint8 constant MAX_HP = 150;

    // Define a constant array of all possible traits
    Trait[6] constant TRAITS = [Trait.NRG, Trait.AGG, Trait.SPK, Trait.BRN, Trait.EYES, Trait.EYEC];

    /**
     * @dev Given the attacker and defender trait values, and a direction (0 or 1),
     * calculate the amount of damage the attacker should inflict on the defender.
     *
     * @param attackerTrait The value of the attacker's trait
     * @param defenderTrait The value of the defender's trait
     * @param direction The direction of the trait comparison (0 for attacker < defender, 1 for attacker > defender)
     * @return The amount of damage the attacker should inflict on the defender
     */
    function calculateDamage(uint8 attackerTrait, uint8 defenderTrait, uint8 direction) internal pure returns (uint8) {
        uint8 damage;
        if (direction == 0) {
            damage = attackerTrait > defenderTrait ? attackerTrait - defenderTrait : defenderTrait - attackerTrait;
        } else {
            damage = attackerTrait < defenderTrait ? defenderTrait - attackerTrait : attackerTrait - defenderTrait;
        }
        return damage;
    }

    /**
     * @dev Simulate a duel between two Gotchis with the given traits and names.
     * The duel consists of a series of rounds, each of which pits the two Gotchis
     * against each other in a random trait comparison. The winner of each round
     * inflicts damage on the loser, and the duel ends when one Gotchi's HP reaches 0.
     *
     * @param gotchi1Traits The traits of the first Gotchi
     * @param gotchi2Traits The traits of the second Gotchi
     * @param gotchi1Name The name of the first Gotchi
     * @param gotchi2Name The name of the second Gotchi
     * @return A tuple containing the name of the winner, an array of the rounds that took place,
     * and the final HP of both Gotchis (in the order they were given)
     */
    function duel(GotchiTraits memory gotchi1Traits, GotchiTraits memory gotchi2Traits, string memory gotchi1Name, string memory gotchi2Name) public view returns (string memory, bytes32[][] memory, uint8, uint8) {
        // Initialize the HP of both Gotchis to the maximum
        uint8 hp1 = MAX_HP;
        uint8 hp2 = MAX_HP;

        // Initialize an empty array to store the rounds that took place
        bytes32[][] memory rounds = new bytes32[][](0);

        // Loop through rounds until one Gotchi's HP reaches 0
        while (hp1 > 0 && hp2 > 0) {
            // Choose a random direction (0 or 1) and trait for the round
            uint8 direction = uint8(block.timestamp) % 2;
            Trait trait = Trait(uint8(block.difficulty) % 6);

            // Get the trait values of each Gotchi for the chosen trait
            uint8 attackerTrait = gotchi1Traits.values[uint8(trait)];
            uint8 defenderTrait = gotchi2Traits.values[uint8(trait)];

            // Calculate the amount of damage the attacker should inflict on the defender
            uint8 damage = calculateDamage(attackerTrait, defenderTrait, direction);

            // Determine which Gotchi won the round and inflict damage on the loser
            if (damage == 0) {
                // If the damage is 0, the round is a tie and no damage is inflicted
                rounds[rounds.length - 1].push(bytes32(0));
            } else if (direction == 0) {
                // If the direction is 0, the attacker should have a lower trait value than the defender
                if (attackerTrait < defenderTrait) {
                    hp1 = hp1 > damage ? hp1 - damage : 0;
                    rounds[rounds.length - 1].push(keccak256(abi.encodePacked(gotchi2Name, trait, damage)));
                } else {
                    hp2 = hp2 > damage ? hp2 - damage : 0;
                    rounds[rounds.length - 1].push(keccak256(abi.encodePacked(gotchi1Name, trait, damage)));
                }
            } else {
                // If the direction is 1, the attacker should have a higher trait value than the defender
                if (attackerTrait > defenderTrait) {
                    hp1 = hp1 > damage ? hp1 - damage : 0;
                    rounds[rounds.length - 1].push(keccak256(abi.encodePacked(gotchi2Name, trait, damage)));
                } else {
                    hp2 = hp2 > damage ? hp2 - damage : 0;
                    rounds[rounds.length - 1].push(keccak256(abi.encodePacked(gotchi1Name, trait, damage)));
                }
            }

            // If neither Gotchi has lost yet, start a new round
            if (hp1 > 0 && hp2 > 0) {
                rounds.push(new bytes32[](0));
            }
        }

    // Determine the winner of the duel based on which Gotchi has more HP
    string memory winner;
    if (hp1 > hp2) {
        winner = gotchi1Name;
    } else {
        winner = gotchi2Name;
    }

    // Return the winner's name, the rounds that took place, and the final HP of both Gotchis
    return (winner, rounds, hp1, hp2);
}
}
