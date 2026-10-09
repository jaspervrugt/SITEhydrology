import json
import hashlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from deliver_snapshots import deliver
from fetch_benchmarks import fetch


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=Path(__file__).parent,
                                                ignore_cleanup_errors=True)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'index.json').write_text(json.dumps({'schema': 1, 'profiles': {}}))

    @patch('deliver_snapshots.subprocess.run')
    def test_changed_index_blocks_every_mutation(self, run):
        run.return_value = subprocess.CompletedProcess([], 0, json.dumps({'sha': 'new'}), '')
        with self.assertRaisesRegex(RuntimeError, 'index changed'):
            deliver(self.root, 'old')
        self.assertEqual(run.call_count, 1)

    @patch('deliver_snapshots.subprocess.run')
    def test_release_network_failure_does_not_create_release(self, run):
        run.side_effect = [subprocess.CompletedProcess([], 1, '', 'HTTP 404'),
                           subprocess.CompletedProcess([], 1, '', 'network failure')]
        with self.assertRaisesRegex(RuntimeError, 'benchmark release'):
            deliver(self.root, None)
        self.assertEqual(run.call_count, 2)

    @patch('fetch_benchmarks.subprocess.run')
    def test_missing_index_is_empty_and_does_not_publish(self, run):
        run.return_value = subprocess.CompletedProcess([], 1, '', 'HTTP 404')
        self.assertIsNone(fetch(self.root))
        self.assertEqual(json.loads((self.root / 'index.json').read_text())['profiles'], {})
        self.assertEqual(run.call_count, 1)

    @patch('fetch_benchmarks.subprocess.run')
    def test_auth_failure_is_not_interpreted_as_empty(self, run):
        run.return_value = subprocess.CompletedProcess([], 1, '', 'HTTP 401')
        with self.assertRaisesRegex(RuntimeError, 'latest benchmark index'):
            fetch(self.root)


    @patch('deliver_snapshots.subprocess.check_output')
    @patch('deliver_snapshots.subprocess.run')
    def test_bootstrap_recovery_asset_precedes_index(self,run,read):
        profile='test_profile';paths=[]
        for data in [b'original verified snapshot',b'new verified snapshot']:
            digest=hashlib.sha256(data).hexdigest();relative=f'snapshots/{profile}/{digest}.json'
            target=self.root/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);paths.append((relative,digest))
        (self.root/'index.json').write_text(json.dumps({'schema':1,'profiles':{profile:{'path':paths[1][0],'sha256':paths[1][1],'original':paths[0][0],'previous':paths[0][0]}}}))
        run.side_effect=[subprocess.CompletedProcess([],1,'','HTTP 404'),subprocess.CompletedProcess([],0,'{}',''),subprocess.CompletedProcess([],0,'',''),subprocess.CompletedProcess([],0,'',''),subprocess.CompletedProcess([],0,'','')]
        read.return_value=json.dumps({'assets':[]})
        deliver(self.root,None)
        uploads=[call.args[0] for call in run.call_args_list if call.args[0][:3]==['gh','release','upload']]
        self.assertEqual(len(uploads),2)
        self.assertEqual(run.call_args_list[-1].args[0][3],'--method')


if __name__ == '__main__':
    unittest.main()
