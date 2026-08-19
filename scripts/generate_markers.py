#!/usr/bin/env python3
"""Generate 12 ARKit-friendly black-and-white marker PNGs and a 10cm US Letter print PDF."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas as pdfcanvas

ROOT = Path(__file__).resolve().parents[1]
MARKER_DIR = ROOT / "Resources" / "Markers"
PRINT_DIR = ROOT / "printables"
CONTENT_DIR = ROOT / "Resources"
SIZE = 1024
COUNT = 24
OBJECTS_PER_ROUND = 24
DEFAULT_MARKER_COUNT = 12
PHYSICAL_CM = 10.0

ROUNDS = [
    {
        "id": "animals",
        "title": "Animals",
        "targets": ["elephant", "dog", "cat", "bird"],
        "objects": [
            ("elephant", "🐘"),
            ("dog", "🐕"),
            ("cat", "🐈"),
            ("bird", "🐦"),
            ("lion", "🦁"),
            ("tiger", "🐅"),
            ("bear", "🐻"),
            ("horse", "🐴"),
            ("cow", "🐄"),
            ("pig", "🐖"),
            ("sheep", "🐑"),
            ("rabbit", "🐇"),
            ("fox", "🦊"),
            ("wolf", "🐺"),
            ("deer", "🦌"),
            ("giraffe", "🦒"),
            ("zebra", "🦓"),
            ("monkey", "🐒"),
            ("penguin", "🐧"),
            ("frog", "🐸"),
            ("snake", "🐍"),
            ("turtle", "🐢"),
            ("fish", "🐟"),
            ("owl", "🦉"),
        ],
    },
    {
        "id": "land-vehicles",
        "title": "Land Vehicles",
        "targets": ["car", "bus", "motorcycle", "train"],
        "objects": [
            ("car", "🚗"),
            ("bus", "🚌"),
            ("motorcycle", "🏍️"),
            ("train", "🚆"),
            ("truck", "🚚"),
            ("van", "🚐"),
            ("taxi", "🚕"),
            ("tractor", "🚜"),
            ("ambulance", "🚑"),
            ("fire truck", "🚒"),
            ("police car", "🚓"),
            ("bicycle", "🚲"),
            ("scooter", "🛴"),
            ("pickup", "🛻"),
            ("racecar", "🏎️"),
            ("bulldozer", "🚜"),
            ("dump truck", "🚛"),
            ("ATV", "🛵"),
            ("limousine", "🚘"),
            ("RV", "🚐"),
            ("jeep", "🚙"),
            ("tank", "🛡️"),
            ("go-kart", "🏎️"),
            ("subway", "🚇"),
        ],
    },
    {
        "id": "water-vehicles",
        "title": "Water Vehicles",
        "targets": ["sailboat", "motorboat", "canoe", "submarine"],
        "objects": [
            ("sailboat", "⛵"),
            ("motorboat", "🚤"),
            ("canoe", "🛶"),
            ("submarine", "🚢"),
            ("kayak", "🛶"),
            ("yacht", "🛥️"),
            ("ferry", "⛴️"),
            ("cruise ship", "🛳️"),
            ("jet ski", "🏄"),
            ("raft", "🛟"),
            ("tugboat", "🚢"),
            ("speedboat", "🚤"),
            ("rowboat", "🚣"),
            ("catamaran", "⛵"),
            ("hovercraft", "🚢"),
            ("fishing boat", "🎣"),
            ("gondola", "🛶"),
            ("pirate ship", "🏴‍☠️"),
            ("aircraft carrier", "🚢"),
            ("paddleboat", "🛳️"),
            ("barge", "🚢"),
            ("destroyer", "🚢"),
            ("dinghy", "🚤"),
            ("paddle steamer", "🚢"),
        ],
    },
    {
        "id": "air-vehicles",
        "title": "Air Vehicles",
        "targets": ["airplane", "helicopter", "hot air balloon", "rocket"],
        "objects": [
            ("airplane", "✈️"),
            ("helicopter", "🚁"),
            ("hot air balloon", "🎈"),
            ("rocket", "🚀"),
            ("glider", "🪂"),
            ("jet", "🛩️"),
            ("blimp", "🎈"),
            ("seaplane", "✈️"),
            ("drone", "🛸"),
            ("hang glider", "🪂"),
            ("space shuttle", "🚀"),
            ("biplane", "🛩️"),
            ("airliner", "✈️"),
            ("cargo plane", "✈️"),
            ("kite", "🪁"),
            ("parachute", "🪂"),
            ("UFO", "🛸"),
            ("stealth jet", "🛩️"),
            ("weather balloon", "🎈"),
            ("gyrocopter", "🚁"),
            ("tiltrotor", "🚁"),
            ("paper airplane", "📄"),
            ("fighter", "🛩️"),
            ("autogyro", "🚁"),
        ],
    },
    {
        "id": "balls",
        "title": "Kinds of Balls",
        "targets": ["soccer", "basketball", "tennis", "baseball"],
        "objects": [
            ("soccer", "⚽"),
            ("basketball", "🏀"),
            ("tennis", "🎾"),
            ("baseball", "⚾"),
            ("football", "🏈"),
            ("volleyball", "🏐"),
            ("golf", "⛳"),
            ("bowling", "🎳"),
            ("rugby", "🏉"),
            ("ping pong", "🏓"),
            ("billiard", "🎱"),
            ("beach ball", "🏖️"),
            ("cricket", "🏏"),
            ("softball", "🥎"),
            ("water polo", "🤽"),
            ("kickball", "🔴"),
            ("wiffle", "⚪"),
            ("bocce", "🟢"),
            ("lacrosse", "🥍"),
            ("squash", "🟡"),
            ("marble", "🔮"),
            ("playground ball", "🟠"),
            ("yoga ball", "🟣"),
            ("medicine ball", "🟤"),
        ],
    },
    {
        "id": "trees-plants",
        "title": "Trees / Plants",
        "targets": ["pine", "oak", "cactus", "flower"],
        "objects": [
            ("pine", "🌲"),
            ("oak", "🌳"),
            ("cactus", "🌵"),
            ("flower", "🌸"),
            ("palm", "🌴"),
            ("maple", "🍁"),
            ("willow", "🌿"),
            ("bamboo", "🎋"),
            ("sunflower", "🌻"),
            ("rose", "🌹"),
            ("tulip", "🌷"),
            ("fern", "🌿"),
            ("bonsai", "🪴"),
            ("sequoia", "🌲"),
            ("birch", "🌳"),
            ("succulent", "🪴"),
            ("daisy", "🌼"),
            ("lily", "🌺"),
            ("ivy", "🌿"),
            ("apple tree", "🍎"),
            ("cherry blossom", "🍒"),
            ("corn", "🌽"),
            ("cactus barrel", "🌵"),
            ("mushroom", "🍄"),
        ],
    },
    {
        "id": "fruits",
        "title": "Fruits",
        "targets": ["apple", "banana", "grape", "strawberry"],
        "objects": [
            ("apple", "🍎"),
            ("banana", "🍌"),
            ("grape", "🍇"),
            ("strawberry", "🍓"),
            ("orange", "🍊"),
            ("watermelon", "🍉"),
            ("pear", "🍐"),
            ("peach", "🍑"),
            ("cherry", "🍒"),
            ("lemon", "🍋"),
            ("pineapple", "🍍"),
            ("blueberry", "🫐"),
            ("kiwi", "🥝"),
            ("mango", "🥭"),
        ],
    },
    {
        "id": "vegetables",
        "title": "Vegetables",
        "targets": ["carrot", "broccoli", "corn", "tomato"],
        "objects": [
            ("carrot", "🥕"),
            ("broccoli", "🥦"),
            ("corn", "🌽"),
            ("tomato", "🍅"),
            ("peas", "🫛"),
            ("potato", "🥔"),
            ("cucumber", "🥒"),
            ("pepper", "🫑"),
            ("lettuce", "🥬"),
            ("onion", "🧅"),
            ("mushroom", "🍄"),
            ("pumpkin", "🎃"),
            ("eggplant", "🍆"),
            ("avocado", "🥑"),
        ],
    },
    {
        "id": "yummy-snacks",
        "title": "Yummy Snacks",
        "targets": ["pizza", "cookie", "ice cream", "cupcake"],
        "objects": [
            ("pizza", "🍕"),
            ("cookie", "🍪"),
            ("ice cream", "🍦"),
            ("cupcake", "🧁"),
            ("donut", "🍩"),
            ("popcorn", "🍿"),
            ("sandwich", "🥪"),
            ("hot dog", "🌭"),
            ("pretzel", "🥨"),
            ("candy", "🍬"),
            ("chocolate", "🍫"),
            ("pancake", "🥞"),
            ("waffle", "🧇"),
            ("cheese", "🧀"),
        ],
    },
    {
        "id": "toys",
        "title": "Toys",
        "targets": ["teddy bear", "blocks", "doll", "toy car"],
        "objects": [
            ("teddy bear", "🧸"),
            ("blocks", "🧱"),
            ("doll", "🪆"),
            ("toy car", "🚗"),
            ("balloon", "🎈"),
            ("kite", "🪁"),
            ("puzzle", "🧩"),
            ("yo-yo", "🪀"),
            ("robot toy", "🤖"),
            ("train toy", "🚂"),
            ("crayons", "🖍️"),
            ("stuffed bunny", "🐰"),
            ("play dough", "🟡"),
            ("marbles", "🔵"),
        ],
    },
    {
        "id": "weather",
        "title": "Weather",
        "targets": ["sun", "rain", "snow", "rainbow"],
        "objects": [
            ("sun", "☀️"),
            ("rain", "🌧️"),
            ("snow", "❄️"),
            ("rainbow", "🌈"),
            ("cloud", "☁️"),
            ("lightning", "⚡"),
            ("wind", "💨"),
            ("fog", "🌫️"),
            ("storm", "⛈️"),
            ("moon", "🌙"),
            ("star", "⭐"),
            ("tornado", "🌪️"),
            ("hail", "🧊"),
            ("sunset", "🌅"),
        ],
    },
    {
        "id": "kitchen",
        "title": "In the Kitchen",
        "targets": ["cup", "spoon", "bowl", "plate"],
        "objects": [
            ("cup", "🥤"),
            ("spoon", "🥄"),
            ("bowl", "🥣"),
            ("plate", "🍽️"),
            ("fork", "🍴"),
            ("knife", "🔪"),
            ("pot", "🍲"),
            ("pan", "🍳"),
            ("kettle", "🫖"),
            ("toaster", "🍞"),
            ("fridge", "🧊"),
            ("oven", "🔥"),
            ("blender", "🌀"),
            ("microwave", "📦"),
        ],
    },
    {
        "id": "clothes",
        "title": "Clothes",
        "targets": ["hat", "shoes", "shirt", "pants"],
        "objects": [
            ("hat", "🧢"),
            ("shoes", "👟"),
            ("shirt", "👕"),
            ("pants", "👖"),
            ("socks", "🧦"),
            ("coat", "🧥"),
            ("dress", "👗"),
            ("gloves", "🧤"),
            ("scarf", "🧣"),
            ("boots", "🥾"),
            ("pajamas", "🛏️"),
            ("raincoat", "🌧️"),
            ("glasses", "👓"),
            ("backpack", "🎒"),
        ],
    },
    {
        "id": "instruments",
        "title": "Musical Instruments",
        "targets": ["drum", "guitar", "piano", "trumpet"],
        "objects": [
            ("drum", "🥁"),
            ("guitar", "🎸"),
            ("piano", "🎹"),
            ("trumpet", "🎺"),
            ("violin", "🎻"),
            ("flute", "🪈"),
            ("xylophone", "🎵"),
            ("maracas", "🪇"),
            ("microphone", "🎤"),
            ("harp", "🎶"),
            ("accordion", "🪗"),
            ("bells", "🔔"),
            ("tambourine", "🪘"),
            ("saxophone", "🎷"),
        ],
    },
    {
        "id": "bugs",
        "title": "Bugs",
        "targets": ["butterfly", "ladybug", "bee", "ant"],
        "objects": [
            ("butterfly", "🦋"),
            ("ladybug", "🐞"),
            ("bee", "🐝"),
            ("ant", "🐜"),
            ("spider", "🕷️"),
            ("snail", "🐌"),
            ("worm", "🪱"),
            ("grasshopper", "🦗"),
            ("beetle", "🪲"),
            ("dragonfly", "🪽"),
            ("caterpillar", "🐛"),
            ("firefly", "✨"),
            ("cricket", "🦗"),
            ("mosquito", "🦟"),
        ],
    },
    {
        "id": "dinosaurs",
        "title": "Dinosaurs",
        "targets": ["t-rex", "triceratops", "stegosaurus", "brachiosaurus"],
        "objects": [
            ("t-rex", "🦖"),
            ("triceratops", "🦕"),
            ("stegosaurus", "🦕"),
            ("brachiosaurus", "🦕"),
            ("velociraptor", "🦖"),
            ("pterodactyl", "🦅"),
            ("ankylosaurus", "🦕"),
            ("diplodocus", "🦕"),
            ("spinosaurus", "🦖"),
            ("parasaurolophus", "🦕"),
            ("allosaurus", "🦖"),
            ("iguanodon", "🦕"),
            ("fossil", "🦴"),
            ("dino egg", "🥚"),
            ("carnotaurus", "🦖"),
            ("brontosaurus", "🦕"),
            ("compsognathus", "🦖"),
            ("pachycephalosaurus", "🦕"),
            ("archaeopteryx", "🐦"),
            ("gallimimus", "🦕"),
            ("dimetrodon", "🦎"),
            ("mosasaurus", "🐋"),
            ("dino footprint", "👣"),
            ("dino skeleton", "🦴"),
        ],
    },
    {
        "id": "wild-cats",
        "title": "Wild Cats",
        "targets": ["lion", "tiger", "cheetah", "leopard"],
        "objects": [
            ("lion", "🦁"),
            ("tiger", "🐅"),
            ("cheetah", "🐆"),
            ("leopard", "🐆"),
            ("jaguar", "🐆"),
            ("cougar", "🐱"),
            ("puma", "🐱"),
            ("lynx", "🐱"),
            ("bobcat", "🐱"),
            ("ocelot", "🐱"),
            ("serval", "🐱"),
            ("caracal", "🐱"),
            ("snow leopard", "🐆"),
            ("clouded leopard", "🐆"),
            ("margay", "🐱"),
            ("sand cat", "🐱"),
            ("fishing cat", "🐱"),
            ("black panther", "🐈‍⬛"),
            ("wildcat", "🐱"),
            ("jungle cat", "🐱"),
            ("kodkod", "🐱"),
            ("pallas cat", "🐱"),
            ("iberian lynx", "🐱"),
            ("manul", "🐱"),
        ],
    },
    {
        "id": "ice-age-animals",
        "title": "Ice Age Animals",
        "targets": ["mammoth", "saber-tooth", "ground sloth", "woolly rhino"],
        "objects": [
            ("mammoth", "🦣"),
            ("saber-tooth", "🐯"),
            ("ground sloth", "🦥"),
            ("woolly rhino", "🦏"),
            ("cave bear", "🐻"),
            ("dire wolf", "🐺"),
            ("mastodon", "🦣"),
            ("cave lion", "🦁"),
            ("giant beaver", "🦫"),
            ("glyptodont", "🐢"),
            ("cave hyena", "🐺"),
            ("irish elk", "🦌"),
            ("musk ox", "🐂"),
            ("bison", "🦬"),
            ("woolly mammoth calf", "🦣"),
            ("short-faced bear", "🐻"),
            ("prehistoric horse", "🐴"),
            ("cave painting", "🎨"),
            ("fossil bone", "🦴"),
            ("tar pit", "🛢️"),
            ("glacier", "🏔️"),
            ("snowflake", "❄️"),
            ("tundra", "🏔️"),
            ("ice sheet", "🧊"),
        ],
    },
    {
        "id": "apex-predators",
        "title": "Apex Predators",
        "targets": ["great white shark", "orca", "grizzly bear", "saltwater crocodile"],
        "objects": [
            ("great white shark", "🦈"),
            ("orca", "🐋"),
            ("grizzly bear", "🐻"),
            ("saltwater crocodile", "🐊"),
            ("lion", "🦁"),
            ("tiger", "🐅"),
            ("polar bear", "🐻‍❄️"),
            ("wolf", "🐺"),
            ("komodo dragon", "🦎"),
            ("python", "🐍"),
            ("anaconda", "🐍"),
            ("leopard", "🐆"),
            ("jaguar", "🐆"),
            ("eagle", "🦅"),
            ("hawk", "🦅"),
            ("peregrine falcon", "🦅"),
            ("barracuda", "🐟"),
            ("hyena", "🐺"),
            ("cheetah", "🐆"),
            ("alligator", "🐊"),
            ("black mamba", "🐍"),
            ("wolverine", "🦡"),
            ("osprey", "🦅"),
            ("king cobra", "🐍"),
        ],
    },
    {
        "id": "ocean-giants",
        "title": "Ocean Giants",
        "targets": ["blue whale", "humpback whale", "whale shark", "giant squid"],
        "objects": [
            ("blue whale", "🐋"),
            ("humpback whale", "🐋"),
            ("whale shark", "🦈"),
            ("giant squid", "🦑"),
            ("sperm whale", "🐋"),
            ("orca", "🐋"),
            ("great white shark", "🦈"),
            ("manta ray", "🐟"),
            ("narwhal", "🦄"),
            ("beluga whale", "🐋"),
            ("dolphin", "🐬"),
            ("octopus", "🐙"),
            ("sea turtle", "🐢"),
            ("walrus", "🦭"),
            ("elephant seal", "🦭"),
            ("hammerhead shark", "🦈"),
            ("stingray", "🐟"),
            ("jellyfish", "🪼"),
            ("coral reef", "🪸"),
            ("seaweed", "🌿"),
            ("starfish", "⭐"),
            ("lobster", "🦞"),
            ("crab", "🦀"),
            ("anglerfish", "🐟"),
        ],
    },
    {
        "id": "birds-of-prey",
        "title": "Birds of Prey",
        "targets": ["eagle", "hawk", "owl", "falcon"],
        "objects": [
            ("eagle", "🦅"),
            ("hawk", "🦅"),
            ("owl", "🦉"),
            ("falcon", "🦅"),
            ("bald eagle", "🦅"),
            ("golden eagle", "🦅"),
            ("red-tailed hawk", "🦅"),
            ("peregrine falcon", "🦅"),
            ("barn owl", "🦉"),
            ("snowy owl", "🦉"),
            ("osprey", "🦅"),
            ("vulture", "🦅"),
            ("condor", "🦅"),
            ("kestrel", "🦅"),
            ("harrier", "🦅"),
            ("buzzard", "🦅"),
            ("secretary bird", "🦅"),
            ("horned owl", "🦉"),
            ("screech owl", "🦉"),
            ("kite", "🦅"),
            ("great horned owl", "🦉"),
            ("merlin", "🦅"),
            ("goshawk", "🦅"),
            ("talon", "🦴"),
        ],
    },
    {
        "id": "rainforest-animals",
        "title": "Rainforest Animals",
        "targets": ["jaguar", "toucan", "sloth", "monkey"],
        "objects": [
            ("jaguar", "🐆"),
            ("toucan", "🦜"),
            ("sloth", "🦥"),
            ("monkey", "🐒"),
            ("parrot", "🦜"),
            ("macaw", "🦜"),
            ("gorilla", "🦍"),
            ("chameleon", "🦎"),
            ("poison dart frog", "🐸"),
            ("tree frog", "🐸"),
            ("anaconda", "🐍"),
            ("capybara", "🐹"),
            ("anteater", "🐜"),
            ("tapir", "🐗"),
            ("ocelot", "🐱"),
            ("hummingbird", "🐦"),
            ("butterfly", "🦋"),
            ("leaf cutter ant", "🐜"),
            ("iguana", "🦎"),
            ("piranha", "🐟"),
            ("howler monkey", "🐒"),
            ("rainforest tree", "🌳"),
            ("orchid", "🌸"),
            ("banana", "🍌"),
        ],
    },
    {
        "id": "farm-animals",
        "title": "Farm Animals",
        "targets": ["cow", "pig", "chicken", "horse"],
        "objects": [
            ("cow", "🐄"),
            ("pig", "🐖"),
            ("chicken", "🐔"),
            ("horse", "🐴"),
            ("sheep", "🐑"),
            ("goat", "🐐"),
            ("duck", "🦆"),
            ("rooster", "🐓"),
            ("turkey", "🦃"),
            ("donkey", "🫏"),
            ("llama", "🦙"),
            ("alpaca", "🦙"),
            ("goose", "🪿"),
            ("rabbit", "🐇"),
            ("farm dog", "🐕"),
            ("farm cat", "🐈"),
            ("bee", "🐝"),
            ("barn", "🏚️"),
            ("tractor", "🚜"),
            ("hay bale", "🌾"),
            ("milk", "🥛"),
            ("egg", "🥚"),
            ("corn", "🌽"),
            ("farmer", "👨‍🌾"),
        ],
    },
    {
        "id": "pets",
        "title": "Pets",
        "targets": ["dog", "cat", "hamster", "goldfish"],
        "objects": [
            ("dog", "🐕"),
            ("cat", "🐈"),
            ("hamster", "🐹"),
            ("goldfish", "🐠"),
            ("puppy", "🐶"),
            ("kitten", "🐱"),
            ("parrot", "🦜"),
            ("guinea pig", "🐹"),
            ("turtle", "🐢"),
            ("rabbit", "🐇"),
            ("ferret", "🦡"),
            ("gecko", "🦎"),
            ("betta fish", "🐟"),
            ("hermit crab", "🦀"),
            ("chinchilla", "🐭"),
            ("budgie", "🐦"),
            ("cockatiel", "🐦"),
            ("bearded dragon", "🦎"),
            ("pet mouse", "🐭"),
            ("pet snake", "🐍"),
            ("pet bed", "🛏️"),
            ("food bowl", "🥣"),
            ("leash", "🦮"),
            ("dog bone", "🦴"),
        ],
    },
    {
        "id": "desert-animals",
        "title": "Desert Animals",
        "targets": ["camel", "scorpion", "rattlesnake", "coyote"],
        "objects": [
            ("camel", "🐫"),
            ("scorpion", "🦂"),
            ("rattlesnake", "🐍"),
            ("coyote", "🐺"),
            ("fennec fox", "🦊"),
            ("roadrunner", "🐦"),
            ("horned lizard", "🦎"),
            ("desert tortoise", "🐢"),
            ("jackrabbit", "🐇"),
            ("meerkat", "🦝"),
            ("vulture", "🦅"),
            ("desert gecko", "🦎"),
            ("sand dune", "🏜️"),
            ("cactus", "🌵"),
            ("oasis", "🏝️"),
            ("sandstorm", "🌪️"),
            ("desert sun", "☀️"),
            ("tumbleweed", "🌿"),
            ("kangaroo rat", "🐭"),
            ("gila monster", "🦎"),
            ("bobcat", "🐱"),
            ("desert eagle", "🦅"),
            ("desert beetle", "🪲"),
            ("tarantula", "🕷️"),
        ],
    },
    {
        "id": "arctic-animals",
        "title": "Arctic Animals",
        "targets": ["polar bear", "penguin", "walrus", "seal"],
        "objects": [
            ("polar bear", "🐻‍❄️"),
            ("penguin", "🐧"),
            ("walrus", "🦭"),
            ("seal", "🦭"),
            ("arctic fox", "🦊"),
            ("snowy owl", "🦉"),
            ("reindeer", "🦌"),
            ("musk ox", "🐂"),
            ("beluga", "🐋"),
            ("narwhal", "🦄"),
            ("orca", "🐋"),
            ("puffin", "🐦"),
            ("ermine", "🐭"),
            ("lemming", "🐭"),
            ("husky", "🐕"),
            ("igloo", "🏠"),
            ("iceberg", "🧊"),
            ("aurora", "🌌"),
            ("snow", "❄️"),
            ("blizzard", "🌨️"),
            ("arctic fish", "🐟"),
            ("caribou", "🦌"),
            ("arctic wolf", "🐺"),
            ("snow hare", "🐇"),
        ],
    },
    {
        "id": "african-safari",
        "title": "African Safari",
        "targets": ["elephant", "giraffe", "zebra", "lion"],
        "objects": [
            ("elephant", "🐘"),
            ("giraffe", "🦒"),
            ("zebra", "🦓"),
            ("lion", "🦁"),
            ("rhino", "🦏"),
            ("hippo", "🦛"),
            ("cheetah", "🐆"),
            ("leopard", "🐆"),
            ("buffalo", "🐃"),
            ("wildebeest", "🦬"),
            ("gazelle", "🦌"),
            ("ostrich", "🦩"),
            ("hyena", "🐺"),
            ("warthog", "🐗"),
            ("meerkat", "🦝"),
            ("baboon", "🐒"),
            ("crocodile", "🐊"),
            ("vulture", "🦅"),
            ("acacia tree", "🌳"),
            ("baobab tree", "🌳"),
            ("watering hole", "💧"),
            ("termite mound", "🪨"),
            ("safari jeep", "🚙"),
            ("flamingo", "🦩"),
        ],
    },
    {
        "id": "under-the-sea",
        "title": "Under the Sea",
        "targets": ["clownfish", "sea turtle", "starfish", "seahorse"],
        "objects": [
            ("clownfish", "🐠"),
            ("sea turtle", "🐢"),
            ("starfish", "⭐"),
            ("seahorse", "🐚"),
            ("dolphin", "🐬"),
            ("octopus", "🐙"),
            ("jellyfish", "🪼"),
            ("crab", "🦀"),
            ("lobster", "🦞"),
            ("stingray", "🐟"),
            ("coral", "🪸"),
            ("seaweed", "🌿"),
            ("pufferfish", "🐡"),
            ("anglerfish", "🐟"),
            ("eel", "🐍"),
            ("shrimp", "🦐"),
            ("squid", "🦑"),
            ("clam", "🐚"),
            ("pearl", "🦪"),
            ("sea anemone", "🪸"),
            ("sand dollar", "🐚"),
            ("treasure chest", "🧰"),
            ("submarine", "🚤"),
            ("whale", "🐋"),
        ],
    },
    {
        "id": "reptiles",
        "title": "Reptiles",
        "targets": ["snake", "lizard", "turtle", "crocodile"],
        "objects": [
            ("snake", "🐍"),
            ("lizard", "🦎"),
            ("turtle", "🐢"),
            ("crocodile", "🐊"),
            ("gecko", "🦎"),
            ("chameleon", "🦎"),
            ("iguana", "🦎"),
            ("alligator", "🐊"),
            ("tortoise", "🐢"),
            ("komodo dragon", "🦎"),
            ("python", "🐍"),
            ("cobra", "🐍"),
            ("rattlesnake", "🐍"),
            ("anaconda", "🐍"),
            ("bearded dragon", "🦎"),
            ("monitor lizard", "🦎"),
            ("gila monster", "🦎"),
            ("skink", "🦎"),
            ("salamander", "🦎"),
            ("frog", "🐸"),
            ("toad", "🐸"),
            ("newt", "🦎"),
            ("dino fossil", "🦴"),
            ("egg", "🥚"),
        ],
    },
    {
        "id": "baby-animals",
        "title": "Baby Animals",
        "targets": ["puppy", "kitten", "chick", "calf"],
        "objects": [
            ("puppy", "🐶"),
            ("kitten", "🐱"),
            ("chick", "🐤"),
            ("calf", "🐮"),
            ("lamb", "🐑"),
            ("piglet", "🐷"),
            ("duckling", "🐥"),
            ("foal", "🐴"),
            ("bunny", "🐇"),
            ("bear cub", "🐻"),
            ("joey", "🦘"),
            ("fawn", "🦌"),
            ("kid goat", "🐐"),
            ("owlet", "🦉"),
            ("tadpole", "🐸"),
            ("caterpillar", "🐛"),
            ("elephant calf", "🐘"),
            ("zebra foal", "🦓"),
            ("giraffe calf", "🦒"),
            ("penguin chick", "🐧"),
            ("seal pup", "🦭"),
            ("whale calf", "🐋"),
            ("turtle hatchling", "🐢"),
            ("lion cub", "🦁"),
        ],
    },
    {
        "id": "nocturnal-animals",
        "title": "Nocturnal Animals",
        "targets": ["owl", "bat", "raccoon", "firefly"],
        "objects": [
            ("owl", "🦉"),
            ("bat", "🦇"),
            ("raccoon", "🦝"),
            ("firefly", "✨"),
            ("hedgehog", "🦔"),
            ("moth", "🦋"),
            ("wolf", "🐺"),
            ("fox", "🦊"),
            ("badger", "🦡"),
            ("opossum", "🦝"),
            ("skunk", "🦨"),
            ("cricket", "🦗"),
            ("nighthawk", "🐦"),
            ("lemur", "🐒"),
            ("tarsier", "🐒"),
            ("mouse", "🐭"),
            ("cat", "🐈"),
            ("moon", "🌙"),
            ("stars", "⭐"),
            ("night sky", "🌌"),
            ("coyote", "🐺"),
            ("porcupine", "🦔"),
            ("kiwi bird", "🐦"),
            ("nightjar", "🐦"),
        ],
    },
    {
        "id": "volcanoes-around-the-world",
        "title": "Volcanoes Around the World",
        "targets": ["Mount Fuji", "Vesuvius", "Krakatoa", "Kilauea"],
        "objects": [
            ("Mount Fuji", "🗻"),
            ("Vesuvius", "🌋"),
            ("Krakatoa", "🌋"),
            ("Kilauea", "🌋"),
            ("Mauna Loa", "🌋"),
            ("Mount Etna", "🌋"),
            ("Mount St Helens", "🌋"),
            ("Yellowstone", "🌋"),
            ("Mount Rainier", "🗻"),
            ("Cotopaxi", "🌋"),
            ("Mount Kilimanjaro", "🗻"),
            ("Popocatepetl", "🌋"),
            ("Sakurajima", "🌋"),
            ("Eyjafjallajokull", "🌋"),
            ("Mount Nyiragongo", "🌋"),
            ("lava flow", "🌋"),
            ("ash cloud", "🌫️"),
            ("volcanic crater", "🕳️"),
            ("geyser", "♨️"),
            ("caldera", "🕳️"),
            ("Pompeii ruins", "🏛️"),
            ("Hawaii", "🏝️"),
            ("volcanic island", "🏝️"),
            ("magma", "🔥"),
        ],
    },
    {
        "id": "deep-sea-creatures",
        "title": "Deep Sea Creatures",
        "targets": ["anglerfish", "blobfish", "vampire squid", "gulper eel"],
        "objects": [
            ("anglerfish", "🐟"),
            ("blobfish", "🐟"),
            ("vampire squid", "🦑"),
            ("gulper eel", "🐍"),
            ("dumbo octopus", "🐙"),
            ("frilled shark", "🦈"),
            ("barreleye fish", "🐟"),
            ("dragonfish", "🐟"),
            ("sea pig", "🐷"),
            ("yeti crab", "🦀"),
            ("giant isopod", "🪲"),
            ("black swallower", "🐟"),
            ("stoplight loosejaw", "🐟"),
            ("tripod fish", "🐟"),
            ("snailfish", "🐟"),
            ("comb jelly", "🪼"),
            ("deep sea jellyfish", "🪼"),
            ("lanternfish", "🐟"),
            ("viperfish", "🐟"),
            ("fangtooth", "🐟"),
            ("hatchetfish", "🐟"),
            ("sea angel", "🪽"),
            ("black smoker worm", "🪱"),
            ("hydrothermal vent", "♨️"),
        ],
    },
    {
        "id": "carnivorous-plants",
        "title": "Carnivorous Plants",
        "targets": ["venus flytrap", "pitcher plant", "sundew", "bladderwort"],
        "objects": [
            ("venus flytrap", "🪴"),
            ("pitcher plant", "🪴"),
            ("sundew", "🌿"),
            ("bladderwort", "🌿"),
            ("cobra lily", "🪴"),
            ("butterwort", "🌸"),
            ("waterwheel plant", "🌿"),
            ("albany pitcher", "🪴"),
            ("monkey cup", "🪴"),
            ("rainbow plant", "🌿"),
            ("flypaper trap", "🪴"),
            ("snap trap", "🪴"),
            ("pitfall trap", "🪴"),
            ("bladder trap", "🌿"),
            ("sticky sundew", "🌿"),
            ("purple pitcher", "🪴"),
            ("tropical pitcher", "🪴"),
            ("forked sundew", "🌿"),
            ("fly", "🪰"),
            ("mosquito", "🦟"),
            ("ant", "🐜"),
            ("spider", "🕷️"),
            ("beetle", "🪲"),
            ("swamp moss", "🌿"),
        ],
    },
    {
        "id": "living-fossils",
        "title": "Living Fossils",
        "targets": ["coelacanth", "horseshoe crab", "nautilus", "tuatara"],
        "objects": [
            ("coelacanth", "🐟"),
            ("horseshoe crab", "🦀"),
            ("nautilus", "🐚"),
            ("tuatara", "🦎"),
            ("lungfish", "🐟"),
            ("ginkgo tree", "🌳"),
            ("fern", "🌿"),
            ("sturgeon", "🐟"),
            ("elephant shrew", "🐭"),
            ("sandhill crane", "🦩"),
            ("crocodile", "🐊"),
            ("alligator gar", "🐟"),
            ("chambered nautilus", "🐚"),
            ("fossil shell", "🐚"),
            ("ammonite", "🐚"),
            ("trilobite", "🦂"),
            ("ancient fern", "🌿"),
            ("primitive fish", "🐟"),
            ("living rock", "🪨"),
            ("deep time", "⏳"),
            ("museum fossil", "🦴"),
            ("petrified wood", "🪵"),
            ("amber", "🟡"),
            ("prehistoric fern", "🌿"),
        ],
    },
    {
        "id": "bioluminescent-life",
        "title": "Bioluminescent Life",
        "targets": ["firefly", "glow worm", "firefly squid", "bioluminescent jellyfish"],
        "objects": [
            ("firefly", "✨"),
            ("glow worm", "🪱"),
            ("firefly squid", "🦑"),
            ("bioluminescent jellyfish", "🪼"),
            ("lanternfish", "🐟"),
            ("anglerfish lure", "💡"),
            ("comb jelly", "🪼"),
            ("deep sea shrimp", "🦐"),
            ("click beetle", "🪲"),
            ("mycena mushroom", "🍄"),
            ("foxfire fungus", "🍄"),
            ("sea sparkle", "✨"),
            ("dinoflagellate", "🦠"),
            ("glow plankton", "✨"),
            ("night sea", "🌊"),
            ("glowing coral", "🪸"),
            ("flashlight fish", "🐟"),
            ("railroad worm", "🪱"),
            ("glow snail", "🐌"),
            ("bioluminescent algae", "🌿"),
            ("night forest", "🌲"),
            ("starlight", "⭐"),
            ("moon jelly", "🪼"),
            ("glow cave", "🕳️"),
        ],
    },
    {
        "id": "peculiar-animals",
        "title": "Peculiar Animals",
        "targets": ["axolotl", "platypus", "pangolin", "aye-aye"],
        "objects": [
            ("axolotl", "🦎"),
            ("platypus", "🦫"),
            ("pangolin", "🦔"),
            ("aye-aye", "🐒"),
            ("okapi", "🦓"),
            ("narwhal", "🦄"),
            ("tapir", "🐗"),
            ("echidna", "🦔"),
            ("kakapo", "🦜"),
            ("shoebill", "🦩"),
            ("proboscis monkey", "🐒"),
            ("star-nosed mole", "🐭"),
            ("mantis shrimp", "🦐"),
            ("tardigrade", "🦠"),
            ("leafy seadragon", "🐉"),
            ("sun bear", "🐻"),
            ("saiga antelope", "🦌"),
            ("markhor", "🐐"),
            ("flying lemur", "🐿️"),
            ("numbat", "🐜"),
            ("spider crab", "🦀"),
            ("blobfish", "🐟"),
            ("mudskipper", "🐟"),
            ("secretary bird", "🦅"),
        ],
    },
    {
        "id": "extreme-survivors",
        "title": "Extreme Survivors",
        "targets": ["tardigrade", "camel", "cactus", "polar bear"],
        "objects": [
            ("tardigrade", "🦠"),
            ("camel", "🐫"),
            ("cactus", "🌵"),
            ("polar bear", "🐻‍❄️"),
            ("desert tortoise", "🐢"),
            ("emperor penguin", "🐧"),
            ("deep sea worm", "🪱"),
            ("lichen", "🌿"),
            ("mangrove tree", "🌳"),
            ("alpine ibex", "🐐"),
            ("arctic tern", "🐦"),
            ("volcano bacteria", "🦠"),
            ("hot spring algae", "🌿"),
            ("salt flat shrimp", "🦐"),
            ("ice worm", "🪱"),
            ("blind cave fish", "🐟"),
            ("vulture", "🦅"),
            ("cockroach", "🪳"),
            ("crocodile", "🐊"),
            ("komodo dragon", "🦎"),
            ("deep freeze", "🧊"),
            ("desert sun", "☀️"),
            ("volcano rim", "🌋"),
            ("ocean trench", "🌊"),
        ],
    },
    {
        "id": "infamous-shipwrecks",
        "title": "Infamous Shipwrecks",
        "targets": ["Titanic", "Lusitania", "Mary Rose", "Vasa"],
        "objects": [
            ("Titanic", "🚢"),
            ("Lusitania", "🚢"),
            ("Mary Rose", "⛵"),
            ("Vasa", "🚢"),
            ("Andrea Doria", "🚢"),
            ("USS Arizona", "🚢"),
            ("SS Edmund Fitzgerald", "🚢"),
            ("Whydah Gally", "🏴‍☠️"),
            ("Queen Anne's Revenge", "🏴‍☠️"),
            ("HMS Victory", "⚓"),
            ("submarine wreck", "🚢"),
            ("treasure chest", "🧰"),
            ("anchor", "⚓"),
            ("diving helmet", "🤿"),
            ("coral reef", "🪸"),
            ("ship bell", "🔔"),
            ("barnacles", "🦀"),
            ("ocean floor", "🌊"),
            ("lifeboat", "🛟"),
            ("compass", "🧭"),
            ("sea map", "🗺️"),
            ("maritime museum", "🏛️"),
            ("storm waves", "🌊"),
            ("shipwreck diver", "🤿"),
        ],
    },
    {
        "id": "famous-pirates",
        "title": "Famous Pirates",
        "targets": ["Blackbeard", "Anne Bonny", "Captain Kidd", "Barbarossa"],
        "objects": [
            ("Blackbeard", "🏴‍☠️"),
            ("Anne Bonny", "🏴‍☠️"),
            ("Captain Kidd", "🏴‍☠️"),
            ("Barbarossa", "🏴‍☠️"),
            ("Calico Jack", "🏴‍☠️"),
            ("Mary Read", "🏴‍☠️"),
            ("Henry Morgan", "🏴‍☠️"),
            ("Grace O'Malley", "🏴‍☠️"),
            ("Ching Shih", "🏴‍☠️"),
            ("pirate flag", "🏴‍☠️"),
            ("treasure map", "🗺️"),
            ("cutlass", "⚔️"),
            ("parrot", "🦜"),
            ("pirate ship", "⛵"),
            ("cannon", "💣"),
            ("doubloon", "🪙"),
            ("Caribbean sea", "🌴"),
            ("Tortuga", "🏝️"),
            ("Nassau", "🏝️"),
            ("crow's nest", "🪺"),
            ("Jolly Roger", "🏴‍☠️"),
            ("spyglass", "🔭"),
            ("rum barrel", "🛢️"),
            ("plank", "🪵"),
        ],
    },
    {
        "id": "legendary-explorers",
        "title": "Legendary Explorers",
        "targets": ["Magellan", "Columbus", "Shackleton", "Amelia Earhart"],
        "objects": [
            ("Magellan", "🧭"),
            ("Columbus", "⛵"),
            ("Shackleton", "🐧"),
            ("Amelia Earhart", "✈️"),
            ("Marco Polo", "🐫"),
            ("Lewis and Clark", "🛶"),
            ("Roald Amundsen", "🧊"),
            ("Neil Armstrong", "🚀"),
            ("Jacques Cousteau", "🤿"),
            ("Sacagawea", "🦬"),
            ("compass", "🧭"),
            ("sextant", "📐"),
            ("expedition map", "🗺️"),
            ("expedition tent", "⛺"),
            ("sled dogs", "🐕"),
            ("sailing ship", "⛵"),
            ("expedition plane", "✈️"),
            ("moon landing", "🌙"),
            ("desert caravan", "🐫"),
            ("North Pole", "🧊"),
            ("South Pole", "🐧"),
            ("telescope", "🔭"),
            ("explorer journal", "📓"),
            ("mountain peak", "🏔️"),
        ],
    },
    {
        "id": "ancient-wonders",
        "title": "Ancient Wonders",
        "targets": ["Great Pyramid", "Colosseum", "Stonehenge", "Great Wall"],
        "objects": [
            ("Great Pyramid", "🔺"),
            ("Colosseum", "🏛️"),
            ("Stonehenge", "🪨"),
            ("Great Wall", "🧱"),
            ("Parthenon", "🏛️"),
            ("Machu Picchu", "🏔️"),
            ("Petra", "🏜️"),
            ("Taj Mahal", "🕌"),
            ("Angkor Wat", "🛕"),
            ("Easter Island moai", "🗿"),
            ("Sphinx", "🦁"),
            ("Acropolis", "🏛️"),
            ("Roman aqueduct", "🏛️"),
            ("Terracotta Army", "🪖"),
            ("Chichen Itza", "🛕"),
            ("Hagia Sophia", "🕌"),
            ("Leaning Tower", "🗼"),
            ("ancient temple", "🛕"),
            ("marble column", "🏛️"),
            ("mosaic floor", "🎨"),
            ("amphora", "🏺"),
            ("desert monument", "🏜️"),
            ("ancient statue", "🗿"),
            ("ruined arch", "🏛️"),
        ],
    },
    {
        "id": "lost-cities",
        "title": "Lost Cities",
        "targets": ["Pompeii", "Petra", "Machu Picchu", "Tikal"],
        "objects": [
            ("Pompeii", "🏛️"),
            ("Petra", "🏜️"),
            ("Machu Picchu", "🏔️"),
            ("Tikal", "🌳"),
            ("Atlantis", "🌊"),
            ("Babylon", "🏺"),
            ("Troy", "🛡️"),
            ("El Dorado", "🌟"),
            ("Aztec ruins", "🛕"),
            ("Mayan pyramid", "🛕"),
            ("underwater city", "🌊"),
            ("desert ruins", "🏜️"),
            ("jungle temple", "🌿"),
            ("buried treasure", "🧰"),
            ("archaeologist hat", "🎩"),
            ("ancient map", "🗺️"),
            ("stone tablet", "📜"),
            ("cave painting", "🎨"),
            ("sandstorm", "🌪️"),
            ("vine wall", "🌿"),
            ("crumbled column", "🏛️"),
            ("lost civilization", "⏳"),
            ("excavation site", "⛏️"),
            ("hidden doorway", "🚪"),
        ],
    },
]

# Hunts published via remote manifest only (app appends by round id).
# Author here, then: python scripts/generate_markers.py --remote-only
REMOTE_ROUNDS: list[dict] = [
    {
        "id": "country-flags",
        "title": "Country Flags",
        "targets": ["United States", "Japan", "Brazil", "France"],
        "objects": [
            ("United States", "🇺🇸"),
            ("Japan", "🇯🇵"),
            ("Brazil", "🇧🇷"),
            ("France", "🇫🇷"),
            ("Canada", "🇨🇦"),
            ("Mexico", "🇲🇽"),
            ("United Kingdom", "🇬🇧"),
            ("Germany", "🇩🇪"),
            ("Italy", "🇮🇹"),
            ("Spain", "🇪🇸"),
            ("Australia", "🇦🇺"),
            ("India", "🇮🇳"),
            ("China", "🇨🇳"),
            ("South Korea", "🇰🇷"),
            ("South Africa", "🇿🇦"),
            ("Argentina", "🇦🇷"),
            ("Sweden", "🇸🇪"),
            ("Norway", "🇳🇴"),
            ("Ireland", "🇮🇪"),
            ("Greece", "🇬🇷"),
            ("Turkey", "🇹🇷"),
            ("Egypt", "🇪🇬"),
            ("Israel", "🇮🇱"),
            ("New Zealand", "🇳🇿"),
        ],
    },
    {
        "id": "animal-habitats",
        "title": "Animal Habitats",
        "targets": ["rainforest", "desert", "arctic tundra", "coral reef"],
        "objects": [
            ("rainforest", "🌳"),
            ("desert", "🏜️"),
            ("arctic tundra", "🧊"),
            ("coral reef", "🪸"),
            ("savanna", "🦁"),
            ("wetland", "🌿"),
            ("mountain", "🏔️"),
            ("grassland", "🦬"),
            ("ocean", "🌊"),
            ("river", "🏞️"),
            ("mangrove", "🌴"),
            ("cave", "🕳️"),
            ("pond", "🐸"),
            ("prairie", "🌾"),
            ("jungle canopy", "🌳"),
            ("tide pool", "🦀"),
            ("bamboo forest", "🎋"),
            ("volcanic island", "🏝️"),
            ("deep sea", "🐟"),
            ("estuary", "🌊"),
            ("alpine meadow", "🏔️"),
            ("salt flat", "🧂"),
            ("kelp forest", "🌿"),
            ("beech forest", "🌳"),
        ],
    },
    {
        "id": "pokemon-characters",
        "title": "Pokémon Characters",
        "targets": ["Pikachu", "Charizard", "Bulbasaur", "Squirtle"],
        "objects": [
            ("Pikachu", "⚡"),
            ("Charizard", "🔥"),
            ("Bulbasaur", "🌱"),
            ("Squirtle", "💧"),
            ("Eevee", "🦊"),
            ("Jigglypuff", "🎤"),
            ("Snorlax", "😴"),
            ("Mewtwo", "🧬"),
            ("Gengar", "👻"),
            ("Dragonite", "🐉"),
            ("Lucario", "🥋"),
            ("Greninja", "🐸"),
            ("Charmander", "🔥"),
            ("Psyduck", "🦆"),
            ("Meowth", "🐱"),
            ("Machamp", "💪"),
            ("Magikarp", "🐟"),
            ("Lapras", "🐢"),
            ("Cubone", "🦴"),
            ("Togepi", "🥚"),
            ("Pichu", "⚡"),
            ("Vulpix", "🦊"),
            ("Onix", "🪨"),
            ("Pokeball", "🔴"),
        ],
    },
    {
        "id": "pete-the-cat",
        "title": "Pete the Cat",
        "targets": ["Pete the Cat", "Callie", "Gus", "Grumpy Toad"],
        "objects": [
            ("Pete the Cat", "🐱"),
            ("Callie", "🐱"),
            ("Gus", "🐱"),
            ("Grumpy Toad", "🐸"),
            ("Squirrel", "🐿️"),
            ("Turtle", "🐢"),
            ("blue shoes", "👟"),
            ("white shoes", "👟"),
            ("red shoes", "👟"),
            ("groovy buttons", "🔘"),
            ("guitar", "🎸"),
            ("school bus", "🚌"),
            ("pizza", "🍕"),
            ("library book", "📚"),
            ("skateboard", "🛹"),
            ("sunglasses", "🕶️"),
            ("backpack", "🎒"),
            ("apple", "🍎"),
            ("paint brush", "🖌️"),
            ("cookie", "🍪"),
            ("bedtime moon", "🌙"),
            ("rain boots", "🥾"),
            ("hot dog", "🌭"),
            ("four buttons", "🔘"),
        ],
    },
    {
        "id": "wild-kratts",
        "title": "Wild Kratts",
        "targets": ["cheetah", "crocodile", "elephant", "bald eagle"],
        "objects": [
            ("cheetah", "🐆"),
            ("crocodile", "🐊"),
            ("elephant", "🐘"),
            ("bald eagle", "🦅"),
            ("Chris Kratt", "🧑"),
            ("Martin Kratt", "🧑"),
            ("Aviva", "👩"),
            ("Koki", "👩"),
            ("Jimmy Z", "👨"),
            ("creature power disc", "💿"),
            ("tortuga", "🐢"),
            ("monkey", "🐒"),
            ("wolf", "🐺"),
            ("dolphin", "🐬"),
            ("penguin", "🐧"),
            ("komodo dragon", "🦎"),
            ("firefly", "✨"),
            ("rhino", "🦏"),
            ("orca", "🐋"),
            ("hummingbird", "🐦"),
            ("beaver", "🦫"),
            ("draco lizard", "🦎"),
            ("mantis shrimp", "🦐"),
            ("blue heron", "🦩"),
        ],
    },
]

PREDATOR_ROUNDS = [
    {
        "id": "eagle-predator",
        "title": "Eagle Hunt",
        "predator": "eagle",
        "predatorEmoji": "🦅",
        "targets": ["rabbit", "mouse", "fish", "snake"],
        "objects": [
            ("rabbit", "🐇"),
            ("mouse", "🐭"),
            ("fish", "🐟"),
            ("snake", "🐍"),
            ("squirrel", "🐿️"),
            ("frog", "🐸"),
            ("lizard", "🦎"),
            ("duck", "🦆"),
            ("worm", "🪱"),
            ("beetle", "🪲"),
            ("turtle", "🐢"),
            ("deer", "🦌"),
        ],
    },
    {
        "id": "shark-predator",
        "title": "Shark Hunt",
        "predator": "shark",
        "predatorEmoji": "🦈",
        "targets": ["fish", "seal", "squid", "turtle"],
        "objects": [
            ("fish", "🐟"),
            ("seal", "🦭"),
            ("squid", "🦑"),
            ("turtle", "🐢"),
            ("crab", "🦀"),
            ("dolphin", "🐬"),
            ("whale", "🐋"),
            ("octopus", "🐙"),
            ("starfish", "⭐"),
            ("seahorse", "🐚"),
            ("clownfish", "🐠"),
            ("jellyfish", "🪼"),
        ],
    },
    {
        "id": "wolf-predator",
        "title": "Wolf Hunt",
        "predator": "wolf",
        "predatorEmoji": "🐺",
        "targets": ["deer", "rabbit", "moose", "sheep"],
        "objects": [
            ("deer", "🦌"),
            ("rabbit", "🐇"),
            ("moose", "🫎"),
            ("sheep", "🐑"),
            ("bear", "🐻"),
            ("fox", "🦊"),
            ("owl", "🦉"),
            ("cow", "🐄"),
            ("horse", "🐴"),
            ("bird", "🐦"),
            ("beaver", "🦫"),
            ("skunk", "🦨"),
        ],
    },
    {
        "id": "owl-predator",
        "title": "Owl Hunt",
        "predator": "owl",
        "predatorEmoji": "🦉",
        "targets": ["mouse", "rabbit", "squirrel", "moth"],
        "objects": [
            ("mouse", "🐭"),
            ("rabbit", "🐇"),
            ("squirrel", "🐿️"),
            ("moth", "🦋"),
            ("bat", "🦇"),
            ("frog", "🐸"),
            ("snake", "🐍"),
            ("crow", "🐦‍⬛"),
            ("worm", "🪱"),
            ("beetle", "🪲"),
            ("chipmunk", "🐿️"),
            ("hedgehog", "🦔"),
        ],
    },
    {
        "id": "cat-predator",
        "title": "Cat Hunt",
        "predator": "cat",
        "predatorEmoji": "🐈",
        "targets": ["mouse", "bird", "fish", "moth"],
        "objects": [
            ("mouse", "🐭"),
            ("bird", "🐦"),
            ("fish", "🐟"),
            ("moth", "🦋"),
            ("rabbit", "🐇"),
            ("lizard", "🦎"),
            ("frog", "🐸"),
            ("dog", "🐕"),
            ("hamster", "🐹"),
            ("yarn ball", "🧶"),
            ("butterfly", "🦋"),
            ("cricket", "🦗"),
        ],
    },
    {
        "id": "frog-predator",
        "title": "Frog Hunt",
        "predator": "frog",
        "predatorEmoji": "🐸",
        "targets": ["fly", "beetle", "worm", "grasshopper"],
        "objects": [
            ("fly", "🪰"),
            ("beetle", "🪲"),
            ("worm", "🪱"),
            ("grasshopper", "🦗"),
            ("moth", "🦋"),
            ("dragonfly", "🪽"),
            ("snail", "🐌"),
            ("spider", "🕷️"),
            ("ant", "🐜"),
            ("bee", "🐝"),
            ("ladybug", "🐞"),
            ("cricket", "🦗"),
        ],
    },
    {
        "id": "bear-predator",
        "title": "Bear Hunt",
        "predator": "bear",
        "predatorEmoji": "🐻",
        "targets": ["salmon", "trout", "berries", "honey"],
        "objects": [
            ("salmon", "🐟"),
            ("trout", "🐠"),
            ("berries", "🫐"),
            ("honey", "🍯"),
            ("apple", "🍎"),
            ("carrot", "🥕"),
            ("rabbit", "🐇"),
            ("deer", "🦌"),
            ("bird egg", "🥚"),
            ("acorn", "🌰"),
            ("mushroom", "🍄"),
            ("fish", "🐟"),
        ],
    },
]

WILD_CAT_HUNTS = [
    {
        "id": "lion-wildcat",
        "title": "Lion Hunt",
        "predator": "lion",
        "predatorEmoji": "🦁",
        "targets": ["zebra", "wildebeest", "gazelle", "warthog"],
        "objects": [
            ("zebra", "🦓"),
            ("wildebeest", "🦬"),
            ("gazelle", "🦌"),
            ("warthog", "🐗"),
            ("antelope", "🦌"),
            ("buffalo", "🐃"),
            ("giraffe", "🦒"),
            ("hippo", "🦛"),
            ("hyena", "🐕"),
            ("ostrich", "🦃"),
            ("monkey", "🐒"),
            ("meerkat", "🐾"),
            ("elephant", "🐘"),
            ("springbok", "🦌"),
            ("impala", "🦌"),
            ("kudu", "🦌"),
        ],
    },
    {
        "id": "tiger-wildcat",
        "title": "Tiger Hunt",
        "predator": "tiger",
        "predatorEmoji": "🐅",
        "targets": ["deer", "boar", "monkey", "buffalo"],
        "objects": [
            ("deer", "🦌"),
            ("boar", "🐗"),
            ("monkey", "🐒"),
            ("buffalo", "🐃"),
            ("rabbit", "🐇"),
            ("bird", "🐦"),
            ("fish", "🐟"),
            ("turtle", "🐢"),
            ("peacock", "🦚"),
            ("goat", "🐐"),
            ("wild pig", "🐖"),
            ("sambar", "🦌"),
            ("langur", "🐒"),
            ("python", "🐍"),
            ("crane", "🦢"),
            ("frog", "🐸"),
        ],
    },
    {
        "id": "cheetah-wildcat",
        "title": "Cheetah Hunt",
        "predator": "cheetah",
        "predatorEmoji": "🐆",
        "targets": ["gazelle", "hare", "impala", "springbok"],
        "objects": [
            ("gazelle", "🦌"),
            ("hare", "🐇"),
            ("impala", "🦌"),
            ("springbok", "🦌"),
            ("warthog", "🐗"),
            ("ostrich", "🦃"),
            ("guinea fowl", "🐦"),
            ("jackal", "🐕"),
            ("hyena", "🐕"),
            ("zebra foal", "🦓"),
            ("wildebeest calf", "🦬"),
            ("dik-dik", "🦌"),
            ("steenbok", "🦌"),
            ("duiker", "🦌"),
            ("bushbuck", "🦌"),
            ("oryx", "🦌"),
        ],
    },
    {
        "id": "leopard-wildcat",
        "title": "Leopard Hunt",
        "predator": "leopard",
        "predatorEmoji": "🐆",
        "targets": ["monkey", "deer", "pig", "antelope"],
        "objects": [
            ("monkey", "🐒"),
            ("deer", "🦌"),
            ("pig", "🐖"),
            ("antelope", "🦌"),
            ("baboon", "🐒"),
            ("bird", "🐦"),
            ("hare", "🐇"),
            ("goat", "🐐"),
            ("dog", "🐕"),
            ("porcupine", "🦔"),
            ("snake", "🐍"),
            ("lizard", "🦎"),
            ("fish", "🐟"),
            ("crab", "🦀"),
            ("insect", "🐛"),
            ("rodent", "🐭"),
        ],
    },
    {
        "id": "jaguar-wildcat",
        "title": "Jaguar Hunt",
        "predator": "jaguar",
        "predatorEmoji": "🐆",
        "targets": ["capybara", "turtle", "fish", "deer"],
        "objects": [
            ("capybara", "🐹"),
            ("turtle", "🐢"),
            ("fish", "🐟"),
            ("deer", "🦌"),
            ("monkey", "🐒"),
            ("peccary", "🐗"),
            ("caiman", "🐊"),
            ("sloth", "🦥"),
            ("snake", "🐍"),
            ("bird", "🐦"),
            ("frog", "🐸"),
            ("lizard", "🦎"),
            ("armadillo", "🦔"),
            ("tapir", "🐗"),
            ("otter", "🦦"),
            ("iguana", "🦎"),
        ],
    },
    {
        "id": "lynx-wildcat",
        "title": "Lynx Hunt",
        "predator": "lynx",
        "predatorEmoji": "🐱",
        "targets": ["snowshoe hare", "grouse", "squirrel", "mouse"],
        "objects": [
            ("snowshoe hare", "🐇"),
            ("grouse", "🐦"),
            ("squirrel", "🐿️"),
            ("mouse", "🐭"),
            ("vole", "🐭"),
            ("chipmunk", "🐿️"),
            ("ptarmigan", "🐦"),
            ("deer fawn", "🦌"),
            ("fox", "🦊"),
            ("owl", "🦉"),
            ("beaver", "🦫"),
            ("marten", "🐾"),
            ("porcupine", "🦔"),
            ("rabbit", "🐇"),
            ("bird", "🐦"),
            ("frog", "🐸"),
        ],
    },
    {
        "id": "cougar-wildcat",
        "title": "Cougar Hunt",
        "predator": "cougar",
        "predatorEmoji": "🐱",
        "targets": ["deer", "rabbit", "raccoon", "sheep"],
        "objects": [
            ("deer", "🦌"),
            ("rabbit", "🐇"),
            ("raccoon", "🦝"),
            ("sheep", "🐑"),
            ("goat", "🐐"),
            ("elk", "🦌"),
            ("moose calf", "🫎"),
            ("coyote", "🐺"),
            ("bird", "🐦"),
            ("skunk", "🦨"),
            ("opossum", "🐾"),
            ("beaver", "🦫"),
            ("turkey", "🦃"),
            ("porcupine", "🦔"),
            ("lizard", "🦎"),
            ("mouse", "🐭"),
        ],
    },
    {
        "id": "snow-leopard-wildcat",
        "title": "Snow Leopard Hunt",
        "predator": "snow leopard",
        "predatorEmoji": "🐆",
        "targets": ["blue sheep", "marmot", "hare", "goat"],
        "objects": [
            ("blue sheep", "🐑"),
            ("marmot", "🐾"),
            ("hare", "🐇"),
            ("goat", "🐐"),
            ("yak", "🐂"),
            ("bird", "🐦"),
            ("pika", "🐭"),
            ("deer", "🦌"),
            ("snow cock", "🐦"),
            ("fox", "🦊"),
            ("wolf", "🐺"),
            ("rodent", "🐭"),
            ("ibex", "🐐"),
            ("tahr", "🐐"),
            ("partridge", "🐦"),
            ("vole", "🐭"),
        ],
    },
    {
        "id": "ocelot-wildcat",
        "title": "Ocelot Hunt",
        "predator": "ocelot",
        "predatorEmoji": "🐱",
        "targets": ["rodent", "lizard", "frog", "bird"],
        "objects": [
            ("rodent", "🐭"),
            ("lizard", "🦎"),
            ("frog", "🐸"),
            ("bird", "🐦"),
            ("fish", "🐟"),
            ("crab", "🦀"),
            ("snake", "🐍"),
            ("insect", "🐛"),
            ("opossum", "🐾"),
            ("armadillo", "🦔"),
            ("monkey", "🐒"),
            ("turtle", "🐢"),
            ("iguana", "🦎"),
            ("bat", "🦇"),
            ("mouse", "🐭"),
            ("rabbit", "🐇"),
        ],
    },
]

PREHISTORIC_HUNTS = [
    {
        "id": "trex-prehistoric",
        "title": "T-Rex Hunt",
        "predator": "t-rex",
        "predatorEmoji": "🦖",
        "targets": ["triceratops", "duckbill", "stegosaurus", "parasaurolophus"],
        "objects": [
            ("triceratops", "🦕"),
            ("duckbill", "🦕"),
            ("stegosaurus", "🦕"),
            ("parasaurolophus", "🦕"),
            ("ankylosaurus", "🦕"),
            ("sauropod", "🦕"),
            ("pterosaur", "🦅"),
            ("lizard", "🦎"),
            ("turtle", "🐢"),
            ("fish", "🐟"),
            ("crocodile", "🐊"),
            ("dino egg", "🥚"),
            ("fossil", "🦴"),
            ("hadrosaur", "🦕"),
            ("ceratops", "🦕"),
            ("bone", "🦴"),
        ],
    },
    {
        "id": "raptor-prehistoric",
        "title": "Raptor Hunt",
        "predator": "velociraptor",
        "predatorEmoji": "🦖",
        "targets": ["lizard", "mammal", "dino egg", "bird"],
        "objects": [
            ("lizard", "🦎"),
            ("mammal", "🐭"),
            ("dino egg", "🥚"),
            ("bird", "🐦"),
            ("insect", "🐛"),
            ("fish", "🐟"),
            ("frog", "🐸"),
            ("snake", "🐍"),
            ("baby dino", "🦕"),
            ("rodent", "🐭"),
            ("beetle", "🪲"),
            ("worm", "🪱"),
            ("crab", "🦀"),
            ("turtle", "🐢"),
            ("dragonfly", "🪽"),
            ("fossil", "🦴"),
        ],
    },
    {
        "id": "saber-tooth-prehistoric",
        "title": "Saber-Tooth Hunt",
        "predator": "saber-tooth",
        "predatorEmoji": "🐯",
        "targets": ["bison", "deer", "horse", "ground sloth"],
        "objects": [
            ("bison", "🦬"),
            ("deer", "🦌"),
            ("horse", "🐴"),
            ("ground sloth", "🦥"),
            ("mammoth calf", "🦣"),
            ("camel", "🐫"),
            ("boar", "🐗"),
            ("bird", "🐦"),
            ("rabbit", "🐇"),
            ("fish", "🐟"),
            ("cave bear", "🐻"),
            ("wolf", "🐺"),
            ("antelope", "🦌"),
            ("yak", "🐂"),
            ("tapir", "🐗"),
            ("fossil", "🦴"),
        ],
    },
    {
        "id": "megalodon-prehistoric",
        "title": "Megalodon Hunt",
        "predator": "megalodon",
        "predatorEmoji": "🦈",
        "targets": ["fish", "seal", "squid", "whale calf"],
        "objects": [
            ("fish", "🐟"),
            ("seal", "🦭"),
            ("squid", "🦑"),
            ("whale calf", "🐋"),
            ("turtle", "🐢"),
            ("dolphin", "🐬"),
            ("ray", "🐟"),
            ("octopus", "🐙"),
            ("crab", "🦀"),
            ("seahorse", "🐚"),
            ("jellyfish", "🪼"),
            ("prehistoric fish", "🐟"),
            ("shark", "🦈"),
            ("lobster", "🦞"),
            ("starfish", "⭐"),
            ("fossil", "🦴"),
        ],
    },
    {
        "id": "pterosaur-prehistoric",
        "title": "Pterosaur Hunt",
        "predator": "pterosaur",
        "predatorEmoji": "🦅",
        "targets": ["fish", "crab", "squid", "insect"],
        "objects": [
            ("fish", "🐟"),
            ("crab", "🦀"),
            ("squid", "🦑"),
            ("insect", "🐛"),
            ("lizard", "🦎"),
            ("frog", "🐸"),
            ("baby dino", "🦕"),
            ("worm", "🪱"),
            ("beetle", "🪲"),
            ("dragonfly", "🪽"),
            ("snake", "🐍"),
            ("clam", "🐚"),
            ("shrimp", "🦐"),
            ("bird egg", "🥚"),
            ("mouse", "🐭"),
            ("fossil", "🦴"),
        ],
    },
    {
        "id": "spinosaurus-prehistoric",
        "title": "Spinosaurus Hunt",
        "predator": "spinosaurus",
        "predatorEmoji": "🦖",
        "targets": ["fish", "crocodile", "turtle", "duckbill"],
        "objects": [
            ("fish", "🐟"),
            ("crocodile", "🐊"),
            ("turtle", "🐢"),
            ("duckbill", "🦕"),
            ("shark", "🦈"),
            ("ray", "🐟"),
            ("crab", "🦀"),
            ("squid", "🦑"),
            ("lizard", "🦎"),
            ("pterosaur", "🦅"),
            ("dino egg", "🥚"),
            ("heron", "🦢"),
            ("frog", "🐸"),
            ("snake", "🐍"),
            ("prehistoric fish", "🐟"),
            ("fossil", "🦴"),
        ],
    },
    {
        "id": "allosaurus-prehistoric",
        "title": "Allosaurus Hunt",
        "predator": "allosaurus",
        "predatorEmoji": "🦖",
        "targets": ["stegosaurus", "diplodocus", "iguanodon", "camptosaurus"],
        "objects": [
            ("stegosaurus", "🦕"),
            ("diplodocus", "🦕"),
            ("iguanodon", "🦕"),
            ("camptosaurus", "🦕"),
            ("dryosaurus", "🦕"),
            ("pterosaur", "🦅"),
            ("lizard", "🦎"),
            ("turtle", "🐢"),
            ("fish", "🐟"),
            ("dino egg", "🥚"),
            ("ceratosaurus", "🦖"),
            ("bone", "🦴"),
            ("ornithopod", "🦕"),
            ("sauropod", "🦕"),
            ("fossil", "🦴"),
            ("footprint", "👣"),
        ],
    },
    {
        "id": "mosasaurus-prehistoric",
        "title": "Mosasaurus Hunt",
        "predator": "mosasaurus",
        "predatorEmoji": "🐋",
        "targets": ["fish", "squid", "turtle", "shark"],
        "objects": [
            ("fish", "🐟"),
            ("squid", "🦑"),
            ("turtle", "🐢"),
            ("shark", "🦈"),
            ("ammonite", "🐚"),
            ("plesiosaur", "🐋"),
            ("crab", "🦀"),
            ("ray", "🐟"),
            ("seal", "🦭"),
            ("bird", "🐦"),
            ("prehistoric fish", "🐟"),
            ("lobster", "🦞"),
            ("jellyfish", "🪼"),
            ("octopus", "🐙"),
            ("fossil", "🦴"),
            ("coral", "🪸"),
        ],
    },
    {
        "id": "mammoth-prehistoric",
        "title": "Mammoth Hunt",
        "predator": "mammoth",
        "predatorEmoji": "🦣",
        "targets": ["grass", "leaves", "berries", "water"],
        "objects": [
            ("grass", "🌿"),
            ("leaves", "🍃"),
            ("berries", "🫐"),
            ("water", "💧"),
            ("ferns", "🌿"),
            ("bark", "🪵"),
            ("roots", "🥕"),
            ("apple", "🍎"),
            ("willow", "🌳"),
            ("sedge", "🌿"),
            ("moss", "🌿"),
            ("snow", "❄️"),
            ("cave", "🕳️"),
            ("calf", "🦣"),
            ("flower", "🌸"),
            ("pine", "🌲"),
        ],
    },
]


def slug(name: str) -> str:
    return name.lower().replace(" ", "-").replace("/", "-")


BLACK = (0, 0, 0)
WHITE = (255, 255, 255)


def try_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def make_marker(index: int) -> Image.Image:
    """Pure black-and-white art for laser printers. ARKit wants unique high-contrast corners."""
    rng = random.Random(1000 + index * 97)
    img = Image.new("RGB", (SIZE, SIZE), WHITE)
    draw = ImageDraw.Draw(img)

    cells = 16
    cell = SIZE // cells
    for y in range(cells):
        for x in range(cells):
            seed = rng.random()
            x0, y0 = x * cell + 2, y * cell + 2
            x1, y1 = x0 + cell - 6, y0 + cell - 6
            if seed < 0.42:
                draw.rectangle([x0, y0, x1, y1], fill=BLACK)
            elif seed < 0.55:
                draw.ellipse([x0 + 4, y0 + 4, x1 - 4, y1 - 4], fill=BLACK)
            elif seed < 0.68:
                draw.polygon([(x0, y1), (x0 + cell // 2, y0), (x1, y1)], fill=BLACK)
            elif seed < 0.78:
                draw.rectangle([x0 + 8, y0 + 4, x1 - 8, y1 - 4], fill=BLACK)
            elif seed < 0.88:
                draw.line([x0, y0, x1, y1], fill=BLACK, width=10)
                draw.line([x0, y1, x1, y0], fill=BLACK, width=8)

    ornaments = index % 4
    if ornaments == 0:
        draw.ellipse([48, 48, 260, 220], outline=BLACK, width=22)
        draw.rectangle([SIZE - 250, 56, SIZE - 56, 230], fill=BLACK)
        draw.polygon([(70, SIZE - 70), (280, SIZE - 300), (340, SIZE - 50)], fill=BLACK)
    elif ornaments == 1:
        draw.rectangle([48, 48, 240, 240], outline=BLACK, width=22)
        draw.ellipse([SIZE - 280, 40, SIZE - 40, 260], fill=BLACK)
        draw.pieslice([SIZE - 340, SIZE - 340, SIZE - 40, SIZE - 40], 200, 40, fill=BLACK)
    elif ornaments == 2:
        draw.polygon([(40, 40), (280, 70), (90, 280)], fill=BLACK)
        draw.rectangle([SIZE - 300, 70, SIZE - 70, 200], outline=BLACK, width=18)
        draw.ellipse([80, SIZE - 300, 300, SIZE - 50], fill=BLACK)
    else:
        draw.chord([40, 40, 300, 260], 10, 220, fill=BLACK)
        draw.polygon([(SIZE - 80, 60), (SIZE - 260, 80), (SIZE - 70, 260)], fill=BLACK)
        draw.rectangle([60, SIZE - 240, 280, SIZE - 60], outline=BLACK, width=20)

    stripe_origin = 80 + (index * 17) % 200
    for i in range(7):
        x = stripe_origin + i * 28
        w = 8 if (index + i) % 2 == 0 else 16
        draw.rectangle([x, 320, x + w, 700], fill=BLACK)

    for _ in range(220):
        x = rng.randint(40, SIZE - 40)
        y = rng.randint(40, SIZE - 40)
        r = rng.randint(6, 14)
        draw.ellipse(
            [x - r, y - r, x + r, y + r],
            fill=BLACK if rng.random() < 0.7 else WHITE,
            outline=BLACK,
            width=3,
        )

    number = f"{index:02d}"
    font = try_font(210)
    bbox = draw.textbbox((0, 0), number, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2
    ty = (SIZE - th) // 2 - 20
    pad = 28
    draw.rounded_rectangle(
        [tx - pad, ty - pad, tx + tw + pad, ty + th + pad],
        radius=12,
        fill=WHITE,
        outline=BLACK,
        width=14,
    )
    draw.text((tx, ty), number, font=font, fill=BLACK)

    draw.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=BLACK, width=36)
    draw.rectangle([44, 44, SIZE - 45, SIZE - 45], outline=BLACK, width=8)
    return img.convert("1", dither=Image.Dither.NONE).convert("RGB")


def write_pdf(paths: list[Path]) -> Path:
    PRINT_DIR.mkdir(parents=True, exist_ok=True)
    out = PRINT_DIR / "ARScav-markers.pdf"
    page_w, page_h = letter
    marker_pt = PHYSICAL_CM * 10 * mm  # 10cm
    cols, rows = 2, 2
    gap = 10
    grid_w = cols * marker_pt + (cols - 1) * gap
    grid_h = rows * marker_pt + (rows - 1) * gap
    origin_x = (page_w - grid_w) / 2
    origin_y = (page_h - grid_h) / 2 - 12

    c = pdfcanvas.Canvas(str(out), pagesize=letter)
    for page in range(0, COUNT, 4):
        c.setFont("Helvetica-Bold", 14)
        c.drawCentredString(page_w / 2, page_h - 36, "ARScav markers — B&W laser — print at 100% (Actual Size)")
        c.setFont("Helvetica", 9)
        c.drawCentredString(
            page_w / 2,
            page_h - 52,
            f"Each square is {PHYSICAL_CM:.0f} cm. Black toner, not draft/eco. Do not scale to fit. Page {page // 4 + 1} of {(COUNT + 3) // 4}.",
        )
        for i in range(4):
            idx = page + i
            if idx >= COUNT:
                break
            col, row = i % 2, i // 2
            x = origin_x + col * (marker_pt + gap)
            y = origin_y + (1 - row) * (marker_pt + gap)
            # crop marks
            mark = 10
            c.setStrokeColorRGB(0, 0, 0)
            c.setLineWidth(0.6)
            for mx, my in (
                (x, y + marker_pt),
                (x + marker_pt, y + marker_pt),
                (x, y),
                (x + marker_pt, y),
            ):
                dx = -1 if mx == x else 1
                dy = 1 if my == y + marker_pt else -1
                c.line(mx + dx * 4, my + dy * 4, mx + dx * (4 + mark), my + dy * 4)
                c.line(mx + dx * 4, my + dy * 4, mx + dx * 4, my + dy * (4 + mark))
            c.drawImage(
                str(paths[idx]),
                x,
                y,
                width=marker_pt,
                height=marker_pt,
                preserveAspectRatio=True,
                mask="auto",
            )
            c.setFont("Helvetica", 8)
            c.drawCentredString(x + marker_pt / 2, y - 12, f"marker-{idx + 1:02d}  ·  {PHYSICAL_CM:.0f} cm")
        c.showPage()
    c.save()
    return out


def round_objects(rnd: dict) -> list[tuple[str, str]]:
    """Four targets plus decoys — one object per printed marker (up to 24)."""
    targets = rnd["targets"]
    all_objs = rnd["objects"]
    by_name = {name: (name, emoji) for name, emoji in all_objs}
    picked: list[tuple[str, str]] = [by_name[t] for t in targets if t in by_name]
    for name, emoji in all_objs:
        if name not in targets and len(picked) < OBJECTS_PER_ROUND:
            picked.append((name, emoji))
    return picked[:OBJECTS_PER_ROUND]


def assign_markers(
    rnd: dict,
    objects_list: list[tuple[str, str]],
    marker_count: int,
    rng: random.Random,
    active_marker_count: int = DEFAULT_MARKER_COUNT,
) -> list[tuple[tuple[str, str], str]]:
    """Place every hunt target on an active marker (marker-01 … marker-N)."""
    target_names = set(rnd["targets"])
    targets: list[tuple[str, str]] = []
    decoys: list[tuple[str, str]] = []
    for item in objects_list[:marker_count]:
        if item[0] in target_names:
            targets.append(item)
        else:
            decoys.append(item)

    active_cap = min(active_marker_count, marker_count)
    active_slots = [f"marker-{i:02d}" for i in range(1, active_cap + 1)]
    extra_slots = [f"marker-{i:02d}" for i in range(active_cap + 1, marker_count + 1)]
    rng.shuffle(active_slots)
    rng.shuffle(extra_slots)

    if len(targets) > len(active_slots):
        msg = f"Round {rnd['id']} has {len(targets)} targets but only {len(active_slots)} active marker slots"
        raise ValueError(msg)

    target_marker_ids = active_slots[: len(targets)]
    decoy_marker_ids = active_slots[len(targets) :] + extra_slots
    rng.shuffle(decoy_marker_ids)

    pairs: list[tuple[tuple[str, str], str]] = []
    for obj, marker_id in zip(targets, target_marker_ids, strict=True):
        pairs.append((obj, marker_id))
    for obj, marker_id in zip(decoys, decoy_marker_ids, strict=True):
        pairs.append((obj, marker_id))
    rng.shuffle(pairs)
    return pairs


def category_search_hint(rnd: dict, mode: str) -> str:
    if mode == "predator":
        predator = rnd.get("predator", "predator").replace("-", " ")
        return f"{predator} prey"

    title = rnd["title"].lower().replace(" hunt", "").strip()
    overrides = {
        "kinds of balls": "sports ball",
        "trees / plants": "plant",
        "yummy snacks": "food",
        "in the kitchen": "kitchen",
        "musical instruments": "instrument",
        "under the sea": "ocean",
        "african safari": "safari",
        "ice age animals": "prehistoric",
        "apex predators": "predator",
        "ocean giants": "ocean",
        "birds of prey": "raptor",
        "baby animals": "baby",
        "nocturnal animals": "nocturnal",
        "wild cats": "big cat",
        "desert animals": "desert",
        "arctic animals": "arctic",
        "rainforest animals": "jungle",
        "farm animals": "farm",
        "land vehicles": "vehicle",
        "water vehicles": "boat",
        "air vehicles": "aircraft",
        "dinosaurs": "dinosaur",
        "reptiles": "reptile",
        "bugs": "insect",
        "pets": "pet",
        "animals": "wildlife",
        "volcanoes around the world": "volcano",
        "infamous shipwrecks": "shipwreck",
        "famous pirates": "pirate",
        "legendary explorers": "explorer",
        "ancient wonders": "ancient monument",
        "lost cities": "archaeological ruins",
        "deep sea creatures": "deep sea",
        "carnivorous plants": "carnivorous plant",
        "living fossils": "prehistoric",
        "bioluminescent life": "bioluminescence",
        "peculiar animals": "wildlife",
        "extreme survivors": "wildlife",
        "country flags": "country flag",
        "animal habitats": "habitat",
        "pokémon characters": "pokemon",
        "pokemon characters": "pokemon",
        "pete the cat": "children book",
        "wild kratts": "wildlife",
    }
    return overrides.get(title, title)


def pixabay_category(rnd_id: str, mode: str, hint: str) -> str | None:
    rid = rnd_id.lower()
    hint_l = hint.lower()
    if mode == "predator" or "animal" in hint_l or "prey" in hint_l or "dinosaur" in hint_l:
        if any(token in rid for token in ("vehicle", "car", "train", "boat", "air", "plane", "helicopter")):
            return "transportation"
        if any(
            token in rid
            for token in (
                "animal",
                "cat",
                "safari",
                "dino",
                "reptile",
                "bird",
                "bug",
                "pet",
                "farm",
                "ocean",
                "sea",
                "arctic",
                "desert",
                "rainforest",
                "ice-age",
                "apex",
                "baby",
                "nocturnal",
                "prehistoric",
                "predator",
                "wildcat",
                "deep-sea",
                "carnivorous",
                "living-fossil",
                "bioluminescent",
                "peculiar",
                "extreme",
            )
        ):
            return "animals"
    if any(token in rid for token in ("fruit", "vegetable", "snack", "kitchen")):
        return "food"
    if "ball" in rid:
        return "sports"
    if "plant" in rid or "tree" in rid:
        return "nature"
    if "instrument" in rid:
        return "music"
    if "vehicle" in rid or "car" in rid or "train" in rid or "boat" in rid or "air" in rid:
        return "transportation"
    if "weather" in rid or "volcano" in rid:
        return "science"
    if any(token in rid for token in ("shipwreck", "pirate", "explorer", "wonder", "lost-cit")):
        return "science"
    if "flag" in rid or "pokemon" in rid:
        return "science"
    if "clothes" in rid or "cloth" in rid:
        return "fashion"
    if "toy" in rid:
        return None
    return None


def build_round_entries(catalog: list[tuple[dict, str, str]], seed_offset: int = 0) -> list[dict]:
    rounds = []
    for r_i, (rnd, mode, group) in enumerate(catalog):
        rng = random.Random(42 + seed_offset + r_i)
        objects_list = round_objects(rnd)
        marker_count = min(len(objects_list), COUNT)
        pairs = assign_markers(rnd, objects_list, marker_count, rng)
        hint = category_search_hint(rnd, mode)
        pixabay_cat = pixabay_category(rnd["id"], mode, hint)
        objects = []
        for (name, emoji), marker_id in pairs:
            oid = slug(name)
            search_query = f"{name} {hint} photo"
            objects.append(
                {
                    "id": oid,
                    "name": name,
                    "emoji": emoji,
                    "markerId": marker_id,
                    "searchQuery": search_query,
                    "searchCategory": hint,
                }
            )
        entry = {
            "id": rnd["id"],
            "title": rnd["title"],
            "targets": [slug(t) for t in rnd["targets"]],
            "objects": objects,
            "gameplayMode": mode,
            "categoryGroup": group,
            "searchCategory": hint,
        }
        if pixabay_cat:
            entry["pixabayCategory"] = pixabay_cat
        if mode == "predator":
            entry["predatorName"] = rnd["predator"]
            entry["predatorEmoji"] = rnd["predatorEmoji"]
        rounds.append(entry)
    return rounds


def write_manifest() -> Path:
    CONTENT_DIR.mkdir(parents=True, exist_ok=True)
    catalog = [(rnd, "standard", "Classic Hunts") for rnd in ROUNDS] + [
        (rnd, "predator", "Predator Hunts") for rnd in PREDATOR_ROUNDS
    ] + [(rnd, "predator", "Wild Cat Hunts") for rnd in WILD_CAT_HUNTS] + [
        (rnd, "predator", "Prehistoric Hunts") for rnd in PREHISTORIC_HUNTS
    ]
    rounds = build_round_entries(catalog)
    payload = {
        "physicalMarkerWidthMeters": 0.10,
        "markerCount": DEFAULT_MARKER_COUNT,
        "rounds": rounds,
    }
    path = CONTENT_DIR / "manifest.json"
    path.write_text(json.dumps(payload, indent=2) + "\n")
    return path


def write_remote_manifest() -> Path:
    CONTENT_DIR.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    catalog_dir = root / "catalog"
    catalog_dir.mkdir(parents=True, exist_ok=True)
    path = catalog_dir / "manifest-remote.json"

    existing_rounds: list[dict] = []
    if path.exists():
        try:
            existing_payload = json.loads(path.read_text())
            existing_rounds = existing_payload.get("rounds", [])
        except json.JSONDecodeError:
            existing_rounds = []

    existing_ids = {entry["id"] for entry in existing_rounds}
    catalog = [(rnd, "standard", "Classic Hunts") for rnd in REMOTE_ROUNDS]
    new_rounds = build_round_entries(catalog, seed_offset=10_000)
    appended = [entry for entry in new_rounds if entry["id"] not in existing_ids]
    payload = {"rounds": existing_rounds + appended}
    path.write_text(json.dumps(payload, indent=2) + "\n")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate AR markers and hunt manifests.")
    parser.add_argument(
        "--remote-only",
        action="store_true",
        help="Write catalog/manifest-remote.json from REMOTE_ROUNDS only (for GitHub hosting).",
    )
    args = parser.parse_args()

    if args.remote_only:
        path = write_remote_manifest()
        total = len(json.loads(path.read_text()).get("rounds", []))
        print(f"wrote {path} ({len(REMOTE_ROUNDS)} new template(s), {total} total remote round(s))")
        return

    MARKER_DIR.mkdir(parents=True, exist_ok=True)
    for old in MARKER_DIR.glob("marker-*.png"):
        try:
            number = int(old.stem.removeprefix("marker-"))
        except ValueError:
            continue
        if number > COUNT:
            old.unlink()
            print(f"removed {old.name}")
    paths: list[Path] = []
    for i in range(1, COUNT + 1):
        img = make_marker(i)
        path = MARKER_DIR / f"marker-{i:02d}.png"
        img.save(path, "PNG", optimize=True)
        paths.append(path)
        print(f"wrote {path.name}")
    pdf = write_pdf(paths)
    print(f"wrote {pdf}")
    manifest = write_manifest()
    print(f"wrote {manifest}")


if __name__ == "__main__":
    main()
