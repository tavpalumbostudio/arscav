import Foundation

enum WonderLines {
    private static let objectLines: [String: [String]] = [
        "elephant": [
            "Elephants are huge — maybe taller than you!",
            "Do you think an elephant could hide under your bed?"
        ],
        "dog": [
            "Dogs love to sniff things — just like your scanner!",
            "Can you bark like a dog?"
        ],
        "cat": [
            "Cats are super sneaky hiders.",
            "Do you think a cat would like this hunt?"
        ],
        "bird": [
            "Birds have wings, but they still hide on cards!",
            "Can you flap your arms like a bird?"
        ],
        "penguin": [
            "Penguins can't fly — but they're great swimmers!",
            "Do penguins live where it's cold?"
        ],
        "lion": [
            "Lions are loud — can you roar softly?",
            "A lion's mane looks like a fancy haircut!"
        ],
        "tiger": [
            "Tigers have stripes — count some stripes out loud!",
            "Tigers are great at sneaking."
        ],
        "fish": [
            "Fish live underwater. Glub glub!",
            "Can you swim your hand like a fish?"
        ],
        "horse": [
            "Horses gallop fast — can you gallop in place?",
            "Horses say neigh!"
        ],
        "frog": [
            "Frogs go ribbit! Can you ribbit?",
            "Frogs are great at jumping."
        ],
        "bear": [
            "Bears love to sniff around for snacks.",
            "Can you growl like a bear?"
        ],
        "train": [
            "Trains go chugga chugga — make that sound!",
            "Trains ride on tracks."
        ],
        "car": [
            "Cars have wheels — how many wheels on a car?",
            "Beep beep!"
        ],
        "shark": [
            "Sharks swim all day long.",
            "Sharks have lots of teeth!"
        ],
        "dolphin": [
            "Dolphins are friendly swimmers.",
            "Dolphins click and whistle!"
        ],
        "dinosaur": [
            "Dinosaurs lived long long ago!",
            "Stomp stomp like a dinosaur!"
        ],
        "anglerfish": [
            "Anglerfish carry a glowing lure in the deep dark sea!",
            "Would you like a flashlight like an anglerfish?"
        ],
        "blobfish": [
            "Blobfish look squishy — but they're tough deep-sea survivors!",
            "Do you think a blobfish would make a good pillow?"
        ],
        "venus flytrap": [
            "Venus flytraps snap shut when a bug lands!",
            "Can you clap your hands like a flytrap snap?"
        ],
        "axolotl": [
            "Axolotls can grow new limbs — like magic!",
            "Axolotls smile with feathery gills!"
        ],
        "platypus": [
            "Platypuses have a duck bill and lay eggs!",
            "Is a platypus a bird, a fish, or something else?"
        ],
        "pangolin": [
            "Pangolins curl up like a spiky ball!",
            "Pangolins have scales like armor!"
        ],
        "firefly": [
            "Fireflies blink in the dark — blink blink!",
            "Can you blink like a firefly?"
        ],
        "coelacanth": [
            "Coelacanths were thought extinct — then one swam by!",
            "This fish is older than dinosaurs!"
        ],
        "tardigrade": [
            "Tardigrades are tiny but almost impossible to stop!",
            "A tardigrade is smaller than a crumb!"
        ],
        "mount-fuji": [
            "Mount Fuji is a perfect cone-shaped volcano in Japan!",
            "Can you draw a snowy mountain peak?"
        ],
        "titanic": [
            "The Titanic was the biggest ship of its time!",
            "Shipwrecks can hide treasures on the ocean floor!"
        ],
        "blackbeard": [
            "Blackbeard was one of the most famous pirates ever!",
            "Can you say Arrr like a pirate?"
        ],
        "great-pyramid": [
            "The Great Pyramid is thousands of years old!",
            "How many blocks do you think it took to build?"
        ],
        "pompeii": [
            "Pompeii was buried by a volcano — then rediscovered!",
            "Ancient cities can sleep under ash for centuries!"
        ]
    ]

    static func line(
        playerName: String,
        target: HuntObject,
        round: HuntRound,
        styleIndex: Int = 0
    ) -> String {
        if let lines = objectLines[target.id] {
            let base = lines[styleIndex % lines.count]
            return PromptPersonalizer.personalize(base, name: playerName, chance: 0.4)
        }

        let category = round.title
        let name = target.name
        let templates: [String]
        if round.isPredatorHunt {
            templates = [
                "Do you think a \(name) knows you're hunting?",
                "What sound does a \(name) make?",
                "Predators use their eyes — use yours too!"
            ]
        } else if category.localizedCaseInsensitiveContains("vehicle") {
            templates = [
                "Does a \(name) go fast or slow?",
                "What color might a \(name) be?",
                "Can you make a vehicle sound for \(name)?"
            ]
        } else {
            templates = [
                "Do you think a \(name) is bigger than your hand?",
                "What do you think a \(name) eats?",
                "If you were a \(name), where would you hide?",
                "Can you name something the same color as a \(name)?"
            ]
        }
        let base = templates[styleIndex % templates.count]
        return PromptPersonalizer.personalize(base, name: playerName, chance: 0.4)
    }
}
