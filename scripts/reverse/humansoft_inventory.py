#!/usr/bin/env python3
"""Inspect a supplied HumanSoft XAPK without running it or dumping secrets.

Only explicitly selected protocol names and source URIs are exported. These
are byte observations, not proof of request construction or execution.
"""
import argparse
import hashlib
import io
import json
import re
import zipfile
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect(path):
    archive = path.read_bytes()
    with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
        manifest = json.loads(bundle.read('manifest.json'))
        if manifest.get('package_name') != 'th.co.humansoft.app':
            raise ValueError('Expected HumanSoft employee package')
        base = bundle.read('th.co.humansoft.app.apk')
        arm64 = bundle.read('config.arm64_v8a.apk')
    with zipfile.ZipFile(io.BytesIO(arm64)) as apk:
        app = apk.read('lib/arm64-v8a/libapp.so')
        engine = apk.read('lib/arm64-v8a/libflutter.so')
    with zipfile.ZipFile(io.BytesIO(base)) as apk:
        dex = [{'name': n, 'bytes': apk.getinfo(n).file_size}
               for n in apk.namelist() if re.fullmatch(r'classes\d*\.dex', n)]
    # Export an allowlist, never all printable strings or arbitrary URLs.
    candidates = [
        '/api/v1/hrs/time_attendance/add_time_attendance_mobile_4',
        '/api/v1/hrs/time_attendance/re_add_time_attendance_mobile',
        '/api/v1/hrs/work_cycles/get_attendance_work_cycle',
        '/api/v1/hrs/work_cycles/get_work_cycle_by_employee_id',
        'identifier_user', 'verify_face_by_person', 'verify_attendance',
        'search_time_attendance_mobile', 'attendance_image_base64',
        'attendance_datetime', 'work_cycle_date', 'time_attendance_type_lv',
        'attendance_person_id', 'latitude', 'longitude', 'location_id',
        'device_sn', 'face_capture_too_dark', 'face_capture_backlit',
        'face_capture_partial_face', 'face_capture_multiple_faces',
        'face_too_small', 'checking_mock_location', 'attendance_already_receive',
    ]
    literals = []
    for text in candidates:
        pattern = re.compile(rb'(?<![A-Za-z0-9_])' + re.escape(text.encode())
                             + rb'(?![A-Za-z0-9_])')
        offsets = [m.start() for m in pattern.finditer(app)]
        if offsets:
            literals.append({'text': text, 'file_offsets': offsets})
    uri_pattern = rb'package:humansoft/[A-Za-z0-9_/]+\.dart'
    sources = sorted({m.group().decode() for m in re.finditer(uri_pattern, app)
                      if any(k in m.group() for k in [
                          b'/services/check_in_services/',
                          b'/services/time_attendance_services/',
                          b'/services/face_capture/', b'/services/auth_service/',
                          b'/services/my_http_services/',
                          b'/services/my_url_services/',
                          b'/screens/home/attendance/check_in/models/',
                          b'/screens/authen/login/',
                          b'/screens/authen/domain_check/'])})
    return {
        'artifact': {'name': path.name, 'bytes': len(archive),
                     'sha256': digest(archive)},
        'package': {k: manifest.get(k) for k in [
            'package_name', 'version_name', 'version_code', 'min_sdk_version',
            'target_sdk_version']},
        'base_apk': {'bytes': len(base), 'sha256': digest(base), 'dex': dex},
        'arm64_split': {'bytes': len(arm64), 'sha256': digest(arm64)},
        'libapp': {'bytes': len(app), 'sha256': digest(app)},
        'libflutter': {'bytes': len(engine), 'sha256': digest(engine)},
        'observed_literals': literals, 'observed_source_uris': sources,
        'coverage': 'Selected static byte observations only; no Dart object '
                    'decoding, call graph, payload validation or runtime trace. '
                    'SDK or unused code may contain these same literals.',
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('xapk', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = inspect(args.xapk)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print(f'Saved selected static observations to {args.output}')
