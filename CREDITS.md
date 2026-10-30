# Créditos

Unnamed usa solamente arte con licencia libre (CC0, CC-BY y SIL OFL). Abajo
está cada autor, la licencia y de dónde sale cada cosa. Si agregás algo nuevo,
verificá la licencia en la página de origen y sumalo acá.

## Interfaz

Las texturas de la interfaz (marcos, casillas, botones, barras y fondos de
madera, en `ui/theme/textures/`) están armadas a partir del
**"RPG GUI construction kit v1.0"** de **Matjaž Lamut (Lamoot)**,
con licencia [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/).

- Original: https://opengameart.org/content/rpg-gui-construction-kit-v10
- El kit usa la textura "Dirt 002" del mismo autor (CC-BY 3.0) y una foto de
  madera de dominio público.
- Cambios: piezas recortadas y combinadas en marcos de 9 partes, madera
  reducida y oscurecida, tablones sin las puntas y recoloreados para los
  botones, rellenos de barra nuevos. Se regeneran con
  `ui/theme/textures/build_textures.gd` a partir de `ui/theme/textures/source/`.

## Fuentes (SIL Open Font License 1.1)

En `assets/fonts/`, cada una con su `OFL.txt`:

- **Cinzel** (títulos y encabezados): Natanael Gama, The Cinzel Project Authors.
  https://github.com/NDISCOVER/Cinzel
- **EB Garamond** (texto): Georg Duffner y Octavio Pardo, The EB Garamond
  Project Authors. https://github.com/octaviopardo/EBGaramond12

## Íconos (CC BY 3.0)

Íconos de [game-icons.net](https://game-icons.net), con licencia
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), en
`assets/icons/game-icons/` (una carpeta por autor):

- **Lorc** (https://lorcblog.blogspot.com)
- **Delapouite** (https://delapouite.com)
- **Sbed** (http://opengameart.org/content/95-game-icons)
- **Carl Olsen** (https://twitter.com/unstoppableCarl)

Cambios: se les sacó el fondo negro y el juego los tiñe de colores. Los íconos
de habilidades (`ui/icons/skills/`) son esos dibujos recoloreados sobre un fondo
propio: Golpe Brutal (Lorc, hammer-drop), Torbellino (Lorc, sword-spin), Bola de
Fuego (Lorc, fireball), Furia (Delapouite, enrage) y Piel de Piedra
(Delapouite, rock-golem). En el mapa grande, el yunque del herrero es "anvil"
de Lorc y el baúl es "chest" de Delapouite.

Las gemas (`item/gems/`) no usan arte de afuera: su talla y sus materiales los
genera `item/gems/build_gems.gd`.

## Efectos

Texturas de partículas de `fx/textures/`: armadas a partir del
**Particle Pack** de **Kenney** (https://kenney.nl/assets/particle-pack), CC0.
Cambios: reducidas a 256 px, el brillo pasa a ser el alfa y varias se juntan
en tiras de 4 cuadros. Licencia original en `fx/textures/License-Kenney.txt`.

## Mundo

Todo lo de esta sección es CC0 (dominio público): no hace falta atribuir, pero
lo dejamos anotado.

### Suelos (`assets/terrain/`)

| Textura | Autor | Fuente |
|---|---|---|
| Pasto (Grass 004) | ambientCG | https://ambientcg.com/a/Grass004 |
| Musgo (Ground 037) | ambientCG | https://ambientcg.com/a/Ground037 |
| Hojas del bosque (Forest Leaves 02) | Rob Tuytel | https://polyhaven.com/a/forest_leaves_02 |
| Tierra de los caminos (Brown Mud 02) | Rob Tuytel | https://polyhaven.com/a/brown_mud_02 |
| Adoquines (Cobblestone Floor 001) | Rob Tuytel | https://polyhaven.com/a/cobblestone_floor_001 |
| Piedra (Rocks Ground 02) | Rob Tuytel | https://polyhaven.com/a/rocks_ground_02 |

### Naturaleza (`assets/nature/`)

| Modelo | Autor | Fuente |
|---|---|---|
| Rocas (Rock 07, Rock 09) | Jenelle van Heerden | https://polyhaven.com/a/rock_07 · https://polyhaven.com/a/rock_09 |
| Rocas con musgo (Rock Moss Set 01) | Kless Gyzen | https://polyhaven.com/a/rock_moss_set_01 |
| Helechos (Fern 02) | Rob Tuytel, Rico Cilliers | https://polyhaven.com/a/fern_02 |
| Arbustos (Shrub 02) | Rico Cilliers | https://polyhaven.com/a/shrub_02 |
| Tocón (Tree Stump 01) | Rob Tuytel | https://polyhaven.com/a/tree_stump_01 |
| Árboles, pinos, árboles secos y retorcidos ("Stylized Nature MegaKit") | Quaternius | https://quaternius.com · modelos bajados de https://poly.pizza (CC0 1.0) |

### Piezas (`assets/props/`)

| Modelo | Autor | Fuente |
|---|---|---|
| Barril de vino (Wine Barrel 01) | James Ray Cock | https://polyhaven.com/a/wine_barrel_01 |
| Cajón (Wooden Crate 01) | James Ray Cock | https://polyhaven.com/a/wooden_crate_01 |
| Farol (Wooden Lantern 01) | James Ray Cock | https://polyhaven.com/a/wooden_lantern_01 |
| Balde (Wooden Bucket 01) | James Ray Cock | https://polyhaven.com/a/wooden_bucket_01 |
| Fogata (Stone Fire Pit) | Sebastian Platen | https://polyhaven.com/a/stone_fire_pit |
| Muros, torre y portón (Modular Fort 01) | Rico Cilliers | https://polyhaven.com/a/modular_fort_01 |
| Estatua (Gothic Statue) | Benny Weimer | https://polyhaven.com/a/gothic_statue |
| Cofres y baúl (Treasure Chest) | Rico Cilliers | https://polyhaven.com/a/treasure_chest |
| Lápidas, criptas, rejas, faroles y braseros (Graveyard Kit) | Kenney | https://kenney.nl/assets/graveyard-kit (licencia en `assets/props/graveyard/License.txt`) |
| Casas, pozo, carro y puesto ("Medieval Village") | Quaternius | https://quaternius.com · modelos bajados de https://poly.pizza (CC0 1.0) |

Nota sobre Quaternius: los modelos se bajaron de poly.pizza, donde cada uno
figura como CC0 1.0 (igual que la página del pack en quaternius.com). Su sitio
publicó en 2026 una licencia propia para descargas nuevas que no permite
redistribuir los modelos sueltos como pack; las copias que ya salieron como CC0
siguen siéndolo, pero si se quiere evitar cualquier duda, se pueden cambiar por
modelos de Poly Haven o Kenney.

### Animales (`assets/animals/`)

| Modelo | Autor | Fuente |
|---|---|---|
| Caballo con animaciones (montura) | Quaternius | https://poly.pizza/m/qvTrSG9pZF (CC0 1.0) |
| Lobo con animaciones (enemigo) | Quaternius | https://poly.pizza/m/P1gU3Qkr9r (CC0 1.0) |
| Araña con animaciones (enemigo) | Quaternius | https://poly.pizza/m/yRYJiAJyiM (CC0 1.0) |

### Con atribución (CC-BY 3.0)

| Modelo | Autor | Fuente |
|---|---|---|
| Herrería de la aldea ("Forge") | Don Carson | https://poly.pizza/m/2ZnLsJJL4Pe ([CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/)) |

Cambios en el juego: escalas, tintes y materiales de piedra o hierro (ver
`scripts/world/prop.gd`). El mundo se arma con `world/build_world.gd`.

## Música (`sounds/music/`)

Todos los temas son CC0 (dominio público) y salen de OpenGameArt. Se pasaron
a OGG y algunos se recortaron como loop.

| Tema en el juego | Obra | Autor | Fuente |
|---|---|---|---|
| Aldea (`aldea.ogg`) | Medieval: The Bard's Tale (versión loop) | RandomMind | https://opengameart.org/content/medieval-the-bards-tale |
| Bosque (`bosque.ogg`) | Forest Whisper Theme | Cleyton Kauffman | https://opengameart.org/content/forest-whisper-theme |
| Cementerio (`cementerio.ogg`) | Kokopelli's Graveyard Theme | Cleyton Kauffman | https://opengameart.org/content/kokopellis-graveyard-theme |
| Ruinas (`ruinas.ogg`) | Village Ruins | isaiah658 | https://opengameart.org/content/village-ruins |
| Praderas (`pradera.ogg`) | Medieval: Exploration | RandomMind | https://opengameart.org/content/medieval-exploration |
| Combate (`combate.ogg`) | Determined Pursuit (epic orchestra loop) | Emma_MA | https://opengameart.org/content/determined-pursuit-epic-orchestra-loop |
| Pantalla de título (`titulo.ogg`) | Fantasy: Lament for a Warrior's Soul | RandomMind | https://opengameart.org/content/fantasy-lament-for-a-warriors-soul |

## Sonidos nuevos

CC0 o dominio público. Los de antes (golpes, interfaz, pasos y hechizos de
`sounds/`) no están acá.

| Sonido | Autor | Fuente |
|---|---|---|
| Lluvia suave y fuerte (`sounds/ambient/weather/rain_*.ogg`) | Ylmir | https://opengameart.org/content/rain-loopable (CC0) |
| Truenos (`thunder1-4.ogg`), recortes de "Storm, Thunderbolts" | stephan (pdsounds.org) | https://commons.wikimedia.org/wiki/File:Storm_thunderbolts.ogg (dominio público) |
| Viento (`wind_loop.ogg`, "wind1") | Luke.RUSTLTD | https://opengameart.org/content/wind1 (CC0) |
| Cofre que se abre (`sounds/interact/chest/open.ogg`, mezcla de metalLatch y creak2) | Kenney | https://kenney.nl/assets/rpg-audio (CC0) |
| Monedas del herrero (`coins.ogg`, handleCoins) | Kenney | https://kenney.nl/assets/rpg-audio (CC0) |
| Yunque (`anvil1.ogg`, "Blacksmith's Hammer") | VishwaJai | https://opengameart.org/content/blacksmiths-hammer (CC0) |
| Yunque (`anvil2.ogg`, "Hammer on Anvil") | themightyglider | https://opengameart.org/content/hammer-on-anvil (CC0) |
| Gemas engarzadas (`sounds/interact/gems/`, glass) | Kenney | https://kenney.nl/assets/interface-sounds (CC0) |
| Aullido del lobo (`sounds/creatures/wolf/howl.ogg`, "Wolf howls") | US Fish & Wildlife Service | https://commons.wikimedia.org/wiki/File:Wolf_howls.ogg (dominio público) |
| Gruñidos del lobo (`attack*.ogg`, recortes de "Monster snarls") | Darsycho | https://opengameart.org/content/monster-snarls (CC0) |
| Gruñidos cortos (`growl1.ogg` "Dog Growl", `growl2.ogg` "Dog Grunt") | bonebrah, qubodup | https://opengameart.org/content/dog-growl · https://opengameart.org/content/dog-grunt (CC0) |
| Mordidas (`bite1.ogg` de RPG Sound Pack, `bite2.ogg` "Crunchy bite") | artisticdude, fvcalderan | https://opengameart.org/content/rpg-sound-pack · https://opengameart.org/content/crunchy-bite (CC0) |
| Araña (`sounds/creatures/spider/chitter*.ogg`, "bug" de 80 CC0 creature SFX) | rubberduck | https://opengameart.org/content/80-cc0-creature-sfx · https://opengameart.org/content/80-cc0-creture-sfx-2 (CC0) |
| Siseo de la araña (`hiss.ogg`, `chirp.ogg`, "Alien Sounds") | EZduzziteh | https://opengameart.org/content/alien-sounds-0 (CC0) |
