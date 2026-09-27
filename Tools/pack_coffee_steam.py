"""Pack the exported coffee-steam PNG sequence into a cropped atlas.

Run from the project root with the workspace Python runtime. The common crop
is the union of every frame's nontransparent pixels, so animation framing does
not move between frames.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets/Assets for new version of game/wape_anim/Comp 1"
ATLAS_PATH = ROOT / "Assets/Desk/steam_atlas.png"
RESOURCE_PATH = ROOT / "Data/coffee_steam.tres"
FPS = 30.0
COLUMNS = 8


def main() -> None:
    frames = sorted(SOURCE.glob("wape_anim_*.png"))
    if not frames:
        raise SystemExit(f"No wape_anim_*.png frames found in {SOURCE}")

    union = None
    for path in frames:
        with Image.open(path) as source:
            if source.size != (1920, 1080):
                raise ValueError(f"Unexpected frame size for {path.name}: {source.size}")
            bounds = source.convert("RGBA").getchannel("A").getbbox()
        union = bounds if union is None else (
            min(union[0], bounds[0]), min(union[1], bounds[1]),
            max(union[2], bounds[2]), max(union[3], bounds[3]),
        )

    left, top, right, bottom = union
    cell_width, cell_height = right - left, bottom - top
    rows = (len(frames) + COLUMNS - 1) // COLUMNS
    atlas = Image.new("RGBA", (COLUMNS * cell_width, rows * cell_height), (0, 0, 0, 0))
    regions = []
    for index, path in enumerate(frames):
        with Image.open(path) as source:
            crop = source.convert("RGBA").crop(union)
        x, y = (index % COLUMNS) * cell_width, (index // COLUMNS) * cell_height
        atlas.alpha_composite(crop, (x, y))
        regions.append((x, y, cell_width, cell_height))

    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(ATLAS_PATH, optimize=True)

    lines = [
        "[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]" % (len(frames) + 2),
        "",
        '[ext_resource type="Texture2D" path="res://Assets/Desk/steam_atlas.png" id="1_atlas"]',
    ]
    for index, (x, y, width, height) in enumerate(regions):
        lines.extend([
            "",
            f'[sub_resource type="AtlasTexture" id="AtlasTexture_{index}"]',
            'atlas = ExtResource("1_atlas")',
            f"region = Rect2({x}, {y}, {width}, {height})",
        ])
    frame_refs = ", ".join(
        f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{index}")}}'
        for index in range(len(frames))
    )
    lines.extend([
        "",
        "[resource]",
        "animations = [{",
        f'"frames": [{frame_refs}],',
        '"loop": true,',
        '"name": &"default",',
        f'"speed": {FPS:.1f}',
        "}]",
        "",
    ])
    RESOURCE_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Frames: {len(frames)}; common crop: ({left}, {top})..({right}, {bottom})")
    print(f"Atlas: {atlas.width}x{atlas.height}; {COLUMNS} columns; {FPS:g} fps")


if __name__ == "__main__":
    main()
