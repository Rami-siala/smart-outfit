# Outfit Assets

Outfit images are organized by style first, then by weather bucket:

- `casual/`
- `chic/`
- `sport/`

Each style folder contains:

- `normal/`
- `rainy/`
- `sunny/`

## Filename convention

Every outfit image must follow this pattern:

`<gender>_<color>_<weather>_<style>.png`

Examples:

- `female_blue_rainy_casual.png`
- `male_black_sunny_chic.png`
- `male_white_normal_sport.png`

## Rules

- Use lowercase only.
- Use underscores between tokens.
- Do not add spaces anywhere in the filename.
- Use a single image extension such as `.png`.
- Keep the filename values aligned with the folder path.

The Flutter app filters assets by folder plus filename tokens, so malformed names can prevent expected outfits from being found consistently.
