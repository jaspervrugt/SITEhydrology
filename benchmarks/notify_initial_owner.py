"""Notify the owner after trusted validation; never approve or publish scores."""
import json,os,re,urllib.request

OWNER='jaspervrugt'
MARKER='<!-- site-first-reference-owner-review -->'


def api(path,method='GET',body=None):
    repo=os.environ['REPOSITORY']
    if repo!='jaspervrugt/SITEhydrology':raise ValueError('Unexpected repository')
    data=json.dumps(body).encode() if body is not None else None
    request=urllib.request.Request('https://api.github.com/repos/'+repo+'/'+path,
        data=data,method=method,headers={'Authorization':'Bearer '+os.environ['GH_TOKEN'],
        'Accept':'application/vnd.github+json','User-Agent':'SITE-owner-review',
        'Content-Type':'application/json'})
    with urllib.request.urlopen(request,timeout=45) as response:
        return json.loads(response.read())


def notify(number,call=api):
    number=int(number)
    pr=call(f'pulls/{number}')
    if pr['user']['login'].lower()==OWNER:return 'owner-authored'
    if pr.get('draft'):
        comments=call(f'issues/{number}/comments?per_page=100')
        if not any(MARKER in c.get('body','') for c in comments):
            call(f'issues/{number}/comments','POST',dict(body=MARKER+'\n@'+OWNER+
                ' First SITE reference submitted. Owner review and independent score replay are required before publication.'))
        return 'draft-owner-notified'
    if not any(r['login'].lower()==OWNER for r in pr.get('requested_reviewers',[])):
        call(f'pulls/{number}/requested_reviewers','POST',dict(reviewers=[OWNER]))
    return 'owner-review-requested'


if __name__=='__main__':print(notify(os.environ['PR_NUMBER']))
