"""Notification calls are idempotent and do not approve or publish anything."""
import unittest
from notify_initial_owner import notify,MARKER


class NotificationTests(unittest.TestCase):
    def test_ready_external_request_requests_owner_review(self):
        calls=[]
        def api(path,method='GET',body=None):
            calls.append((path,method,body))
            if method=='GET':return dict(user=dict(login='contributor'),draft=False,requested_reviewers=[])
            self.assertEqual(body,dict(reviewers=['jaspervrugt']))
            return {}
        self.assertEqual(notify(1,api),'owner-review-requested')
        self.assertEqual(len(calls),2)

    def test_existing_review_request_is_not_repeated(self):
        calls=[]
        def api(path,method='GET',body=None):
            calls.append(method)
            return dict(user=dict(login='contributor'),draft=False,requested_reviewers=[dict(login='jaspervrugt')])
        notify(1,api);self.assertEqual(calls,['GET'])

    def test_existing_draft_notice_is_not_repeated(self):
        calls=[]
        def api(path,method='GET',body=None):
            calls.append(method)
            return ([dict(body=MARKER)] if 'comments' in path else
                    dict(user=dict(login='contributor'),draft=True))
        notify(1,api);self.assertEqual(calls,['GET','GET'])


if __name__=='__main__':unittest.main()
