"""Rebuild deterministic prototype levels and their constructive solutions.

Run from PocketPuzzle: python tools/generate_levels.py
Only Python's standard library is required. Runtime gameplay uses GDScript.
"""
from collections import deque
import json
from pathlib import Path
import random

LEVEL_COUNT = 150


def parcel_solution(queues, route, capacity=3):
    initial = ((0,) * len(queues), (), 0)
    pending = deque([(initial, [])])
    seen = {initial}
    while pending:
        (indices, buffer, delivered), path = pending.popleft()
        if delivered == len(route):
            return path
        for lane, queue in enumerate(queues):
            if indices[lane] == len(queue):
                continue
            color = queue[indices[lane]]
            waiting = list(buffer)
            count = delivered
            if color == route[count]:
                count += 1
            elif len(waiting) < capacity:
                waiting.append(color)
            else:
                continue
            while count < len(route) and route[count] in waiting:
                waiting.remove(route[count])
                count += 1
            positions = list(indices)
            positions[lane] += 1
            state = (tuple(positions), tuple(sorted(waiting)), count)
            if state not in seen:
                seen.add(state)
                pending.append((state, path + [lane]))
    return None


def make_parcels():
    levels = []
    for number in range(1, LEVEL_COUNT + 1):
        rng = random.Random(7100 + number)
        colors = 3 if number <= 15 else 4
        length = (2 if number <= 5 else 3 if number <= 15 else
                  4 if number <= 60 else 5 if number <= 100 else 6)
        if number == 1:
            queues = [[0, 0], [1, 1], [2, 2]]
        elif number == 2:
            queues = [[1, 0], [0, 1], [2, 2]]
        elif number == 3:
            queues = [[1, 0], [2, 1], [0, 2]]
        else:
            queues = None
        for _ in range(10000):
            if queues is None:
                pool = [c for c in range(colors) for _ in range(length)]
                rng.shuffle(pool)
                candidate = [pool[i::3] for i in range(3)]
            else:
                candidate = queues
            route = ([c for c in range(colors) for _ in range(length)] if length <= 4
                     else [c for _ in range(length) for c in range(colors)])
            solution = parcel_solution(candidate, route)
            if solution is not None:
                # Reject later boards solved entirely without a waiting parcel.
                indices = [0, 0, 0]
                needs_buffer = False
                for lane in solution:
                    target = route[sum(indices)]
                    if candidate[lane][indices[lane]] != target:
                        needs_buffer = True
                        break
                    indices[lane] += 1
                if number <= 3 or needs_buffer:
                    break
        else:
            raise RuntimeError(f"No parcel board for level {number}")
        levels.append(dict(queues=candidate, route=route, capacity=3,
                           solution=solution, seed=7100 + number))
    return levels


GATES = [dict(side="right", start=1, span=2),
         dict(side="down", start=2, span=2),
         dict(side="left", start=2, span=2),
         dict(side="up", start=1, span=2)]
DIRECTIONS = [(1, 0), (0, 1), (-1, 0), (0, -1)]


def make_blocks():
    levels = []
    for number in range(1, LEVEL_COUNT + 1):
        rng = random.Random(9200 + number)
        pieces, solution = [], []
        count = min(10 if number > 30 else 7, 1 + (number + 1) // 3)
        for index in range(count):
            color = index % (3 if number < 9 else 4)
            gate = GATES[color]
            width, height = (1, 1)
            if number >= 6 and index % 2 == 0:
                width, height = rng.choice([(2, 1), (1, 2)])
            occupied = {(p['x'] + x, p['y'] + y) for p in pieces
                        for x in range(p['w']) for y in range(p['h'])}

            def valid(x, y):
                return (x >= 0 and y >= 0 and x + width <= 5 and y + height <= 5
                        and all((x + dx, y + dy) not in occupied
                                for dx in range(width) for dy in range(height)))

            edge = []
            if color in (0, 2):
                edge = [(5 - width if color == 0 else 0, y)
                        for y in range(gate['start'], gate['start'] + gate['span'] - height + 1)]
            else:
                edge = [(x, 5 - height if color == 1 else 0)
                        for x in range(gate['start'], gate['start'] + gate['span'] - width + 1)]
            edge = [position for position in edge if valid(*position)]
            if not edge:
                continue
            start = rng.choice(edge)
            paths = {start: []}
            pending = deque([start])
            while pending:
                position = pending.popleft()
                for direction in DIRECTIONS:
                    dest = (position[0] + direction[0], position[1] + direction[1])
                    if valid(*dest) and dest not in paths:
                        paths[dest] = paths[position] + [direction]
                        pending.append(dest)
            choices = [p for p in paths if len(paths[p]) >= (1 if number < 4 else 3)]
            if not choices:
                continue
            destination = rng.choice(choices)
            piece_id = len(pieces)
            pieces.append(dict(x=destination[0], y=destination[1], w=width,
                               h=height, color=color))
            reverse_moves = [[piece_id, -dx, -dy]
                             for dx, dy in reversed(paths[destination])]
            reverse_moves.append([piece_id, *DIRECTIONS[color]])
            solution = reverse_moves + solution
        assert pieces
        levels.append(dict(size=5, pieces=pieces, gates=GATES,
                           solution=solution, seed=9200 + number))
    # A quarter-turn maps each gate exactly onto the next gate in this layout.
    # Rotate duplicate boards, including their solution, to keep the collection
    # visually distinct without changing its constructive solvability proof.
    seen = set()
    for level in levels:
        for turns in range(4):
            key = tuple(sorted((p['x'], p['y'], p['w'], p['h'], p['color'])
                               for p in level['pieces']))
            if key not in seen:
                seen.add(key)
                break
            for piece in level['pieces']:
                piece['x'], piece['y'], piece['w'], piece['h'], piece['color'] = (
                    5 - piece['y'] - piece['h'], piece['x'], piece['h'],
                    piece['w'], (piece['color'] + 1) % 4)
            level['solution'] = [[i, -dy, dx] for i, dx, dy in level['solution']]
        else:
            raise RuntimeError('Duplicate Block board after all rotations')
    return levels


if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[1] / "assets/data/levels.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(dict(parcel=make_parcels(), block=make_blocks()),
                                      indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {LEVEL_COUNT} Parcel Sort + {LEVEL_COUNT} Block Exit levels to {destination}")
