"""Download public release bytes anonymously and verify integrity/range support.
Measured speed is from the CI runner, never a promise about a user's network.
"""
import hashlib
import json
import pathlib
import sys
import time
import urllib.request


def verify(root, tag, repo='exactsolution26-lgtm/sss-khatabook'):
    results=[]
    for name in ['SSS-Khatabook-1.0.2-ARM64.apk','SSS-Khatabook-1.0.2-Universal.apk']:
        local=root/name
        expected=hashlib.sha256(local.read_bytes()).hexdigest()
        url=f'https://github.com/{repo}/releases/download/{tag}/{name}'
        started=time.monotonic()
        digest=hashlib.sha256()
        total=0
        # No token/cookie: this tests the public link used by the owner.
        with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'SSS-APK-Download-Verification'}),timeout=90) as response:
            status=response.status
            assert status==200,(name,status)
            while chunk:=response.read(1024*1024):
                digest.update(chunk)
                total+=len(chunk)
        elapsed=time.monotonic()-started
        assert total==local.stat().st_size and digest.hexdigest()==expected,'Public APK differs from signed tested build'
        offset=1024*1024
        request=urllib.request.Request(url,headers={'Range':f'bytes={offset}-{offset+1023}','User-Agent':'SSS-APK-Resume-Verification'})
        with urllib.request.urlopen(request,timeout=90) as response:
            range_status=response.status
            partial=response.read(2048)
            assert range_status==206 and len(partial)==1024,(range_status,len(partial))
            assert response.headers.get('Content-Range')==f'bytes {offset}-{offset+1023}/{total}'
        with local.open('rb') as original:
            original.seek(offset)
            assert partial==original.read(1024),'Resumed bytes differ'
        results.append({'file':name,'public_http':status,'bytes':total,'sha256':expected,
                        'ci_download_seconds':round(elapsed,3),'ci_bytes_per_second':round(total/elapsed),
                        'resume_http':range_status,'resume_bytes_verified':len(partial),
                        'note':'CI runner measurement; user network speed is not guaranteed'})
        print(f'PASS: anonymous full download + SHA256 + HTTP206 resume: {name} ({total} bytes, CI {elapsed:.2f}s)')
    (root/'DOWNLOAD_CHECKS.json').write_text(json.dumps(results,indent=2)+'\n')


if __name__=='__main__':
    verify(pathlib.Path(sys.argv[1]),sys.argv[2])
