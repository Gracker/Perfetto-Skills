from contextlib import closing
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from tools.download_declared_fixtures import download_declared_fixtures


class FixtureDownloaderTest(unittest.TestCase):
    def test_downloads_only_declared_upstream_fixture_and_verifies_hash(self) -> None:
        payload = b"official trace fixture"
        digest = hashlib.sha256(payload).hexdigest()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = root / "fixture-manifest.json"
            manifest.write_text(
                json.dumps(
                    {
                        "fixtures": [
                            {
                                "id": "fixture",
                                "source": "perfetto/test/data/sample.pftrace",
                                "sha256": digest,
                                "assertions": [{"query_id": "sample/root"}],
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            urls: list[str] = []

            def opener(url: str):
                urls.append(url)
                return closing(io.BytesIO(payload))

            downloaded = download_declared_fixtures(
                manifest, root / "SmartPerfetto", opener=opener
            )

            self.assertEqual(len(downloaded), 1)
            self.assertEqual(downloaded[0].read_bytes(), payload)
            self.assertEqual(
                urls,
                [
                    "https://storage.googleapis.com/perfetto/test_data/"
                    f"sample.pftrace-{digest}"
                ],
            )


if __name__ == "__main__":
    unittest.main()
