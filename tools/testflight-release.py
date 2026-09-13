"""Allocate a remote-aware build number and upload once, never blindly retry.

Codemagic's integration supplies credentials to app-store-connect. No credentials
are written to the repository or logs by this wrapper.
"""
import argparse
import json
import os
import re
import plistlib
import zipfile
from pathlib import Path
import subprocess


def latest_build(app_id):
    result = subprocess.run(
        ['app-store-connect', 'get-latest-testflight-build-number', app_id, '--all-versions'],
        capture_output=True, text=True, check=True,
    )
    return parse_latest_build(result.stdout, result.stderr, app_id)


def parse_latest_build(stdout, stderr, app_id):
    # CLI diagnostics may contain ANSI colors; a successful empty query has
    # no printed value but explicitly logs this message (CLI 0.69.0).
    clean = lambda value: re.sub(r'\x1b\[[0-9;]*m', '', value).strip()
    output, diagnostics = clean(stdout), clean(stderr)
    lines = output.splitlines()
    if lines and lines[-1].strip().isdecimal():
        return int(lines[-1].strip())
    empty = f'Did not find latest build for app {app_id}'
    if empty in (output + '\n' + diagnostics).splitlines() and not output:
        return 0
    if output == empty:
        return 0
    raise RuntimeError('Apple did not return a numeric build or an explicit empty result; refusing to guess.')


def next_build(latest, counter):
    if latest < 0 or counter < 0:
        raise ValueError('Build numbers must be nonnegative')
    return max(latest + 1, counter + 1)


def upload_succeeded(output):
    # The LAST altool JSON result is authoritative. An earlier timeout/error
    # followed by a successful transfer must not trigger another binary upload.
    decoder = json.JSONDecoder()
    for match in reversed(list(re.finditer(r'\{', output))):
        try:
            result, _ = decoder.raw_decode(output[match.start():])
        except ValueError:
            continue
        if isinstance(result, dict) and ('success-message' in result or 'product-errors' in result):
            return bool(result.get('success-message')) and not result.get('product-errors')
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['number', 'upload'])
    parser.add_argument('--app-id', required=True)
    parser.add_argument('--ipa')
    args = parser.parse_args()
    latest = latest_build(args.app_id)
    if args.action == 'number':
        number = next_build(latest, int(os.environ['PROJECT_BUILD_NUMBER']))
        with Path(os.environ['CM_ENV']).open('a') as file:
            file.write(f'IOS_BUILD_NUMBER={number}\n')
        print(f'Apple latest: {latest}; new build: {number}')
        return
    number = int(os.environ['IOS_BUILD_NUMBER'])
    if latest >= number:
        raise RuntimeError(f'Build {number} already exists or is outdated (Apple latest {latest}). No upload attempted.')
    ipa = Path(args.ipa or '')
    if not ipa.is_file() or ipa.suffix != '.ipa':
        raise ValueError('Exactly one existing IPA is required')
    with zipfile.ZipFile(ipa) as archive:
        infos = [p for p in archive.namelist() if p.startswith('Payload/') and p.count('/') == 2 and p.endswith('.app/Info.plist')]
        if len(infos) != 1:
            raise ValueError('Expected one main application in IPA')
        info = plistlib.loads(archive.read(infos[0]))
        if str(info.get('CFBundleVersion')) != str(number):
            raise ValueError('IPA build number does not match the allocated number; refusing stale artifact')
    print(f'Uploading build {number} once; waiting for Apple transfer result...', flush=True)
    result = subprocess.run(
        ['app-store-connect', 'publish', '--path', str(ipa), '--altool-retries', '1'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    # Retain the CLI's already-redacted diagnostic output. Do not dump env/key data.
    print(result.stdout)
    if upload_succeeded(result.stdout):
        print('Apple confirmed the upload. Processing and tester availability must be checked separately.')
    elif result.returncode:
        raise RuntimeError('Upload result uncertain or failed. Check Apple before retrying; no automatic re-upload performed.')
    else:
        print('Uploader completed. Check Apple processing status before any further action.')


if __name__ == '__main__':
    main()
