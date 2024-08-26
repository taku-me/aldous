# Aldous
![DSCF5771](https://github.com/user-attachments/assets/baf35ff5-93c9-4b87-8ceb-31c48e920e65)

Aldous is a generative audio-visual script for the Norns platform, creating an evolving tree-like structure accompanied by a responsive soundscape.

## Description

Aldous generates a dynamic, branching pattern inspired by natural growth processes. As the visual structure evolves, it triggers musical notes based on a pentatonic scale system, creating a harmonious audiovisual experience. The script features LFO-modulated parameters for continuous variation and includes a demo mode with growth and decay cycles for extended play.

## Features

- Procedurally generated branching patterns
- Evolving musical composition using a pentatonic scale system
- Visual ripple effects synchronized with audio events
- LFO-modulated parameters for scale and interval adjustments
- Demo mode with cycles of growth, decay, and pause
- Interactive controls for freezing growth and resetting the tree

## Installation

1. Connect to your Norns using SSH
2. Navigate to the `dust/code` directory
3. Clone this repository: `git clone https://github.com/yourusername/aldous.git`
4. Restart or rescan scripts on your Norns

## Demo

<img width="1388" alt="Screenshot 2024-08-25 at 14 33 09" src="https://github.com/user-attachments/assets/d27f1e8f-d2fb-4af1-b061-c91df459ca52">

https://youtu.be/cQojuEV5z34

## Usage

- Select and run the "Aldous" script on your Norns
- Use E2 to adjust the scale base value
- Use E3 to adjust the interval base value
- Press K2 to reset the tree
- Press K3 to freeze/unfreeze the tree growth

In demo mode, the script will automatically cycle through phases of growth, decay, and pause.

## Customization

You can customize various parameters at the top of the script, including:

- `DEMO_MODE`: Set to true/false to enable/disable demo mode
- `MAX_BRANCHES`: Maximum number of branches allowed
- `BOOST_DURATION` and `BOOST_FACTOR`: Control the initial growth boost of new branches
- LFO parameters for scale and interval modulation

## Contributing

Contributions, issues, and feature requests are welcome. Feel free to check issues page if you want to contribute.

## License

[MIT](https://choosealicense.com/licenses/mit/)

## Acknowledgments

- Inspired by natural growth patterns and generative art, with support from Claude
- Developed for the Norns platform by Monome
