# Abstract login artwork

Approved poster direction: oversized acid-mint italic typography behind warm palm-facing 3D hands, midnight navy grain, refractive glass and an ultramarine orbit.

Production assets generated with the built-in image tool from the user-approved poster:

- `abstract-glass.webp`: remove all lettering, logos, footer and hand; preserve the navy grain, glass ribbons, coral glints and ultramarine orbit. This is the shared background for both stages.
- `palm-rise.webp`: extract only the palm-facing adult hand and long navy cuff, preserving composition, lighting, anatomy and true transparency; no raised-finger nail visible.

Assets are WebP encoded at quality 85 with the generated alpha retained; the two additions total about 140 KiB. Original reaching hands remain in `login-hands.png`. Typography is native Flutter canvas text rather than baked into images.

Connecting: CONNECT / ING / PEOPLE behind two independently positioned hand sprites. A 3.5-second reverse loop slowly closes and opens the gap; authenticated contact settles for 500 ms.

Connected: reaching hands dissolve, then the palm rises along a shallow arc from 52% of the viewport height below its final position, unwinding a six-degree wrist rotation and easing to a stop. The 2.3-second reveal retains a final one-second hold. This is a layered 2D lift of the entire hand, not an articulated finger rig. Reduced-motion mode shows the settled poses immediately.

The review route `?preview=login-motion` never authenticates or submits attendance. Actual authentication success alone triggers the success artwork in normal use.
