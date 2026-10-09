import unittest,urllib.error
from unittest.mock import patch
from prepare_worker_data import open_retry,RemoteZip
class RetryTests(unittest.TestCase):
 @patch('prepare_worker_data.time.sleep')
 @patch('prepare_worker_data.urllib.request.urlopen')
 def test_gateway_recovers(self,read,sleep):
  expected=object();read.side_effect=[urllib.error.HTTPError('https://zenodo.org/',504,'timeout',{},None),expected]
  self.assertIs(open_retry('url'),expected);self.assertEqual(read.call_count,2);sleep.assert_called_once_with(2)
 @patch('prepare_worker_data.time.sleep')
 @patch('prepare_worker_data.urllib.request.urlopen')
 def test_404_fails_immediately(self,read,sleep):
  read.side_effect=urllib.error.HTTPError('url',404,'missing',{},None)
  with self.assertRaises(urllib.error.HTTPError):open_retry('url')
  self.assertEqual(read.call_count,1);sleep.assert_not_called()
 @patch('prepare_worker_data.time.sleep')
 @patch('prepare_worker_data.urllib.request.urlopen')
 def test_retry_bounded(self,read,sleep):
  read.side_effect=TimeoutError('offline')
  with self.assertRaises(TimeoutError):open_retry('url')
  self.assertEqual(read.call_count,4);self.assertEqual([x.args[0] for x in sleep.call_args_list],[2,4,8])
 @patch('prepare_worker_data.time.sleep')
 def test_truncated_archive_range_recovers(self,sleep):
  archive=object.__new__(RemoteZip)
  with patch.object(archive,'_range_once',side_effect=[EOFError('truncated'),b'complete']) as read:
   self.assertEqual(archive._range(0,7),b'complete');self.assertEqual(read.call_count,2)
  sleep.assert_called_once_with(2)
 @patch('prepare_worker_data.time.sleep')
 def test_archive_version_change_fails_immediately(self,sleep):
  archive=object.__new__(RemoteZip)
  with patch.object(archive,'_range_once',side_effect=ValueError('Unexpected archive range/version')) as read:
   with self.assertRaises(ValueError):archive._range(0,7)
   self.assertEqual(read.call_count,1)
  sleep.assert_not_called()
if __name__=='__main__':unittest.main()
