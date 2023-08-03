import streamlit as st
from web3 import Web3
import pandas as pd
import ast
import random
from ABI import *
import time
from PIL import Image
import numpy as np
import io
import cairosvg
web3 = Web3(Web3.HTTPProvider((st.secrets['api'])))
address = '0x86935F11C86623deC8a25696E1C19a8659CbF95d'

contract = web3.eth.contract(address=address, abi=abi)

contract2 = web3.eth.contract(address=address, abi=abi2)
contract3 = web3.eth.contract(address=address, abi=abi3)


st.title('AArena')

st.markdown('''In this game, two Aavegotchis battle against each other using their six traits: NRG, AGG, SPK, BRN, EYES, and EYEC. Each trait has a value between 0 and 99 (can exceed with wearables).

During the battle, a random trait is selected, and the Aavegotchi with the higher value in that trait becomes the attacker. However, the direction of the attack is also randomly determined. If the direction is 1, the Aavegotchi with the higher value in the selected trait is the attacker, while if the direction is 0, the Aavegotchi with the lower value in the selected trait is the attacker.

The damage dealt by the attack is calculated as the absolute difference between the attacker's and defender's trait values. The Aavegotchi that receives the damage will lose health points (HP) equal to the damage dealt. The battle continues in this way, with a new trait and direction randomly selected each round, until one of the Aavegotchis has no more HP remaining.

The Aavegotchi that wins the battle is the one with remaining HP.''')
from PIL import Image
owner = '0x39292E0157EF646cc9EA65dc48F8F91Cae009EAe'
import numpy as np
aa_ids = contract3.functions.allAavegotchisOfOwner(owner).call()
ls_gotchis = []
ls_traits = []
ls_names = []
for id in aa_ids:
    if sum(id[6]) == 0:
        pass
    else:
        ls_gotchis.append(id[0])
        ls_traits.append(id[6])
        ls_names.append(id[1])

gotchi1 = st.selectbox('Select Gotchi', ls_gotchis)
gotchi2 = st.selectbox('Select Gotchi2', ls_gotchis)
traits = ls_traits[ls_gotchis.index(gotchi1)]
traits2 = ls_traits[ls_gotchis.index(gotchi2)]
st.write(traits, ls_names[ls_gotchis.index(gotchi1)])
st.image(contract.functions.getAavegotchiSvg(ls_gotchis[ls_gotchis.index(gotchi1)]).call())
st.write(traits2, ls_names[ls_gotchis.index(gotchi2)])
st.image(contract.functions.getAavegotchiSvg(ls_gotchis[ls_gotchis.index(gotchi2)]).call())

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
import io
import cairosvg
def display_round_results(df):
    st.write("### Battle Round Results")
    st.table(df)


def display_winner(winner, hp1, hp2):
    if winner == "Gotchi1":
        st.success(f"{gotchi1_name} WINS with {hp1} HP left")
    elif winner == "Gotchi2":
        st.success(f"{gotchi2_name} WINS with {hp2} HP left")
    else:
        st.warning("TIE!")


def display_round(round_data):
    st.write(f"## Round {round_data['Round']} - {round_data['attacker_name']} vs {round_data['defender_name']}")
    st.write(f"Trait: {round_data['Trait']} (Direction: {'↑' if round_data['Direction'] == 1 else '↓'})")
    st.write(f"Attacker Trait: {round_data['Attacker Trait']}, Defender Trait: {round_data['Defender Trait']}")
    st.write(f"Damage: {round_data['Damage']}")

    # Get Aavegotchi token IDs
    attacker_id = ls_gotchis[ls_names.index(round_data['attacker_name'])]
    defender_id = ls_gotchis[ls_names.index(round_data['defender_name'])]

    # Load SVG images as strings
    attacker_svg = contract.functions.getAavegotchiSvg(attacker_id).call()
    defender_svg = contract.functions.getAavegotchiSvg(defender_id).call()

    # Convert SVG to PNG using cairosvg
    attacker_png = svg_to_png(attacker_svg)
    defender_png = svg_to_png(defender_svg)

    # Overlay health bars
    combined_attacker_image = overlay_health_bar(attacker_png, round_data['attacker_hp'], round_data['Damage'])
    combined_defender_image = overlay_health_bar(defender_png, round_data['defender_hp'], round_data['Damage'])

    # Resize images to make them smaller
    image_size = (150, 150)
    combined_attacker_image = combined_attacker_image.resize(image_size)
    combined_defender_image = combined_defender_image.resize(image_size)

    # Arrange images in columns using st.columns
    col1, col2 = st.columns(2)
    with col1:
        st.image(combined_attacker_image, caption=round_data['attacker_name'], use_column_width=True)
        st.write(f"HP: {round_data['attacker_hp']}")
    with col2:
        st.image(combined_defender_image, caption=round_data['defender_name'], use_column_width=True)
        st.write(f"HP: {round_data['defender_hp']}")

    st.write("---")

# Function to convert SVG to PNG using cairosvg
def svg_to_png(svg_str):
    png_bytes = cairosvg.svg2png(bytestring=svg_str)
    return png_bytes

# Function to overlay health bar on the image
def overlay_health_bar(image_bytes, hp, damage):
    with Image.open(io.BytesIO(image_bytes)) as img:
        img = img.convert("RGBA")

        # Create health bar image
        health_bar_height = 10
        total_hp = 150  # Total HP is 150 in this case
        attacker_health = max(0, hp) / total_hp
        hp_after_damage = max(0, hp - damage) / total_hp

        health_bar_image = Image.new('RGBA', (150, health_bar_height), color='green')
        health_bar_image.paste((255, 0, 0, 255), [0, 0, int(attacker_health * 150), health_bar_height])
        health_bar_image.paste((0, 255, 0, 255), [int(attacker_health * 150), 0, int(hp_after_damage * 150), health_bar_height])

        # Resize health bar image to match Aavegotchi image size
        health_bar_image = health_bar_image.resize((img.width, health_bar_height))

        # Convert images to arrays
        np_img = np.array(img)
        np_health_bar = np.array(health_bar_image)

        # Overlay the health bar image on the Aavegotchi image using NumPy
        np_combined_img = np.copy(np_img)
        np_combined_img[:health_bar_height, :img.width] = np_health_bar

        return Image.fromarray(np_combined_img)
def duel(gotchi1_traits, gotchi2_traits, gotchi1_name, gotchi2_name):
    hp1 = 150
    hp2 = 150
    rounds = []
    while hp1 > 0 and hp2 > 0:
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

        # Clamp HP values to stay within 0 to 150
        attacker_hp = max(0, min(150, attacker_hp))
        defender_hp = max(0, min(150, defender_hp))

        rounds.append({
            "Round": len(rounds) + 1,
            "Trait": trait_name,
            "Direction": direction,
            "Attacker Trait": attacker_trait,
            "Defender Trait": defender_trait,
            "Damage": damage,
            "attacker_hp": attacker_hp,
            "defender_hp": defender_hp,
            "attacker_name": attacker_name,
            "defender_name": defender_name
        })

        display_round(rounds[-1])
        time.sleep(1)  # Adjust the sleep time (in seconds) to control the pause between each round

    if hp1 <= 0 and hp2 <= 0:
        winner = "Tie"
    elif hp1 <= 0:
        winner = "Gotchi2"
    else:
        winner = "Gotchi1"

    return winner, rounds, hp1, hp2


def main():
    global gotchi1_name, gotchi2_name  # Declare the variables as global

    gotchi1_name = ls_names[ls_gotchis.index(gotchi1)]
    gotchi2_name = ls_names[ls_gotchis.index(gotchi2)]

    if gotchi1_name != gotchi2_name:
        if st.button("Battle!"):
            winner, rounds, hp1, hp2 = duel(traits, traits2, gotchi1_name, gotchi2_name)
            df = pd.DataFrame(rounds,
                              columns=["Round", "Trait", "Direction", "Attacker Trait", "Defender Trait", "Damage",
                                       "attacker_hp", "defender_hp", "attacker_name", "defender_name"])
            df["Direction"] = df["Direction"].apply(lambda x: "↑" if x == 1 else "↓")

            display_round_results(df)
            display_winner(winner, hp1, hp2)
    else:
        st.warning('SAME GOTCHIS CANT FIGHT')


if __name__ == "__main__":
    main()
