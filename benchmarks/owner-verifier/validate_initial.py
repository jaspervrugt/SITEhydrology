"""Structural checks only; approval requires owner defaults and numerical replay."""
import re
from validate_submission import validate

def validate_initial(envelope):
 if set(envelope)!={'schema','kind','payload','inputFingerprints'} or envelope['schema']!=1 or envelope['kind']!='owner_initial_reference':raise ValueError('Invalid initial envelope')
 payload=envelope['payload'];fingerprints=envelope['inputFingerprints']
 if set(fingerprints)!={'schema','algorithm','records'} or fingerprints['schema']!=1 or fingerprints['algorithm']!='sha256-input-v1':raise ValueError('Invalid input fingerprint algorithm')
 rows=fingerprints['records'];rows=[rows] if isinstance(rows,dict) else rows
 if not isinstance(rows,list) or not rows or len(rows)>100000:raise ValueError('Invalid fingerprint count')
 ids=set()
 for row in rows:
  if set(row)!={'basin','sha256'} or not isinstance(row['basin'],str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,80}',row['basin']) or not re.fullmatch(r'[0-9a-f]{64}',row['sha256']):raise ValueError('Invalid basin fingerprint')
  if row['basin'] in ids:raise ValueError('Duplicate fingerprint')
  ids.add(row['basin'])
 if not isinstance(payload.get('profile'),str) or not re.fullmatch(r'[a-z][a-z0-9_]{0,99}',payload['profile']):raise ValueError('Invalid profile label')
 profile={'id':payload['profile'],'enabled':True,'contract':payload['contract'],'basinIds':list(ids)}
 report=validate(payload,{'profiles':[profile]})
 records=payload['records'];records=[records] if isinstance(records,dict) else records
 if {r['basin'] for r in records}!=ids:raise ValueError('Fingerprints do not cover submitted basins exactly')
 return report
