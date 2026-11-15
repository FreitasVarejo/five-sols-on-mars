# Five Sols on Mars

The sections below mirror our NASA Space Apps Challenge 2026 submission, field by field and in the order of the form. The last section, "For developers", is about the code.

## Project name

Five Sols on Mars

## High-level summary

Five Sols on Mars is a browser game for children aged 7 to 12. The player commands an outpost in Gale crater for five Martian days, and has to keep the crew alive while sending science home.

Each sol starts with a plan, with no clock running. The player splits the day's energy between making oxygen and running science tasks, and three gauges (energy, oxygen and radiation margin) show the result before the plan is confirmed. Then comes a 60-second shift in real time, in which a solar storm, a dust storm or a broken oxygen generator tests that plan. No choice is free. Energy kept in the battery is science not done. Sheltering from radiation stops the work. Filling the oxygen tank leaves no battery for the dust storm.

There is no game over. When a gauge runs out, the base goes into safe mode, the screen says why and shows the real case behind it, and the mission goes on to a debrief.

The space weather is real. The mission replays the week of 19 May 2024 with the NASA DONKI forecasts for Mars, and the storm is sized from the Curiosity radiation readings of 20 May 2024 in NASA RadLab. The game's Sources tab says where each real-world number comes from.

The game runs in the browser with no download, no account and no tracking, in English and Portuguese. A child leaves it knowing one real constraint of living away from Earth: the safe choice always costs something.

## Demo link

TODO(owner): public video link, no login required.

| Time | On screen | Caption |
|---|---|---|
| 0:00–0:03 | The room at rest, the window onto Mount Sharp, the title on top (added in the edit) | Five Sols on Mars · TODO(owner): team name · NASA Space Apps 2026 · Junior Astronaut Mission Trainer |
| 0:03–0:07 | Pan across the room: radiation meter, shelter button, Earth screen, energy and oxygen gauges | You command a Mars base in Gale crater. Ages 7 to 12. |
| 0:07–0:11 | The plan of sol 1: oxygen goes up, three science tasks are ticked, the bars show "before → after" and "Air for 2 sols" | Every choice has a cost |
| 0:11–0:17 | The card from Earth with the warning and the date of the data; cut to the shift of sol 2: the meter climbs, the alert lights, the shelter button is pressed, the card says what sheltering costs, the shutter closes | Real space weather: NASA DONKI · Curiosity RAD (NASA RadLab), May 2024 |
| 0:17–0:21 | The plan of sol 3 under "Dust storm: the solar panel produces 10%", the energy bar falling; cut to the dust in the window | Opportunity, 2018: 645 → 22 Wh |
| 0:21–0:25 | The safe mode screen of a dust sol with the real case; cut to the report with the stars and "What really happened" | No game over. Safe mode, then a debrief. |
| 0:25–0:29 | The Sources tab, scrolling down to the credits; cut to the report with "Free play", the click, and the address of the game (added in the edit) | Sources tab: where each number comes from · Browser, no account, no tracking · English and Portuguese |

## Final project link

https://freitasvarejo.github.io/five-sols-on-mars/

## Detailed description

**Play it:** https://freitasvarejo.github.io/five-sols-on-mars/ (any browser, mouse or touch, about 10 minutes for an adult; a young reader may need 20 to 30). **Code:** https://github.com/FreitasVarejo/five-sols-on-mars

### What it does

The player sits in the command module of a Mars outpost in Gale crater, the crater where Curiosity works. The room is a pixel-art panorama: a window onto Mount Sharp, the energy and oxygen gauges on the console, the radiation meter, the shelter button and a terminal, the Panel.

A mission lasts five sols. Each sol has three parts.

1. **Plan, with no clock.** A message from Earth brings the space-weather notice. The player sets how much energy goes to the oxygen generator and which science tasks to run. Each gauge shows "before → after" for the choice, and the oxygen gauge says "air for N sols". Energy that is left over goes to the battery by itself. The battery has a ceiling, and the surplus is lost.
2. **Shift, 60 seconds in real time, with nothing to read.** The player runs the science tasks, repairs what broke and watches the radiation meter. A sun crossing a bar at the top of the screen is the clock, and the room turns blue as it sets. Work outside is done through the base's cameras: the player aims ChemCam's laser at points on a rock, and fits the right part into the broken oxygen generator. A task counts only when the player finishes it.
3. **End of sol, with no clock.** The base writes its own log of what happened and what it cost, and the player sends it to Earth. The night heating then comes out of the battery.

At the end of sol 5 a ship arrives and takes the science to Earth. The mission report is that cargo: the science sent, the radiation margin left, the number of safe modes, a rating of one to three stars and a "What really happened" section about the real event.

The five-sol mission is the same for every player: a guided first sol, a solar storm on sol 2, a dust storm on sols 3 and 4, and a generator failure on sol 5. After the report, "Free play" starts a mission in which the sol of each event is drawn.

### The trade-offs

Three gauges, all read the same way: full is good, empty is danger. Each one has an icon, a label and a number, never colour alone.

| Gauge | Fills with | Drains with |
|---|---|---|
| Energy (battery) | The solar panel, every sol; much less under dust | Night heating, the oxygen generator, science tasks |
| Oxygen (tank) | A generator like MOXIE, which costs energy | The crew, every sol |
| Radiation margin | Never refills | Every sol's background; far more in a solar storm |

How the game answers the challenge's guiding questions:

- **Oxygen reserve or a research opportunity.** Oxygen and science are paid from the same energy. The plan puts the two controls on one screen and shows "air for N sols" above the science the plan earns. When the generator breaks it makes no oxygen until it is repaired, and the tank is what the crew breathes.
- **Shielding against a radiation event or energy for the night.** Real crews shield by moving mass: the Artemis II procedure has the crew build a shelter from stowage, which costs work time and no power. So in the game the shelter costs science. Tasks done before sheltering count, and after it the crew does no more tasks in that shift. Shelter too early and science is lost for nothing; too late and the crew takes the dose. The squeeze on night energy is in the dust storm: the panel falls to a tenth for two sols, the night heating still has to be paid, and only a battery charged beforehand carries the base through. Opportunity in 2018 and InSight in 2022 both ended when dust left them without power.
- **Communication delay.** There is no conversation with Earth and no assistant on board. Earth sends a package in the morning, and during the shift the player decides alone, as a crew would with a signal that takes 3 to 22 minutes each way.
- **Food.** The challenge advises two or three core resources, and we kept energy, oxygen and radiation. Food is not a gauge; growing a plant is one of the science tasks.

We measured the mission by playing the published build. Putting everything into science sends 9 points of science and ends one sol in safe mode. A balanced plan sends 5 with no safe mode. Filling the oxygen tank first sends none and ends two sols in safe mode, because the dust arrives with the battery empty. The best plan without a safe mode sends 7. No strategy is best at both science and safety.

### Learning from failure

When energy, oxygen or the radiation margin runs out, the base goes into safe mode, as real spacecraft do: it cuts what is not essential, the crew is safe and science stops. A screen explains the cause in a few short sentences, with a real number or case: Opportunity in 2018 for energy, the October 1989 reference event for radiation, 0.9 kg of oxygen per person per day for oxygen. In most cases the cause is named by what led to it, such as the dust that stopped the panel or the generator nobody fixed, and not only by the gauge that hit zero.

If some plan can still save the sol, the simulator restarts that sol at the plan. If no plan can, because the cause came from earlier sols, the sol passes in safe mode and the screen says the cause came earlier. The child never replays a sol that cannot be won.

### NASA data, and why

- **NASA DONKI (CCMC), WSA-ENLIL simulations.** DONKI is the NASA record that says a solar storm is predicted to reach Mars before it arrives, and that is what turns the warning into a decision. A script downloads the last 60 days when we build the game, and the game shows the date of the data; stored data is never presented as live. The mission uses the DONKI record for 19 to 21 May 2024, when five arrivals at Mars were predicted.
- **NASA RadLab (Open Science Data Repository), Curiosity RAD.** On 20 May 2024 the average radiation reading of the day at Curiosity was about 17 times that of the five days before (our calculation from the RadLab samples). That ratio sets how much a solar storm takes from the radiation margin compared with a normal sol. It is a dose measured on the surface of Mars, in the crater where the game takes place.
- **NASA BVAD Rev2 (2022):** each person breathes about 0.9 kg of oxygen per day.
- **MOXIE (NASA/JPL):** oxygen made from the carbon dioxide of the Martian air, and what it costs in power. The game calls its generator "a giant version of MOXIE, which does not exist yet".
- **NASA-STD-3001:** volume 1 gives the 250 mSv design limit for the reference solar event of October 1989. Volume 2 guided the terminal: only what is needed on the screen, shallow navigation (we keep four tabs and no sub-tabs), and red and yellow only for alerts.
- **Opportunity, 2018:** the panel fell from 645 to 22 Wh in the dust storm.

What we simplified:

- Radiation is scaled up. In reality five sols in Gale use less than 1.5% of the limit; in the game each sol stands for many days of radiation. The Sources tab says so.
- The dust storm lasts two sols. The real one lasted from 30 May 2018 until August or September. The Sources tab says so.
- The night heating is our simplification of "the rover ran out of power".
- The shelter lets through one fifth of the storm dose. Inside Orion, the best-shielded spot saw about a quarter of the dose rate of the least shielded one, in passes similar to large solar events (George et al., Nature, 2024).
- The ship arrives after five sols. In reality the path to Mars opens every 26 months, and the report says so.
- Gauges and costs are in simulator units, not in kWh or kg.

### Made for children

- All reading happens with the clock stopped. The shift is click-only.
- The first sol is guided by cards from Earth, one step at a time.
- Colour is never the only signal. Green marks what can be clicked, red and yellow mark alerts, blue marks what comes from Earth.
- Nothing flashes more than three times per second, every sound has a visual equivalent, and there is a mute button.
- It works with a mouse or a finger. On a phone held upright, the page asks the player to turn it.
- English by default, Portuguese with the selector on the screen.
- No death, no horror.

### Privacy

The game makes no requests to third parties: no analytics, no cookies, no login. The font and the NASA data are packed into the build, so a child's browser never contacts NASA or anyone else to play. What the game remembers (the mute setting and that the mission was finished) stays in the browser's local storage. The host, GitHub Pages, logs visitor IP addresses, as its documentation states.

### How it is built

- **Engine:** Godot 4.7.2, GDScript, Compatibility renderer, single-threaded Web export, 640×360 pixel art.
- **Art:** the room and the Mars exterior are modelled and rendered by Python scripts in Blender (`bpy`, Cycles), in the Apollo palette by AdamCYounis. Each state of the room is one pre-rendered panorama, curved in the game by a CC0 panorama shader. No image was generated by AI.
- **Data:** a Python script (standard library only) downloads DONKI at build time and writes the JSON the game reads.
- **Rules:** one model script holds the rules, with unit tests. The strategies above were measured by playing the published build in the browser with Playwright.
- **Hosting:** GitHub Pages.
- **Languages:** GDScript, Python, Godot shading language, Bash.

### What comes next

Free play in blocks of five sols: every block a ship brings cargo and a fresh crew, each solar storm re-enacts a real one from the latest DONKI data, the dust lasts longer each block, and the run ends at the first failure with a record to beat. After that, the radiation meter driven by the Curiosity RAD curve of May 2024, hour by hour.

## Use of SI

We used Claude, by Anthropic (the Claude apps and Claude Code, a coding agent), throughout the project. Where and how:

- **Research.** Claude searched and summarised sources on life support, radiation, power, Mars operations, crew displays, communication delay and games for children aged 7 to 12. Every number that reached the game was then checked against the source cited on screen, primary wherever we found one: NASA documents, JPL releases and the DONKI and RadLab APIs. Some first answers were wrong and were corrected this way, for example the oxygen a person breathes per day and what caused the radiation peak of 20 May 2024.
- **Design.** Claude proposed options, questioned our choices, simulated the five sols under three strategies and reviewed the design against the challenge text. The decisions are ours.
- **Code.** Most of the code was written by Claude Code from written briefings by the team: the GDScript, the Blender Python scripts that model and render the art, the DONKI download script, the tests and the publish script. We reviewed the changes, played each build and decided what went in. TODO(owner): say what the owner and the teen teammate wrote or changed by hand.
- **Art and sound.** No image and no sound in the game came from a generative AI model. The pixel art is rendered by the Blender scripts. The intro slides of the minigames show real NASA photos, reduced to the game's palette by a script. The sounds are CC0 recordings by the authors credited below, except the radiation alarm, the trip sounds and the greenhouse sounds, which Python scripts Claude wrote synthesize from plain tones.
- **Demo video.** A team member narrates it. The footage is a recording of the published game, played by Claude Code through Playwright and cut with ffmpeg; the captions are burned in.
- **Submission check.** Before submitting, Claude Code played the published build from start to finish through Playwright, measured the strategies quoted above and checked each statement of this text against what it saw.
- **Text.** The on-screen texts in English and Portuguese, the video script and this submission were drafted with Claude and edited by the team.
- **In the game.** None. No model runs in the game, and it calls no AI service.

A dated log of this use is in the repository, in `docs/uso-de-si.md` (in Portuguese); this section is its English summary.

## NASA Data

- **NASA DONKI**, Space Weather Database Of Notifications, Knowledge, Information (CCMC, NASA Goddard), WSA-ENLIL simulations: https://ccmc.gsfc.nasa.gov/tools/DONKI/ (API: https://ccmc.gsfc.nasa.gov/DONKI/WS/get/WSAEnlilSimulations). The predicted arrivals of coronal mass ejections at Mars: the last 60 days, downloaded at build time and shown with their date, and the record of May 2024 used by the mission.
- **NASA RadLab**, Open Science Data Repository: https://visualization.osdr.nasa.gov/radlab/gui/data-api/. The dose-rate readings of Curiosity RAD in May 2024, which sets the size of the solar storm in the game.
- **JPL, "NASA Watches Mars Light Up During Epic Solar Storm"** (10 June 2024): https://www.jpl.nasa.gov/news/nasa-watches-mars-light-up-during-epic-solar-storm. The account of the event of 20 May 2024, used in the warning and in "What really happened".
- **NASA Life Support Baseline Values and Assumptions Document (BVAD), Rev2** (2022): https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf. Oxygen per person per day.
- **NASA-STD-3001, Volume 1, Rev C:** https://standards.nasa.gov/sites/default/files/standards/NASA/C/nasa-std-3001-vol-1-rev-c-signature.pdf. The design limit for the reference solar event. **Volume 2, Rev C:** https://www.nasa.gov/wp-content/uploads/2020/10/2022-04-08_nasa-std-3001_vol_2_rev_c_final.pdf. The display and alert rules followed by the terminal.
- **MOXIE** (NASA/JPL, 6 September 2023): https://www.jpl.nasa.gov/news/nasas-oxygen-generating-experiment-moxie-completes-mars-mission/. The base of the oxygen generator. **A Day Full of MOXIE** (NASA, 31 August 2022): https://science.nasa.gov/blog/a-day-full-of-moxie/. The power behind our estimate of its cost.
- **Opportunity** (NASA, 2019): https://www.nasa.gov/press-release/nasas-record-setting-opportunity-rover-mission-on-mars-comes-to-end. **InSight** (JPL, 2022): https://www.jpl.nasa.gov/news/nasa-retires-insight-mars-lander-mission-after-years-of-science. The real cases behind the dust storm.
- **Artemis II radiation shelter** (NASA Goddard, 16 March 2026): https://science.nasa.gov/missions/artemis/artemis-2/to-protect-artemis-ii-astronauts-nasa-experts-keep-eyes-on-sun/. The base of the shelter that costs time.
- **Communication delays for crewed Mars missions** (NASA Langley): https://ntrs.nasa.gov/api/citations/20220013418/downloads/ASCEND-Communication%20Delays%2C%20Disruptions%2C%20and%20Blackouts%20for%20Crewed%20Mars%20Missions.pdf. Why a question and its answer take at least twice the delay. The 3 to 22 minutes each way come from NASA: https://science.nasa.gov/mars/mars-2020-perseverance/speaking-percys-language-how-to-talk-so-perseverance-will-listen/
- **Mars launch windows** (NASA): https://science.nasa.gov/planetary-science/programs/mars-exploration/mission-timeline/. The 26 months in the report.
- **"Sunset in Mars' Gale Crater"** (Curiosity, sol 956): https://science.nasa.gov/photojournal/sunset-in-mars-gale-crater. The reference for the blue light at the end of the shift.

The game uses no NASA image and no NASA insignia.

## Space Agency Partner Data and other references

**Partner agencies**

- George et al., "Space radiation measurements during the Artemis I lunar mission", Nature 634, 48–52 (2024): https://www.nature.com/articles/s41586-024-07927-7. A paper by NASA, DLR and ESA researchers. We use its fourfold difference in dose rate between shielding locations inside Orion. TODO(owner): check, while logged in to the site, whether ESA and DLR are on the 2026 partner agency list (the paper has ESA and DLR authors, checked on PMC11446838 on 15 Nov). If the greenhouse task does not exist in the build, no CSA material was used and none is cited.

**Code, art and sound by others**

- Godot Engine 4.7.2 (MIT): https://godotengine.org/
- Shader "Accurate FNAF Clickteam Panorama" by b en (CC0), with one sampling change: https://godotshaders.com/shader/accurate-fnaf-panorama/
- Cupcakes Framework by Oplexitie (MIT) inspired the edge-pan camera; no code was copied: https://github.com/Oplexitie/Cupcakes-Framework
- Font Open Sans SemiBold (SIL Open Font License 1.1), bundled with Godot.
- Palette Apollo by AdamCYounis: https://lospec.com/palette-list/apollo
- Sounds, all CC0: "metal_close_01" from "100 CC0 metal and wood SFX" by rubberduck (https://opengameart.org/content/100-cc0-metal-and-wood-sfx); "qubodup-DoorClose07" from "Door Open, Door Close Set" by qubodup (https://opengameart.org/content/door-open-door-close-set); "back_004", "confirmation_001", "bong_001", "maximize_008" and "minimize_008" from "Interface Sounds" by Kenney (https://opengameart.org/content/interface-sounds); "Plug-out" from "Plug In, Plug Out" by cleytonkauffman (https://opengameart.org/content/sfx-plug-in-plug-out). The radiation alarm, the trip sounds and the greenhouse sounds are synthesized by the team's own scripts, with no third-party sample.

**Other sources cited in the game or used in the design**

- The Planetary Society, citing JPL, for Opportunity's 645 and 22 Wh: https://www.planetary.org/articles/06-mer-update-opportunity-dust-storm-sleep
- JPL Horizons, for the 16-minute light time from Mars to Earth on 19 May 2024: https://ssd.jpl.nasa.gov/horizons/
- NASA, Mars Science Laboratory, for the 254 days of Curiosity's trip (launch 26 November 2011, landing 6 August 2012): https://science.nasa.gov/mission/msl-curiosity/
- The Veggie plant chamber on the ISS, behind the greenhouse task: [Vegetable Production System](https://en.wikipedia.org/wiki/Vegetable_Production_System), [ScienceDaily, 19 Jan 2016](https://www.sciencedaily.com/releases/2016/01/160119143038.htm), [Scientific American](https://www.scientificamerican.com/article/a-garden-grows-in-space-first-zinnias-bloom-to-an-astronaut-s-delight/) and the [Advanced Plant Habitat fact sheet (NASA)](https://www.nasa.gov/sites/default/files/atoms/files/advanced-plant-habitat.pdf)
- Guzewich et al. (2019), for the dates of the 2018 dust storm. TODO(owner): add the link.
- Hassler et al., Science (2014), for the dose on the surface of Mars: https://www.science.org/doi/10.1126/science.1244797
- Sinha & Kapur (2021), on when instruction should come before problem solving: https://eric.ed.gov/?id=EJ1308129
- WCAG 2.2, Target Size (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- Nielsen Norman Group, Usability Testing with Minors: https://www.nngroup.com/articles/usability-testing-minors/

**Tools:** Blender, Playwright, Node.js, ffmpeg, GitHub Pages, and Claude by Anthropic (see Use of SI).

## For developers

Play: https://freitasvarejo.github.io/five-sols-on-mars/

Built with Godot 4.7.2 (Compatibility renderer, single-threaded Web export). Code and repository are under the MIT license (see `LICENSE`). Third-party credits and licenses are in the last field above and in the "Credits and licenses" list below.

### Run

Open the project folder in Godot 4.7.2 (exactly this version) and run it. The game is tested in the Web export, in the browser, not only in the editor. Unit tests are headless scripts in `tests/`, for example:

```sh
godot --headless --path . --script tests/test_missao.gd
```

### Build and publish

```sh
scripts/publicar.sh
```

Needs Godot 4.7.2 with the export templates of the same release. It downloads the latest DONKI data, exports the `Web` preset to `build/web/` and force-pushes it to the `gh-pages` branch.

### Privacy

No analytics, cookies, login or calls to third parties. Progress is kept only in the browser's `localStorage`.

### Data in the build

All data is embedded in the build. The game never fetches it live, so no child's IP address goes to NASA.

- **NASA DONKI (CCMC)**, WSA-ENLIL simulations of CMEs arriving at Mars (API: https://ccmc.gsfc.nasa.gov/DONKI/WS/get/WSAEnlilSimulations)
  - The build downloads the last 60 days with `scripts/baixar_donki.py` into `dados/donki.json`. The game shows it, with the date it was collected, on the storm warning card.
  - The mission always uses the historical cut of 19 to 21 May 2024, from `dados/donki_historico_2024-05.json`.
- **Curiosity RAD, NASA RadLab (OSDR)**, absorbed dose rate at Gale Crater (MSL-RAD-Surface), for May 2024, saved in the same historical file: https://visualization.osdr.nasa.gov/radlab/gui/data-api/

The "sources" tab in the game lists the source of each fact (strings in `textos/textos.csv`):

- Storm from the Sun, CMEs predicted at Mars: NASA DONKI (CCMC), WSA-ENLIL.
- Oxygen a person breathes per day: NASA, BVAD Rev2 (2022).
- Energy cost of oxygen from a giant MOXIE: team estimate from MOXIE data (NASA, 2022).
- Radiation limit for the reference solar event of October 1989: NASA-STD-3001, vol. 1 Rev C (V1 4031).
- Curiosity radiation jump on 20 May 2024: Curiosity RAD, NASA RadLab.
- Radiation scale (each sol stands for many days): team estimate from Curiosity RAD data (SwRI, 2013; NASA, 2024) and NASA-STD-3001.
- Opportunity's panel power in the 2018 dust storm and its dates: The Planetary Society, citing JPL; dates from NASA/JPL and Guzewich et al. (2019).
- Message delay between Earth and Mars: NASA.

The shelter in the game lets through 1/5 of the storm dose. The closest real number is a simulation of Orion's storm shelter, which cuts the peak of the October 1989 event about 4 times: George et al., Nature (2024).

### Credits and licenses

Code and the repository are MIT. The game shows a short version of this list at the end of the "sources" tab. The same credits, in the form used for the submission, are in the field "Space Agency Partner Data and other references" above.

- [Godot Engine](https://godotengine.org/) (MIT). The copyright and license notice is below.
- Font: the game uses Godot's default font, Open Sans SemiBold (OFL-1.1). No other font file is in the project.
- Shader "Accurate FNAF Clickteam Panorama" by b en (CC0), with one sampling change: https://godotshaders.com/shader/accurate-fnaf-panorama/
- The edge-pan camera was inspired by the [Cupcakes Framework](https://github.com/Oplexitie/Cupcakes-Framework) by Oplexitie (MIT). No code was copied.
- Sound "metal_close_01" from the pack "100 CC0 metal and wood SFX" by rubberduck (CC0), used for the window shutter: https://opengameart.org/content/100-cc0-metal-and-wood-sfx
- Sound "qubodup-DoorClose07" from "Door Open, Door Close Set" by qubodup (CC0), used for the window shutter: https://opengameart.org/content/door-open-door-close-set
- Sounds "back_004", "confirmation_001", "bong_001", "maximize_008" and "minimize_008" from "Interface Sounds" by Kenney (CC0), pitched down, used for button clicks and the terminal: https://opengameart.org/content/interface-sounds
- Sound "Plug-out" from "Plug In, Plug Out" by cleytonkauffman (CC0), pitched down, used for the safe mode: https://opengameart.org/content/sfx-plug-in-plug-out
- The radiation alarm (`assets/sons/alarme.ogg`) was made by the team with `scripts/gerar_alarme.py`: synthesized tones, no third-party sample.
- The trip sounds (`assets/sons/viagem_ignicao.ogg` and `assets/sons/viagem_pouso.ogg`) were made by the team with `scripts/gerar_som_viagem.py`: synthesized, no third-party sample.
- The greenhouse sounds (`assets/sons/estufa_*.ogg`) were made by the team with `scripts/gerar_som_estufa.py`: synthesized, no third-party sample.
- The greenhouse task is based on the Veggie plant chamber on the ISS (pink light from red and blue LEDs, a green light so astronauts see the plant's real color, the 2015-16 zinnias that wilted and grew mold). Using the green light as a diagnosis lens is our own inference, not a NASA fact. Sources: [Vegetable Production System](https://en.wikipedia.org/wiki/Vegetable_Production_System), [ScienceDaily, 19 Jan 2016](https://www.sciencedaily.com/releases/2016/01/160119143038.htm), [Scientific American](https://www.scientificamerican.com/article/a-garden-grows-in-space-first-zinnias-bloom-to-an-astronaut-s-delight/) and the [Advanced Plant Habitat fact sheet (NASA)](https://www.nasa.gov/sites/default/files/atoms/files/advanced-plant-habitat.pdf).
- Art: renders made by the team with scripts for Blender (`arte/blender/`), in the [Apollo palette](https://lospec.com/palette-list/apollo) by AdamCYounis. No image-generation AI. The only third-party images are the NASA photos listed under "Photos" below. Some PNGs (arrows, shutter layer) are generated by scripts in `scripts/`, and icons and bars are drawn in code.
- AI use: the code and scripts were written with help from Claude Code. Each block of work is logged in [`docs/uso-de-si.md`](docs/uso-de-si.md) (in Portuguese).

### Photos

The intro slides of the minigames (ChemCam, sample, plant, generator) show real photos. All of them are NASA images, credited NASA or NASA/JPL-Caltech (public domain), and the game credits line says so. The originals are not in the repo: `scripts/reduzir_foto.py` (Pillow and numpy, no AI) crops each photo, shrinks it and takes it to the Apollo palette of the renders, and the results are in `assets/fotos/`.

| File | Photo | Credit | Source |
|---|---|---|---|
| `chemcam.png` | PIA13809, "Top of Mars Rover Curiosity's Remote Sensing Mast" | NASA/JPL-Caltech | https://science.nasa.gov/photojournal/top-of-mars-rover-curiositys-remote-sensing-mast |
| `amostra.png` | PIA24808, "Perseverance Sample Tube 266" | NASA/JPL-Caltech | https://science.nasa.gov/photojournal/perseverance-sample-tube-266 |
| `amostra_2.png` | PIA24799, "Sample Tube in Perseverance's Coring Drill" | NASA/JPL-Caltech | https://science.nasa.gov/photojournal/sample-tube-in-perseverances-coring-drill |
| `planta.png` | iss040e009125, "Veg-01 Plant Harvest" | NASA | https://images.nasa.gov/details/iss040e009125 |
| `planta_2.png` | iss046e001336, "Zinnia Flowers Starting to Grow on the International Space Station" | NASA | https://www.nasa.gov/image-feature/zinnia-flowers-starting-to-grow-on-the-international-space-station |
| `gerador.png` | PIA23154, "This Is One Mars Rover With MOXIE" | NASA/JPL-Caltech | https://science.nasa.gov/photojournal/this-is-one-mars-rover-with-moxie |

To reproduce (`ORIGINAL` is the photo downloaded from the page above; the crop is `LEFT,TOP,RIGHT,BOTTOM` in pixels of the original):

```sh
scripts/reduzir_foto.py PIA13809.jpg assets/fotos/chemcam.png --recorte 1450,280,3850,1900 --largura 200
scripts/reduzir_foto.py PIA24808.jpg assets/fotos/amostra.png --recorte 840,60,1880,3860 --largura 52
scripts/reduzir_foto.py PIA24799.jpg assets/fotos/amostra_2.png --recorte 247,214,1368,1014 --largura 144
scripts/reduzir_foto.py iss040e009125.jpg assets/fotos/planta.png --recorte 470,220,1000,610 --largura 120
scripts/reduzir_foto.py iss046e001336.jpg assets/fotos/planta_2.png --recorte 290,220,590,650 --largura 76
scripts/reduzir_foto.py PIA23154.jpg assets/fotos/gerador.png --recorte 3750,1050,5350,2450 --largura 200
```

### Godot Engine license

This game is made with Godot Engine, which is distributed under the MIT license:

```
Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
