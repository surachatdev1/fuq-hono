# Approved login motion

Original 3D hand artwork follows the approved palm-facing storyboard: navy suit/cream cuff on the peach hand, lavender sleeve on the other hand, soft warm lighting and mint rim light. A local transparent atlas contains three independent sprites and adds about 0.8 MB; there is no video dependency or runtime CDN.

- Login begins: keep the form mounted under an opaque waiting screen. The hands move gently toward one another in a loop; the fingertips stay apart while authentication is pending. Text: `connecting people`.
- Real authentication succeeds: finish the reach/contact for 220 ms, then hard-cut to the palm-facing raised middle finger, fingertip pad facing the viewer, with `fuck u hono`. No rotation, fade, morph or withdrawing-hand beat. Hold 1.1 seconds, then reveal the home screen.
- Authentication fails: remove the waiting screen immediately and show the normal login error. Never show the success gesture. Duplicate submissions remain disabled while the login is pending.
- Respect reduced motion by keeping the waiting art still; the success cut remains instantaneous. Screen-reader status uses a live region. Background artwork is excluded from semantics.
- Preload the atlas while the form is shown. Text is rendered by Flutter, not baked into the image. Layout scrolls on short/narrow screens.

Review route: `/?preview=login-motion`. It is explicitly labeled as a preview, has replay/waiting/success controls, never creates a session, and makes no authentication or attendance request. Normal login uses only the actual server result. The existing Vercel secret/Redis configuration blocker remains unchanged.
