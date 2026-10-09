import hashlib,io,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from prepare_worker_data import prepare
class CacheTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(dir=Path(__file__).parent);self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.data=b'official input bytes';self.file=self.root/'camels_name.txt';self.pin=self.root/'pins.json';self.pin.write_text(json.dumps({'files':{'camels_name.txt':hashlib.sha256(self.data).hexdigest()}}))
 @patch('prepare_worker_data.open_retry')
 def test_matching_cache_is_reused(self,fetch):
  self.file.write_bytes(self.data);prepare(self.root,self.pin,[]);fetch.assert_not_called()
 @patch('prepare_worker_data.open_retry')
 def test_tampered_cache_is_replaced_only_with_pinned_bytes(self,fetch):
  self.file.write_bytes(b'tampered');fetch.return_value=io.BytesIO(self.data);prepare(self.root,self.pin,[]);self.assertEqual(self.file.read_bytes(),self.data);fetch.assert_called_once()
 @patch('prepare_worker_data.open_retry')
 def test_bad_download_does_not_overwrite_existing_cache(self,fetch):
  old=b'tampered';self.file.write_bytes(old);fetch.return_value=io.BytesIO(b'bad remote input')
  with self.assertRaisesRegex(ValueError,'checksum'):prepare(self.root,self.pin,[])
  self.assertEqual(self.file.read_bytes(),old)
if __name__=='__main__':unittest.main()
