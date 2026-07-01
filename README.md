# xstyle
From Forecast to Outfit. Dress Smart Every Day

## Breaking change

Weather classification now uses inclusive thresholds:

- `temperature <= 15` returns `cold`
- `15 < temperature <= 25` returns `normal`
- `temperature > 25` returns `hot`

This means `15C` is now classified as `cold`. Any client logic, tests, or fixtures that previously treated `15C` as `normal` should be updated.
