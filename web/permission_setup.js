// Web-only first-login permission helper. No image is stored or transmitted.
window.nwlRequestCameraPermission = async () => {
  if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) return 'unavailable';
  let granted;
  try {
    // Request only what attendance actually needs: the front camera, not audio/GPS.
    granted = await navigator.mediaDevices.getUserMedia({
      video: {facingMode: 'user'}, audio: false,
    });
    return 'granted';
  } catch (error) {
    if (error?.name === 'NotAllowedError' || error?.name === 'PermissionDeniedError' || error?.name === 'SecurityError') return 'denied';
    if (error?.name === 'NotFoundError' || error?.name === 'OverconstrainedError') return 'missing';
    return 'error';
  } finally {
    granted?.getTracks().forEach(track => track.stop());
  }
};

window.nwlTestReminderSound = () => {
  try {
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) return 'unavailable';
    const ctx = new Audio();
    const start = ctx.currentTime;
    const oscillator = ctx.createOscillator();
    const gain = ctx.createGain();
    oscillator.type = 'sine';
    oscillator.frequency.value = 760;
    gain.gain.setValueAtTime(0.001, start);
    gain.gain.exponentialRampToValueAtTime(0.08, start + 0.035);
    gain.gain.exponentialRampToValueAtTime(0.001, start + 0.22);
    oscillator.connect(gain);
    gain.connect(ctx.destination);
    ctx.resume().catch(() => {});
    oscillator.start(start);
    oscillator.stop(start + 0.24);
    oscillator.addEventListener('ended', () => ctx.close().catch(() => {}), {once: true});
    return 'played';
  } catch (_) {
    return 'error';
  }
};

// Coordinates stay in the form until the user explicitly confirms and saves.
window.nwlRequestDeviceCoordinates = () => new Promise((resolve, reject) => {
  if (!window.isSecureContext || !navigator.geolocation) {
    reject(new Error('Location unavailable'));
    return;
  }
  navigator.geolocation.getCurrentPosition(
    ({coords}) => resolve(`${coords.latitude}, ${coords.longitude}`),
    () => reject(new Error('Location unavailable')),
    { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 },
  );
});
