# Search Platformer

A Godot 4.6 platformer that compares three graph search modes

## Run In Godot

1. Open the `game/` folder in Godot.
2. Run `main.tscn`.

## Run Browser Demo

```bash
cd web
python3 serve.py
```

Open `http://localhost:8000` in a browser.

## Controls

- Move: `A` / `D` or arrow keys
- Jump: `Space`, `W`, or up arrow
- Start computer run: `T` or the browser button
- Toggle graph overlay: `V`
- Restart after win or lose: `R`

## Search Modes

- Uniform Cost Search: uses cost so far
- Greedy Best-First Search: uses heuristic estimate
- A* Search: uses cost so far + heuristic estimate
