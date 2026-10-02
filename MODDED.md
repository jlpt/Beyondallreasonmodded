# Beyond All Reason: Modded

This fork of [Beyond All Reason](https://github.com/beyond-all-reason/Beyond-All-Reason) adds:

- **Raptor & Scavenger Arsenal**: the Armada, Cortex and Legion factions can build what the Raptors and Scavengers
  have.
- **Sukuna** and **Steve**: two new units you build from bot labs, with an early-game (T1), mid-game (T2) and
  late-game (T3) version each. Every tier keeps the abilities of the tiers below it.
- **Fahh**: the fahh sound effect plays whenever a unit dies.

## How to play it

Follow the "Development Quick Start" in [README.md](README.md): clone this repository into the `games` folder of
your BAR install as `BAR.sdd`, create `devmode.txt`, then pick `Beyond All Reason Dev` under
`Settings > Developer > Singleplayer` and start a skirmish.

```
git clone --recurse-submodules https://github.com/jlpt/Beyondallreasonmodded.git BAR.sdd
```

## Sukuna

Built from the bot lab of each tech level (Bot Lab, Advanced Bot Lab, Experimental Gantry) of every faction.

| Tier | Unit | Abilities |
| --- | --- | --- |
| T1 | Sukuna (Vessel) | **Dismantle**: close-range cursed slashes that cut through groups. |
| T2 | Sukuna (Malevolent Shrine) | Slashes, plus **Domain Expansion**: press the *Domain Expansion* button. After a one-second hand sign the Malevolent Shrine opens: for 8 seconds every enemy unit and building inside a 380 radius is slashed again and again (320 damage per second). Costs 1500 energy and recharges in 45 seconds. |
| T3 | Sukuna (King of Curses) | Slashes, a bigger Domain Expansion (520 radius, 10 seconds, 650 damage per second, 3000 energy, 40 second recharge), plus **Fuga**: a flaming arrow fired every 16 seconds at up to 950 range that explodes and leaves the ground burning. |

## Steve

Built from the same bot labs as Sukuna. Steve is a builder: select him and pick a block from his build menu.

| Tier | Unit | Abilities |
| --- | --- | --- |
| T1 | Steve | Shoots **arrows** and places **Dirt** and **Cobblestone** blocks to barricade (drag to place a wall of them). |
| T2 | Steve (Iron) | Arrows, blocks, plus **Nether Portals**. |
| T3 | Steve (Diamond) | Flaming arrows, blocks, Nether Portals, plus **TNT**. |

**Nether Portals**: all finished portals of your team (and your allies) are connected in the order they were built:
walking into portal 1 brings you out of portal 2, portal 2 leads to portal 3, and the last one leads back to the
first. With two portals they simply lead to each other. A portal glows purple once it has a partner. To send units
through, move them onto the portal or right-click the portal with them (guard). Ground units only; units passing
by on their way somewhere else are not pulled in.

**TNT**: once built, TNT waits until an enemy comes within 150 range, then its fuse burns for 2.5 seconds and it
explodes, dealing heavy damage around it. Being shot sets it off almost instantly, so TNT next to TNT chains. The
blast never hurts your own or allied units. You can also set it off yourself with self-destruct.

## Raptor & Scavenger Arsenal

On by default. Turn it off in the lobby under `Extras > Raptor & Scavenger Arsenal`.

- **Raptor factories** (raptor hive models). Tech 1 constructors and commanders build the **Raptor Nest** (swarmers,
  healers, kamikazes, spikers, all-terrain raptors) and the **Raptor Roost** (flying raptors). Tech 2 constructors
  build the **Raptor Brood Lair** (assault raptors, artillery, the Overseer) and the **Raptor Queen's Throne** (apex
  raptors, all six Matriarchs and a Raptor Queen).
- **Raptor defences**: T1 constructors build the small tentacle turrets, T2 constructors the large and huge ones,
  the burrowing worm and the raptor anti-nukes.
- **Scavenger units and buildings**, each given to the faction it was made from: the epic T3/T4 bots and vehicles
  come from the Experimental Gantry, the epic aircraft from the T3 Aircraft Gantry (built by T2 constructors),
  the scavenger ships from the Advanced Shipyard, and the scavenger defences and economy buildings from T2
  constructors. This includes everything from the existing "Scavengers Units Pack" option.

The scavenger AI's own machinery (spawn beacons, drop pods, the boss) is not included.

## Fahh

The `Fahh On Death` widget plays the sound whenever a unit dies. In big fights it plays at most once every 0.6
seconds so it does not stack into noise; commander deaths always play. Walls, blocks, mines and TNT do not count.
Turn it off in the widget list (F11).

## Rebuilding the assets

The models, textures and build pictures are generated from the sources in `tools/modded_units/source` by
`python3 tools/modded_units/build_assets.py` (needs numpy and Pillow).

## Credits

- "Freefire new sukuna 3d model" (https://sketchfab.com/3d-models/freefire-new-sukuna-3d-model-d5bb39bca3b34641b07998ad237a3db4)
  by KAKASHI (https://sketchfab.com/amansoyal781), licensed under CC-BY-4.0
  (http://creativecommons.org/licenses/by/4.0/). Converted to S3O, posed into separate body parts and retextured
  for the tier variants.
- "Minecraft - Steve" (https://sketchfab.com/3d-models/minecraft-steve-cb228dcc137042cc9a3dc588758cc6e9) by Vincent
  Yanez (https://sketchfab.com/vinceyanez), licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/).
  Converted to S3O, split into body parts, given a bow and retextured for the tier variants.
- The raptor factories reuse the raptor hive model by FireStorm and Beherith from Beyond All Reason.
- Sukuna is from Jujutsu Kaisen by Gege Akutami. Steve, TNT, blocks and nether portals are from Minecraft by Mojang
  Studios. This is an unofficial fan modification.
