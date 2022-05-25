import os
import subprocess
import json
import re

def get_pass(service, cmd):
    return subprocess.check_output(cmd, )

def load_map(acct):
    try:
        with open('@foldermapdir@/%s.json' % acct, 'r') as f:
            return json.loads(f.read())
    except:
        return {}

def save_map(acct, data):
    try:
        os.makedirs('@foldermapdir@')
    except:
        pass
    with open('@foldermapdir@/%s.json' % acct, 'w') as f:
        f.write(json.dumps(data))

def remote_nametrans(acct, foldername, transname):
    data = load_map(acct)
    data[transname] = foldername
    save_map(acct, data)
    return transname

def local_nametrans(acct, foldername, transname):
    data = load_map(acct)
    try:
        return data[foldername]
    except:
        return transname

def gmail_nametrans(foldername):
    return (
        re.sub('^gmail\.all_mail$', 'archive',
        re.sub('^gmail\.drafts$', 'drafts',
        re.sub('^gmail\.sent_mail$', 'sent',
        re.sub('^gmail\.starred$', 'flagged',
        re.sub('^gmail\.spam$', 'junk',
        re.sub('^\[gmail\]\.', 'gmail.',
        basic_nametrans(foldername)
    )))))))

def basic_nametrans(foldername):
    return (
        re.sub(' ', '_',
        re.sub('/', '.',
        foldername.lower()
    )))
