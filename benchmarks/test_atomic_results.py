import hashlib,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import deliver_result_files as d
class AtomicTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(dir=Path(__file__).parent,ignore_cleanup_errors=True);self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
  self.plan={'files':[]}
  for i,path in enumerate(sorted(d.PATHS)):
   source=f'file{i}';data=f'file{i}'.encode();(self.root/source).write_bytes(data)
   self.plan['files'].append({'path':path,'source':source,'sha256':hashlib.sha256(data).hexdigest(),'expected_sha':str(i)})
 @patch('deliver_result_files.api')
 @patch('deliver_result_files.current_sha')
 def test_changed_input_rejected_before_mutation(self,sha,api):
  api.return_value={'object':{'sha':'head'}}
  sha.return_value='changed'
  with self.assertRaisesRegex(RuntimeError,'Public results changed'):d.deliver_atomic_results(self.root,{},self.plan,'main','benchmarks/index.json','index')
  api.assert_called_once_with('git/ref/heads/main')
 @patch('deliver_result_files.api')
 @patch('deliver_result_files.current_sha')
 def test_all_four_files_single_commit_no_force(self,sha,api):
  n=len(d.PATHS)
  sha.side_effect=[str(i) for i in range(n)]+['index']
  api.side_effect=[{'object':{'sha':'head'}},{'tree':{'sha':'tree'}}]+[{'sha':f'b{i}'} for i in range(n+1)]+[{'sha':'newtree'},{'sha':'newcommit'},{}]
  commit=d.deliver_atomic_results(self.root,{},self.plan,'main','benchmarks/index.json','index')
  self.assertEqual(commit,'newcommit')
  self.assertTrue(all(call.args[1]=='head' for call in sha.call_args_list))
  tree=api.call_args_list[n+3].args[2]['tree'];self.assertEqual(len(tree),n+1)
  self.assertEqual({x['path'] for x in tree},d.PATHS|{'benchmarks/index.json'})
  self.assertEqual(api.call_args_list[-1].args[2],{'sha':'newcommit','force':False})
 @patch('deliver_result_files.api')
 @patch('deliver_result_files.current_sha')
 def test_changed_index_rejected_before_mutation(self,sha,api):
  api.return_value={'object':{'sha':'head'}}
  sha.side_effect=[str(i) for i in range(len(d.PATHS))]+['changed']
  with self.assertRaisesRegex(RuntimeError,'index changed'):d.deliver_atomic_results(self.root,{},self.plan,'main','benchmarks/index.json','index')
  api.assert_called_once_with('git/ref/heads/main')
 @patch('deliver_result_files.api')
 def test_foreign_destinations_rejected(self,api):
  self.plan['files'][0]['path']='README.md'
  with self.assertRaisesRegex(ValueError,'destinations'):d.deliver_atomic_results(self.root,{},self.plan,'main','benchmarks/index.json','index')
  api.assert_not_called()
if __name__=='__main__':unittest.main()
