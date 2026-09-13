import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import subprocess

spec = importlib.util.spec_from_file_location('release', Path(__file__).with_name('testflight-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def test_new_app_requires_explicit_successful_empty_result(self):
        self.assertEqual(release.parse_latest_build('', '\x1b[33mDid not find latest build for app 123\x1b[0m\n', '123'), 0)
        self.assertEqual(release.parse_latest_build('Did not find latest build for app 123\n', '', '123'), 0)
        with self.assertRaises(RuntimeError):
            release.parse_latest_build('', '', '123')
        with self.assertRaises(RuntimeError):
            release.parse_latest_build('', 'Did not find latest build for app 456', '123')

    def test_numeric_output_with_diagnostics(self):
        self.assertEqual(release.parse_latest_build('Found build number 3 from TestFlight version 0.1.0\n3\n', '', '123'), 3)

    def test_api_failure_never_becomes_first_build(self):
        with patch.object(release.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'app-store-connect')):
            with self.assertRaises(subprocess.CalledProcessError):
                release.latest_build('123')

    def test_recreated_ci_counter_cannot_reuse_remote_build(self):
        self.assertEqual(release.next_build(3, 0), 4)
        self.assertEqual(release.next_build(3, 12), 13)

    def test_timeout_followed_by_apple_success_is_success(self):
        output = 'ERROR: The request timed out.\nUPLOAD SUCCEEDED\n{"success-message":"No errors uploading app"}\n'
        self.assertTrue(release.upload_succeeded(output))

    def test_later_redundant_upload_error_is_not_success(self):
        output = '{"success-message":"uploaded"}\n{"product-errors":[{"message":"Redundant Binary Upload"}]}\n'
        self.assertFalse(release.upload_succeeded(output))

    def test_timeout_alone_is_not_a_confirmed_upload(self):
        self.assertFalse(release.upload_succeeded('ERROR: The request timed out.'))

    def test_actual_altool_multiline_json_after_timeout(self):
        output = 'ERROR: timeout\nUPLOAD SUCCEEDED\n{\n  "details": {"delivery-uuid": "test"},\n  "success-message": "No errors uploading archive"\n}\nUploader finished\n'
        self.assertTrue(release.upload_succeeded(output))
        self.assertFalse(release.upload_succeeded(output + '{\n "product-errors": [{"message": "Redundant Binary Upload"}]\n}\n'))


if __name__ == '__main__':
    unittest.main()
