https://lavel0rz-aavegotchifloorbot-main-67bhg2.streamlit.app/

In this game, two Aavegotchis battle against each other using their six traits: NRG, AGG, SPK, BRN, EYES, and EYEC. Each trait has a value between 0 and 99(can exceed with wearables).

During the battle, a random trait is selected, and the Aavegotchi with the higher value in that trait becomes the attacker. However, the direction of the attack is also randomly determined. If the direction is 1, the Aavegotchi with the higher value in the selected trait is the attacker, while if the direction is 0, the Aavegotchi with the lower value in the selected trait is the attacker.

The damage dealt by the attack is calculated as the absolute difference between the attacker's and defender's trait values. The Aavegotchi that receives the damage will lose health points (HP) equal to the damage dealt. The battle continues in this way, with a new trait and direction randomly selected each round, until one of the Aavegotchis has no more HP remaining.

The Aavegotchi that wins the battle is the one with remaining HP.
