import streamlit as st
from web3 import Web3
import pandas as pd
import ast
import random
from ABI import *


web3 = Web3(Web3.HTTPProvider((st.secrets['api'])))
address = '0x86935F11C86623deC8a25696E1C19a8659CbF95d'

contract = web3.eth.contract(address=address, abi=abi)

contract2 = web3.eth.contract(address=address, abi=abi2)
contract3 = web3.eth.contract(address=address, abi=abi3)


st.title('AArena')


owner = '0x39292E0157EF646cc9EA65dc48F8F91Cae009EAe'

aa_ids = contract3.functions.allAavegotchisOfOwner(owner).call()
print((aa_ids[0][0]),(aa_ids[0][1]),(aa_ids[0][6]))
ls_gotchis = []
ls_traits =[]
ls_names = []
for id in aa_ids:
    if sum(id[6])==0:
        pass

    else:
        ls_gotchis.append(id[0])
        ls_traits.append(id[6])
        ls_names.append(id[1])



gotchi1 = st.selectbox('Select Gotchi',ls_gotchis)
gotchi2 = st.selectbox('Select Gotchi2',ls_gotchis)
traits = ls_traits[ls_gotchis.index(gotchi1)]
traits2 = ls_traits[ls_gotchis.index(gotchi2)]
st.write(traits,ls_names[ls_gotchis.index(gotchi1)])
st.write(contract.functions.getAavegotchiSvg(ls_gotchis[ls_gotchis.index(gotchi1)]).call(),unsafe_allow_html=True)
st.write(traits2,ls_names[ls_gotchis.index(gotchi2)])
st.write(contract.functions.getAavegotchiSvg(ls_gotchis[ls_gotchis.index(gotchi2)]).call(),unsafe_allow_html=True)
random_numbers = [random.randint(0, 5) for _ in range(100)]
random_direction = [random.randint(0, 1) for _ in range(100)]


import random
import pandas as pd

TRAITS = ('NRG', 'AGG', 'SPK', 'BRN', 'EYES', 'EYEC')

def calculate_damage(attacker_trait, defender_trait, direction):
    if direction == 0:
        attacker_value = attacker_trait
        defender_value = defender_trait
    else:
        attacker_value = defender_trait
        defender_value = attacker_trait

    damage = abs(attacker_value - defender_value)
    return damage



def duel(gotchi1_traits, gotchi2_traits, gotchi1_name, gotchi2_name):
    hp1 = 150
    hp2 = 150
    rounds = []
    while hp1 > 0 and hp2 > 0:# Changed to a fixed number of rounds for example purposes
        direction = random.randint(0, 1)
        trait_name = random.choice(TRAITS)
        trait_index = TRAITS.index(trait_name)

        if direction == 0:
            if gotchi1_traits[trait_index] < gotchi2_traits[trait_index]:
                attacker_traits, defender_traits = gotchi1_traits, gotchi2_traits
                attacker_name, defender_name = gotchi1_name, gotchi2_name
            else:
                attacker_traits, defender_traits = gotchi2_traits, gotchi1_traits
                attacker_name, defender_name = gotchi2_name, gotchi1_name
        else:
            if gotchi1_traits[trait_index] > gotchi2_traits[trait_index]:
                attacker_traits, defender_traits = gotchi1_traits, gotchi2_traits
                attacker_name, defender_name = gotchi1_name, gotchi2_name
            else:
                attacker_traits, defender_traits = gotchi2_traits, gotchi1_traits
                attacker_name, defender_name = gotchi2_name, gotchi1_name

        attacker_trait = attacker_traits[trait_index]
        defender_trait = defender_traits[trait_index]

        trait_direction = 0 if direction == 0 and attacker_trait < defender_trait else 1 if direction == 1 and attacker_trait > defender_trait else 0
        damage = calculate_damage(attacker_trait, defender_trait, trait_direction)

        if damage > 0:
            if attacker_traits == gotchi1_traits:
                hp2 -= damage
                attacker_hp = hp1
                defender_hp = hp2
            else:
                hp1 -= damage
                attacker_hp = hp2
                defender_hp = hp1
        else:
            attacker_hp = hp1
            defender_hp = hp2

        rounds.append([trait_name, trait_direction, attacker_trait, defender_trait, damage, attacker_hp, defender_hp, attacker_name, defender_name])

    if hp1 <= 0 and hp2 <= 0:
        winner = "Tie"
    elif hp1 <= 0:
        winner = "Gotchi2"
    else:
        winner = "Gotchi1"

    return winner, rounds, hp1, hp2
gotchi1_name = ls_names[ls_gotchis.index(gotchi1)]
gotchi2_name = ls_names[ls_gotchis.index(gotchi2)]
if gotchi1_name != gotchi2_name:
        if st.button("Battle!"):
            # Call the `duel` function to simulate a battle
            gotchi1_name = ls_names[ls_gotchis.index(gotchi1)]
            gotchi2_name = ls_names[ls_gotchis.index(gotchi2)]






            winner, rounds, hp1, hp2 = duel(traits, traits2, gotchi1_name, gotchi2_name)

            # Add Gotchi names and HP to the DataFrame
            df = pd.DataFrame(rounds, columns=["Trait", "Direction", "Attacker Trait", "Defender Trait", "Damage","attacker_hp","defender_hp","atacker_name","defender_name"])


            st.table(df)

            if winner == "Gotchi1":
                st.write(f"{gotchi1_name} WINS with {hp1} HP left")
            elif winner == "Gotchi2":
                st.write(f"{gotchi2_name} WINS with {hp2} HP left")
            else:
                st.write("TIE!")
else:
    st.warning('SAME GOTCHIS CANT FIGHT')




