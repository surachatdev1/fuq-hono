# Thai attendance addresses

The web build produces a static district lookup from the pinned
[GeoThai boundaries snapshot](https://github.com/GeoThai/boundaries/tree/5b0fc5e329f562152b2ffa6a3a597dd81d9a6adf).
The browser tests the selected coordinate against the polygon and uses its Thai
district and province names. Unknown points keep their coordinates. The label
is descriptive only. HONO's current areas and radii continue to govern attendance.

Credit GeoThai, from [OCHA COD-AB](https://data.humdata.org/dataset/cod-ab-tha)
and the Royal Thai Survey Department. Boundary shapes are
[CC BY 3.0 IGO](https://creativecommons.org/licenses/by/3.0/igo/) and names
from [GeoThai data](https://github.com/GeoThai/data) are
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The build combines the two levels, packs rings and adds bounding boxes.
The source geometry is simplified and labels near borders are approximate.

The Thai CC Tower preset address and coordinate are listed by
[Thailand YellowPages](https://www.yellowpages.co.th/en/profile/Thai-CC-Tower-3bAeJS6Im).
